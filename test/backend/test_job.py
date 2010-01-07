import unittest
import modloop
import saliweb.test
import saliweb.backend
import os

class JobTests(saliweb.test.TestCase):
    """Check custom ModLoop Job class"""

    def test_run_sanity_check(self):
        """Test sanity checking in run method"""
        j = self.make_test_job(modloop.Job, 'RUNNING')
        d = saliweb.test.RunInDir(j.directory)
        # Invalid characters in loops.tsv
        open('loops.tsv', 'w').write('1\t%\t5\tA\t')
        self.assertRaises(saliweb.backend.SanityError, j.run)
        # Wrong number of fields in loops.tsv
        open('loops.tsv', 'w').write('1\tA')
        self.assertRaises(saliweb.backend.SanityError, j.run)

    def test_run_ok(self):
        """Test successful run method"""
        j = self.make_test_job(modloop.Job, 'RUNNING')
        d = saliweb.test.RunInDir(j.directory)
        # Negative residue numbers should be OK
        open('loops.tsv', 'w').write('1\tA\t-5\tA')
        cls = j.run()
        self.assert_(isinstance(cls, saliweb.backend.SGERunner),
                     "SGERunner not returned")
        os.unlink('loop.py')

    def test_postprocess_no_models(self):
        """Test postprocess method; no models produced"""
        j = self.make_test_job(modloop.Job, 'POSTPROCESSING')
        d = saliweb.test.RunInDir(j.directory)
        j.postprocess()
        self.assertFalse(os.path.exists('output.pdb'))

    def test_postprocess_models(self):
        """Test postprocess method; some models produced"""
        j = self.make_test_job(modloop.Job, 'POSTPROCESSING')
        d = saliweb.test.RunInDir(j.directory)
        print >> open('loop.BL0.pdb', 'w'), \
               "REMARK   1 MODELLER OBJECTIVE FUNCTION:       309.6122"
        print >> open('loop.BL1.pdb', 'w'), \
               "REMARK   1 MODELLER OBJECTIVE FUNCTION:      -457.3816"
        print >> open('ignored.pdb', 'w'), \
               "REMARK   1 MODELLER OBJECTIVE FUNCTION:      -900.3816"
        open('loops.tsv', 'w').write('1\tA\t5\tA')
        j.postprocess()
        os.unlink('output.pdb')
        os.unlink('output-pdbs.tar.bz2')
        os.unlink('ignored.pdb')
        self.assertFalse(os.path.exists('loop.BL0.pdb'))
        self.assertFalse(os.path.exists('loop.BL1.pdb'))

if __name__ == '__main__':
    unittest.main()
