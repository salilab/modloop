from __future__ import print_function
import saliweb.backend
import tarfile
import glob
import re
import os


class NoLogError(Exception):
    pass


class AssertionError(Exception):
    pass


class IncompleteJobError(Exception):
    pass


class _Model(object):
    def get_outputs(self):
        return glob.glob("loop*.BL*.%s" % self.extension)

    def get_best(self, outputs):
        best_pdb = best_score = None
        for pdb in outputs:
            with open(pdb) as f:
                for line in f:
                    m = self.objfunc_re.search(line)
                    if m:
                        score = float(m.group(1))
                        if best_pdb is None or score < best_score:
                            best_pdb = pdb
                            best_score = score
                        break
        return best_pdb

    def get_output_header(self, jobname, loops, nmodel):
        residue_range = []
        for i in range(0, len(loops), 4):
            residue_range.append("   %s:%s-%s:%s" % tuple(loops[i:i + 4]))
        looplist = "\n".join(residue_range)
        return """
Dear User,

Coordinates for the lowest energy model (out of %(nmodel)d sampled)
of your protein: ``%(jobname)s''  are returned with
the optimized loop regions, listed below:
%(looplist)s

for references please cite these two articles:

   A Fiser, RKG Do and A Sali,
   Modeling of loops in protein structures
   Prot. Sci. (2000) 9, 1753-1773

   A Fiser and A Sali,
   ModLoop: Automated modeling of loops in protein structures
   Bioinformatics. (2003) 18(19) 2500-01


For further inquiries, please contact: modloop@salilab.org

with best regards,
Andras Fiser


""" % locals()

    def make_output(self, best_model, jobname, loops, nmodel):
        with open(best_model) as fin:
            with open(self.output_file, 'w') as fout:
                for line in self.get_output_header(
                        jobname, loops, nmodel).split('\n'):
                    if line == '':
                        fout.write('%s\n' % self.remark_prefix)
                    else:
                        fout.write('%s     %s\n' % (self.remark_prefix, line))
                fout.writelines(fin)


class PdbModel(_Model):
    input_file = 'input.pdb'
    output_file = 'output.pdb'
    file_format = 'PDB'
    extension = 'pdb'
    objfunc_re = re.compile('OBJECTIVE FUNCTION:(.*)$')
    remark_prefix = 'REMARK'


class CifModel(_Model):
    input_file = 'input.cif'
    output_file = 'output.cif'
    file_format = 'MMCIF'
    extension = 'cif'
    objfunc_re = re.compile('_modeller.objective_function (.*)$')
    remark_prefix = '#'


def compress_output_pdbs(pdbs):
    t = tarfile.open('output-pdbs.tar.bz2', 'w:bz2')
    for pdb in pdbs:
        t.add(pdb)
    t.close()

    for pdb in pdbs:
        os.unlink(pdb)


def make_failure_log(logname):
    # No logs or a log containing a Modeller fatal error indicates a problem
    # with the system, and should fail the job (exception). Otherwise, the
    # job should complete normally and the user should be informed they did
    # something wrong
    logs = glob.glob("*.log")
    if len(logs) > 0:
        log = logs[0]
        with open(log) as fh:
            for line in fh:
                if line.startswith('*** ABNORMAL TERMINATION of Modeller'):
                    raise AssertionError(
                        "Modeller assertion failure in " + log)
        os.symlink(log, logname)
    else:
        raise NoLogError("No log files produced")


def make_python_script(loops, model, sequence):
    residue_range = []
    for i in range(0, len(loops), 4):
        residue_range.append("           self.residue_range"
                             "('%s:%s', '%s:%s')," % tuple(loops[i:i + 4]))
    residue_range = "\n".join(residue_range)
    input_pdb = model.input_file
    model_format = model.file_format
    return """
# Run this script with something like
#    python loop.py N > N.log
# where N is an integer from 1 to the number of models.
#
# ModLoop does this for N from 1 to 300 (it runs the tasks in parallel on a
# compute cluster), then returns the single model with the best (lowest)
# value of the Modeller objective function.

from modeller import Environ, Selection, ModellerError
from modeller.automodel import LoopModel, refine
import sys

# to get different starting models for each task
taskid = int(sys.argv[1])
env = Environ(rand_seed=-1000-taskid)

class MyLoop(LoopModel):
    def select_loop_atoms(self):
        rngs = (
%(residue_range)s
        )
        for rng in rngs:
            if len(rng) > 30:
                raise ModellerError("loop too long")
        s = Selection(rngs)
        if len(s.only_no_topology()) > 0:
            raise ModellerError("some selected residues have no topology")
        return s

m = MyLoop(env, inimodel='%(input_pdb)s',
           sequence='%(sequence)s')
m.set_output_model_format('%(model_format)s')
m.loop.md_level = refine.slow
m.loop.starting_model = m.loop.ending_model = taskid

m.make()
""" % locals()


def make_sge_script(runnercls, model, jobname, directory, number_of_tasks):
    input_pdb = model.input_file
    script = """
input="loop.py"
output="${SGE_TASK_ID}.log"

# Create local scratch directory
tmpdir="/scratch/${USER}/modloop/%(jobname)s/$SGE_TASK_ID"
mkdir -p $tmpdir && cd $tmpdir || exit 1

# Get input files
cp %(directory)s/$input %(directory)s/%(input_pdb)s .

module load Sali
module load modeller/10.3
python $input ${SGE_TASK_ID} >& $output

# Copy back PDB/mmCIF
cp *.B* %(directory)s

# Copy back log file (first 5000 lines only, and only for some tasks, in
# case a huge log file was produced):
if [ "${SGE_TASK_ID}" -lt 6 ]; then
  head -5000 $output > %(directory)s/$output
fi

rm -rf $tmpdir
""" % locals()
    r = runnercls(script)
    r.set_sge_options("-o output.error -j y -l h_rt=24:00:00 -l scratch=1G "
                      "-r y -N loop -p -4 -t 1-%d" % number_of_tasks)
    return r


class Job(saliweb.backend.Job):
    number_of_tasks = 300
    required_completed_tasks = 280

    runnercls = saliweb.backend.WyntonSGERunner

    def run(self):
        with open('loops.tsv') as fh:
            loops = fh.read().rstrip('\r\n')
        if not re.match('[A-Za-z0-9\t _<>-]+$', loops):
            raise saliweb.backend.SanityError("Invalid character in loops.tsv")
        loops = loops.split('\t')
        if len(loops) % 4 != 0:
            raise saliweb.backend.SanityError(
                "loops should be a multiple of 4")
        model = self._get_model()
        p = make_python_script(loops, model, 'loop')
        with open('loop.py', 'w') as fh:
            fh.write(p)
        return make_sge_script(self.runnercls, model, self.name,
                               self.directory, self.number_of_tasks)

    def _get_model(self):
        if os.path.exists('input.cif'):
            return CifModel()
        else:
            return PdbModel()

    def postprocess(self):
        model = self._get_model()
        outputs = model.get_outputs()
        best_model = model.get_best(outputs)
        if best_model:
            if len(outputs) < self.required_completed_tasks:
                raise IncompleteJobError("Only %d out of %d modeling tasks "
                                         "completed - at least %d must "
                                         "complete for reasonable results"
                                         % (len(outputs),
                                            self.number_of_tasks,
                                            self.required_completed_tasks))
            else:
                with open('loops.tsv') as fh:
                    loops = fh.read().rstrip('\r\n').split('\t')
                model.make_output(best_model, self.name, loops,
                                  len(outputs))
                compress_output_pdbs(outputs)
        else:
            make_failure_log('failure.log')


def get_web_service(config_file):
    db = saliweb.backend.Database(Job)
    config = saliweb.backend.Config(config_file)
    return saliweb.backend.WebService(config, db)
