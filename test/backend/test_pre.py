import unittest
import modloop
import saliweb.test
import saliweb.backend
import py_compile
import os
import re


class PreProcessTests(saliweb.test.TestCase):
    """Check preprocessing functions"""

    def test_make_python_script_pdb(self):
        """Check make_python_script function with PDB models"""
        with saliweb.test.temporary_working_directory():
            model = modloop.PdbModel()
            s = modloop.make_python_script(('1', 'A', '10', 'A'), model,
                                           'myseq')
            r = re.compile(
                r"def select_loop_atoms\(.*"
                r"self\.residue_range\('1:A', '10:A'\).*"
                r"MyLoop\(env, inimodel='input.pdb',.*"
                r"sequence='myseq'.*"
                r"m\.set_output_model_format\('PDB'\)",
                re.DOTALL | re.MULTILINE)
            self.assertRegex(s, r)
            # Make sure that the script contains no syntax errors
            with open('test.py', 'w') as fh:
                fh.write(s)
            py_compile.compile('test.py', doraise=True)
            os.unlink('test.py')

    def test_make_python_script_mmcif(self):
        """Check make_python_script function with mmCIF models"""
        with saliweb.test.temporary_working_directory():
            model = modloop.CifModel()
            s = modloop.make_python_script(('1', 'A', '10', 'A'), model,
                                           'myseq')
            r = re.compile(
                r"def select_loop_atoms\(.*"
                r"self\.residue_range\('1:A', '10:A'\).*"
                r"MyLoop\(env, inimodel='input.cif',.*"
                r"sequence='myseq'.*"
                r"m\.set_output_model_format\('MMCIF'\)",
                re.DOTALL | re.MULTILINE)
            self.assertRegex(s, r)
            # Make sure that the script contains no syntax errors
            with open('test.py', 'w') as fh:
                fh.write(s)
            py_compile.compile('test.py', doraise=True)
            os.unlink('test.py')

    def test_make_sge_script_pdb(self):
        """Check make_sge_script function with PDB models"""
        model = modloop.PdbModel()
        s = modloop.make_sge_script(saliweb.backend.SGERunner, model, 'myjob',
                                    '/foo/bar', 300)
        self.assertIsInstance(s, saliweb.backend.SGERunner)

    def test_make_sge_script_mmcif(self):
        """Check make_sge_script function with mmCIF models"""
        model = modloop.CifModel()
        s = modloop.make_sge_script(saliweb.backend.SGERunner, model, 'myjob',
                                    '/foo/bar', 300)
        self.assertIsInstance(s, saliweb.backend.SGERunner)


if __name__ == '__main__':
    unittest.main()
