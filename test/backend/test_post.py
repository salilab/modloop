from __future__ import print_function
import unittest
import modloop
import saliweb.backend
import saliweb.test
import tarfile
import re
import os


class PostProcessTests(saliweb.test.TestCase):
    """Check postprocessing functions"""

    def test_compress_output_pdbs(self):
        """Check compress_output_pdbs function"""
        with saliweb.test.temporary_working_directory():
            in_pdbs = ['test1', 'test2.pdb']
            for pdb in in_pdbs:
                with open(pdb, 'w') as fh:
                    fh.write("test\n")
            modloop.compress_output_pdbs(in_pdbs)
            # Original PDB files should have been deleted
            for pdb in in_pdbs:
                self.assertEqual(os.path.exists(pdb), False)
            tar = tarfile.open('output-pdbs.tar.bz2', 'r:bz2')
            self.assertEqual([p.name for p in tar], in_pdbs)
            tar.close()
            os.unlink('output-pdbs.tar.bz2')

    def test_pdb_get_best(self):
        """Check PdbModel.get_best function"""
        with saliweb.test.temporary_working_directory():
            with open('test1.pdb', 'w') as fh:
                fh.write(
                    "REMARK   1 MODELLER OBJECTIVE FUNCTION:       309.6122\n"
                    "dummy\n")
            with open('test2.pdb', 'w') as fh:
                fh.write(
                    "dummy\n"
                    "REMARK   1 MODELLER OBJECTIVE FUNCTION:      -457.3816\n")
            with open('empty.pdb', 'w') as fh:
                pass
            model = modloop.PdbModel()
            self.assertEqual(model.get_best([]), None)
            self.assertEqual(model.get_best(['empty.pdb']), None)
            self.assertEqual(model.get_best(['test1.pdb']),
                             'test1.pdb')
            self.assertEqual(
                model.get_best(['test1.pdb', 'test2.pdb']),
                'test2.pdb')
            self.assertEqual(
                model.get_best(['test2.pdb', 'test1.pdb']),
                'test2.pdb')

    def test_cif_get_best(self):
        """Check CifModel.get_best function"""
        with saliweb.test.temporary_working_directory():
            with open('test1.cif', 'w') as fh:
                fh.write(
                    "_modeller.objective_function     309.6122\n"
                    "dummy\n")
            with open('test2.cif', 'w') as fh:
                fh.write(
                    "dummy\n"
                    "_modeller.objective_function    -457.3816\n")
            with open('empty.cif', 'w') as fh:
                pass
            model = modloop.CifModel()
            self.assertEqual(model.get_best([]), None)
            self.assertEqual(model.get_best(['empty.cif']), None)
            self.assertEqual(model.get_best(['test1.cif']),
                             'test1.cif')
            self.assertEqual(
                model.get_best(['test1.cif', 'test2.cif']),
                'test2.cif')
            self.assertEqual(
                model.get_best(['test2.cif', 'test1.cif']),
                'test2.cif')

    def test_pdb_make_output(self):
        """Check PdbModel.make_output function"""
        with saliweb.test.temporary_working_directory():
            with open('test1.pdb', 'w') as fh:
                fh.write("best model\n")
            model = modloop.PdbModel()
            model.make_output(
                'test1.pdb', 'myjob',
                ('1', 'A', '10', 'A', '20', 'B', '30', 'B'), 10)
            with open('output.pdb') as fh:
                contents = fh.read()
            r = re.compile(r'\AREMARK\nREMARK\s+Dear User.*'
                           r'^REMARK\s+of your protein: ``myjob\'\'.*'
                           r'listed below:.*^REMARK\s+1:A-10:A.*'
                           r'^REMARK\s+20:B-30:B.*best model$',
                           re.MULTILINE | re.DOTALL)
            self.assertRegex(contents, r)
            os.unlink('output.pdb')

    def test_cif_make_output(self):
        """Check CifModel.make_output function"""
        with saliweb.test.temporary_working_directory():
            with open('test1.cif', 'w') as fh:
                fh.write("best model\n")
            model = modloop.CifModel()
            model.make_output(
                'test1.cif', 'myjob',
                ('1', 'A', '10', 'A', '20', 'B', '30', 'B'), 10)
            with open('output.cif') as fh:
                contents = fh.read()
            r = re.compile(r'\A#\n#\s+Dear User.*'
                           r'^#\s+of your protein: ``myjob\'\'.*'
                           r'listed below:.*^#\s+1:A-10:A.*'
                           r'^#\s+20:B-30:B.*best model$',
                           re.MULTILINE | re.DOTALL)
            self.assertRegex(contents, r)
            os.unlink('output.cif')


if __name__ == '__main__':
    unittest.main()
