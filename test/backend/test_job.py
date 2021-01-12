from __future__ import print_function
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
        with saliweb.test.working_directory(j.directory):
            # Invalid characters in loops.tsv
            with open('loops.tsv', 'w') as fh:
                fh.write('1\t%\t5\tA\t')
            self.assertRaises(saliweb.backend.SanityError, j.run)
            # Wrong number of fields in loops.tsv
            with open('loops.tsv', 'w') as fh:
                fh.write('1\tA')
            self.assertRaises(saliweb.backend.SanityError, j.run)

    def test_run_ok(self):
        """Test successful run method"""
        j = self.make_test_job(modloop.Job, 'RUNNING')
        with saliweb.test.working_directory(j.directory):
            # Negative residue numbers should be OK
            with open('loops.tsv', 'w') as fh:
                fh.write('1\tA\t-5\tA')
            cls = j.run()
            self.assertIsInstance(cls, saliweb.backend.SGERunner)
            # Underscore OK for chain ID
            with open('loops.tsv', 'w') as fh:
                fh.write('1\t_\t5\t_')
            j.run()
            os.unlink('loop.py')

    def test_postprocess_no_models(self):
        """Test postprocess method; no models produced"""
        j = self.make_test_job(modloop.Job, 'POSTPROCESSING')
        j.required_completed_tasks = 0
        with saliweb.test.working_directory(j.directory):
            with open('1.log', 'w') as fh:
                fh.write("some user error\n")
            j.postprocess()
            self.assertFalse(os.path.exists('output.pdb'))
            self.assertTrue(os.path.exists('failure.log'))

    def test_postprocess_no_models_no_logs(self):
        """Test postprocess method; no models or logs produced"""
        j = self.make_test_job(modloop.Job, 'POSTPROCESSING')
        j.required_completed_tasks = 0
        with saliweb.test.working_directory(j.directory):
            self.assertRaises(modloop.NoLogError, j.postprocess)

    def test_postprocess_no_models_assertion(self):
        """Test postprocess method; Modeller assertion failure"""
        j = self.make_test_job(modloop.Job, 'POSTPROCESSING')
        j.required_completed_tasks = 0
        with saliweb.test.working_directory(j.directory):
            with open('1.log', 'w') as fh:
                fh.write("*** ABNORMAL TERMINATION of Modeller\n")
            self.assertRaises(modloop.AssertionError, j.postprocess)

    def test_postprocess_models(self):
        """Test postprocess method; some models produced"""
        j = self.make_test_job(modloop.Job, 'POSTPROCESSING')
        j.required_completed_tasks = 0
        with saliweb.test.working_directory(j.directory):
            with open('loop.BL0.pdb', 'w') as fh:
                fh.write(
                    "REMARK   1 MODELLER OBJECTIVE FUNCTION:       309.6122\n")
            with open('loop.BL1.pdb', 'w') as fh:
                fh.write(
                    "REMARK   1 MODELLER OBJECTIVE FUNCTION:      -457.3816\n")
            with open('ignored.pdb', 'w') as fh:
                fh.write(
                    "REMARK   1 MODELLER OBJECTIVE FUNCTION:      -900.3816\n")
            with open('loops.tsv', 'w') as fh:
                fh.write('1\tA\t5\tA')
            j.postprocess()
            os.unlink('output.pdb')
            os.unlink('output-pdbs.tar.bz2')
            os.unlink('ignored.pdb')
            self.assertFalse(os.path.exists('loop.BL0.pdb'))
            self.assertFalse(os.path.exists('loop.BL1.pdb'))

    def test_postprocess_insufficient_models(self):
        """Test postprocess method; too few models produced"""
        j = self.make_test_job(modloop.Job, 'POSTPROCESSING')
        with saliweb.test.working_directory(j.directory):
            with open('loop.BL0.pdb', 'w') as fh:
                fh.write(
                    "REMARK   1 MODELLER OBJECTIVE FUNCTION:       309.6122\n")
            with open('loops.tsv', 'w') as fh:
                fh.write('1\tA\t5\tA')
            self.assertRaises(modloop.IncompleteJobError, j.postprocess)


if __name__ == '__main__':
    unittest.main()
