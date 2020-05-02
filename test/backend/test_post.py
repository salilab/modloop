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
        t = saliweb.test.RunInTempDir()
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

    def test_get_best_model(self):
        """Check get_best_model function"""
        t = saliweb.test.RunInTempDir()
        with open('test1.pdb', 'w') as fh:
            fh.write("REMARK   1 MODELLER OBJECTIVE FUNCTION:       309.6122\n"
                     "dummy\n")
        with open('test2.pdb', 'w') as fh:
            fh.write("dummy\n"
                     "REMARK   1 MODELLER OBJECTIVE FUNCTION:      -457.3816\n")
        with open('empty.pdb', 'w') as fh:
            pass
        self.assertEqual(modloop.get_best_model([]), None)
        self.assertEqual(modloop.get_best_model(['empty.pdb']), None)
        self.assertEqual(modloop.get_best_model(['test1.pdb']), 'test1.pdb')
        self.assertEqual(modloop.get_best_model(['test1.pdb', 'test2.pdb']),
                         'test2.pdb')
        self.assertEqual(modloop.get_best_model(['test2.pdb', 'test1.pdb']),
                         'test2.pdb')

    def test_make_output_pdb(self):
        """Check make_output_pdb function"""
        t = saliweb.test.RunInTempDir()
        with open('test1.pdb', 'w') as fh:
            fh.write("best model\n")
        modloop.make_output_pdb('test1.pdb', 'output.pdb', 'myjob',
                                ('1', 'A', '10', 'A', '20', 'B', '30', 'B'), 10)
        with open('output.pdb') as fh:
            contents = fh.read()
        r = re.compile(r'^REMARK\nREMARK\s+Dear User.*'
                       r'^REMARK\s+of your protein: ``myjob\'\'.*'
                       r'listed below:.*^REMARK\s+1:A-10:A.*'
                       r'^REMARK\s+20:B-30:B.*best model$',
                       re.MULTILINE | re.DOTALL)
        self.assertTrue(r.match(contents),
                     'File contents:\n%s\ndo not match regex' % contents)
        os.unlink('output.pdb')

if __name__ == '__main__':
    unittest.main()
