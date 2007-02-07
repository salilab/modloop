# Input: none, edit this file
# Output: generated models in *.M* files, calculated energies in *.E* files
#

from modeller import *
from modeller.automodel import *

env = environ(rand_seed=RANDOM_SEED) # to get different starting models each time

class myloop(loopmodel):
    def select_loop_atoms(self):
        res = (
RESIDUE_RANGE
        )
        return selection(res)

m = myloop(env, inimodel='USER_PDB',
           sequence='USER_NAME')
m.loop.md_level = refine.slow
m.loop.starting_model = m.loop.ending_model = item

m.make()
