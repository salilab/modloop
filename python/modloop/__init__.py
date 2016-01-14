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


def compress_output_pdbs(pdbs):
    t = tarfile.open('output-pdbs.tar.bz2', 'w:bz2')
    for pdb in pdbs:
        t.add(pdb)
    t.close()

    for pdb in pdbs:
        os.unlink(pdb)


def get_best_model(pdbs):
    best_pdb = best_score = None
    objfunc_re = re.compile('OBJECTIVE FUNCTION:(.*)$')
    for pdb in pdbs:
        f = open(pdb)
        for line in f:
            m = objfunc_re.search(line)
            if m:
                score = float(m.group(1))
                if best_pdb is None or score < best_score:
                    best_pdb = pdb
                    best_score = score
                break
    return best_pdb


def make_failure_log(logname):
    # No logs or a log containing a Modeller fatal error indicates a problem
    # with the system, and should fail the job (exception). Otherwise, the
    # job should complete normally and the user should be informed they did
    # something wrong
    logs = glob.glob("*.log")
    if len(logs) > 0:
        log = logs[0]
        for line in open(log):
            if line.startswith('*** ABNORMAL TERMINATION of Modeller'):
                raise AssertionError("Modeller assertion failure in " + log)
        os.symlink(log, logname)
    else:
        raise NoLogError("No log files produced")


def make_output_pdb(best_model, out, jobname, loops, num_models):
    residue_range = []
    for i in range(0, len(loops), 4):
        residue_range.append("REMARK        %s:%s-%s:%s"
                             % tuple(loops[i:i + 4]))
    looplist = "\n".join(residue_range)
    fin = open(best_model)
    fout = open(out, 'w')
    print >> fout, """REMARK
REMARK     Dear User,
REMARK
REMARK     Coordinates for the lowest energy model (out of %(num_models)d sampled)
REMARK     of your protein: ``%(jobname)s''  are returned with
REMARK     the optimized loop regions, listed below:
%(looplist)s
REMARK
REMARK     for references please cite these two articles:
REMARK
REMARK        A Fiser, RKG Do and A Sali,
REMARK        Modeling of loops in protein structures
REMARK        Prot. Sci. (2000) 9, 1753-1773
REMARK
REMARK        A Fiser and A Sali,
REMARK        ModLoop: Automated modeling of loops in protein structures
REMARK        Bioinformatics. (2003) 18(19) 2500-01
REMARK
REMARK
REMARK     For further inquiries, please contact: modloop@salilab.org
REMARK
REMARK     with best regards,
REMARK     Andras Fiser
REMARK
REMARK""" % locals()
    fout.writelines(fin)


def make_python_script(loops, input_pdb, sequence):
    residue_range = []
    for i in range(0, len(loops), 4):
        residue_range.append("           self.residue_range"
                             "('%s:%s', '%s:%s')," % tuple(loops[i:i + 4]))
    residue_range = "\n".join(residue_range)
    return """
# Run this script with something like
#    python loop.py N > N.log
# where N is an integer from 1 to the number of models.
#
# ModLoop does this for N from 1 to 300 (it runs the tasks in parallel on a
# compute cluster), then returns the single model with the best (lowest)
# value of the Modeller objective function.

from modeller import *
from modeller.automodel import *
import sys

# to get different starting models for each task
taskid = int(sys.argv[1])
env = environ(rand_seed=-1000-taskid)

class MyLoop(loopmodel):
    def select_loop_atoms(self):
        rngs = (
%(residue_range)s
        )
        for rng in rngs:
            if len(rng) > 30:
                raise ModellerError("loop too long")
        s = selection(rngs)
        if len(s.only_no_topology()) > 0:
            raise ModellerError("some selected residues have no topology")
        return s

m = MyLoop(env, inimodel='%(input_pdb)s',
           sequence='%(sequence)s')
m.loop.md_level = refine.slow
m.loop.starting_model = m.loop.ending_model = taskid

m.make()
""" % locals()


def make_sge_script(runnercls, jobname, directory, number_of_tasks):
    script = """
input="loop.py"
output="${SGE_TASK_ID}.log"

# Create local scratch directory
tmpdir="/scratch/${USER}/modloop/%(jobname)s/$SGE_TASK_ID"
mkdir -p $tmpdir && cd $tmpdir || exit 1

# Get input files
cp %(directory)s/$input %(directory)s/input.pdb .

module load modeller/9.16
python $input ${SGE_TASK_ID} >& $output

# Copy back PDB
cp *.B* %(directory)s

# Copy back log file (first 5000 lines only, and only for some tasks, in
# case a huge log file was produced):
if [ "${SGE_TASK_ID}" -lt 6 ]; then
  head -5000 $output > %(directory)s/$output
fi

rm -rf $tmpdir
""" % locals()
    r = runnercls(script)
    r.set_sge_options("-o output.error -j y -l scratch=1G -l netappsali=1G "
                      "-r y -N loop -p -4 -t 1-%d" % number_of_tasks)
    return r


class Job(saliweb.backend.Job):
    number_of_tasks = 300
    required_completed_tasks = 280

    runnercls = saliweb.backend.SaliSGERunner

    def run(self):
        loops = open('loops.tsv').read().rstrip('\r\n')
        if not re.match('[A-Za-z0-9\t _-]+$', loops):
            raise saliweb.backend.SanityError("Invalid character in loops.tsv")
        loops = loops.split('\t')
        if len(loops) % 4 != 0:
            raise saliweb.backend.SanityError(
                "loops should be a multiple of 4")
        p = make_python_script(loops, 'input.pdb', 'loop')
        open('loop.py', 'w').write(p)
        return make_sge_script(self.runnercls, self.name, self.directory,
                               self.number_of_tasks)

    def postprocess(self):
        output_pdbs = glob.glob("loop*.BL*.pdb")
        best_model = get_best_model(output_pdbs)
        if best_model:
            if len(output_pdbs) < self.required_completed_tasks:
                raise IncompleteJobError("Only %d out of %d modeling tasks "
                                         "completed - at least %d must "
                                         "complete for reasonable results"
                                         % (len(output_pdbs),
                                            self.number_of_tasks,
                                            self.required_completed_tasks))
            else:
                loops = open('loops.tsv').read().rstrip('\r\n').split('\t')
                make_output_pdb(best_model, 'output.pdb', self.name, loops,
                                len(output_pdbs))
                compress_output_pdbs(output_pdbs)
        else:
            make_failure_log('failure.log')


def get_web_service(config_file):
    db = saliweb.backend.Database(Job)
    config = saliweb.backend.Config(config_file)
    return saliweb.backend.WebService(config, db)
