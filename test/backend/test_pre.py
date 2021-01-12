import unittest
import modloop
import saliweb.test
import saliweb.backend
import py_compile
import sys
import os
import re


class PreProcessTests(saliweb.test.TestCase):
    """Check preprocessing functions"""

    def test_make_python_script(self):
        """Check make_python_script function"""
        with saliweb.test.temporary_working_directory():
            s = modloop.make_python_script(('1', 'A', '10', 'A'), 'test.pdb',
                                           'myseq')
            r = re.compile(
                r"def select_loop_atoms\(.*"
                r"self\.residue_range\('1:A', '10:A'\).*"
                r"MyLoop\(env, inimodel='test.pdb',.*"
                r"sequence='myseq'", re.DOTALL | re.MULTILINE)
            self.assertRegex(s, r)
            # Make sure that the script contains no syntax errors
            with open('test.py', 'w') as fh:
                fh.write(s)
            py_compile.compile('test.py', doraise=True)
            if sys.version_info[0] == 2:
                os.unlink('test.pyc')
            os.unlink('test.py')

    def test_make_sge_script(self):
        """Check make_sge_script function"""
        s = modloop.make_sge_script(saliweb.backend.SGERunner, 'myjob',
                                    '/foo/bar', 300)
        self.assertIsInstance(s, saliweb.backend.SGERunner)


if __name__ == '__main__':
    unittest.main()
