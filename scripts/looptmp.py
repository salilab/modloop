# Input: ${SGE_TASK_ID}
# Output: generated models in *.B* files, calculated energies in *.E* files
#

from modeller import *
from modeller.automodel import *
import sys

# to get different starting models for each task
taskid = int(sys.argv[1])
env = environ(rand_seed=-1000-taskid)

class myloop(loopmodel):
    def select_loop_atoms(self):
        res = (
RESIDUE_RANGE
        )
        s = selection(res)
        if len(s.only_no_topology()) > 0:
            raise ModellerError, "some selected residues have no topology"
        return s

m = myloop(env, inimodel='USER_PDB',
           sequence='USER_NAME')
m.loop.md_level = refine.slow
m.loop.starting_model = m.loop.ending_model = taskid

m.make()
