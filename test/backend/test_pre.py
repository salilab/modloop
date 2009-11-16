import unittest
import modloop
import saliweb.test
import saliweb.backend
import py_compile
import os
import re

class PreProcessTests(saliweb.test.TestCase):
    """Check preprocessing functions"""

    def test_make_python_script(self):
        """Check make_python_script function"""
        t = saliweb.test.RunInTempDir()
        s = modloop.make_python_script(('1', 'A', '10', 'A'), 'test.pdb',
                                       'myseq')
        self.assert_(re.search("def select_loop_atoms\(.*"
                               "self\.residue_range\('1:A', '10:A'\).*"
                               "MyLoop\(env, inimodel='test.pdb',.*"
                               "sequence='myseq'", s, re.DOTALL | re.MULTILINE),
                     'Python script does not match regex: ' + s)
        # Make sure that the script contains no syntax errors
        open('test.py', 'w').write(s)
        py_compile.compile('test.py', doraise=True)
        os.unlink('test.pyc')
        os.unlink('test.py')

    def test_make_sge_script(self):
        """Check make_sge_script function"""
        s = modloop.make_sge_script(saliweb.backend.SGERunner, 'myjob',
                                    '/foo/bar')
        self.assert_(isinstance(s, saliweb.backend.SGERunner),
                     "SGERunner not returned")

if __name__ == '__main__':
    unittest.main()
