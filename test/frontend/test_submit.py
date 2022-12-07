import unittest
import saliweb.test
import tempfile
import os
import re
from werkzeug.datastructures import FileStorage

# Import the modloop frontend with mocks
modloop = saliweb.test.import_mocked_frontend("modloop", __file__,
                                              '../../frontend')


class Tests(saliweb.test.TestCase):
    """Check submit page"""

    def test_submit_page(self):
        """Test submit page"""
        with tempfile.TemporaryDirectory() as t:
            incoming = os.path.join(t, 'incoming')
            os.mkdir(incoming)
            modloop.app.config['DIRECTORIES_INCOMING'] = incoming
            c = modloop.app.test_client()
            rv = c.post('/job')
            self.assertEqual(rv.status_code, 400)  # no license key

            modkey = saliweb.test.get_modeller_key()
            data = {'modkey': modkey}
            rv = c.post('/job', data=data)
            self.assertEqual(rv.status_code, 400)  # no loops

            data['loops'] = '1::1::'
            rv = c.post('/job', data=data)
            self.assertEqual(rv.status_code, 400)  # no pdb file

            pdbf = os.path.join(t, 'test.pdb')
            with open(pdbf, 'w') as fh:
                fh.write(
                    "REMARK\n"
                    "ATOM      2  CA  ALA     1      26.711  14.576   5.091\n")

            # Successful submission (no email)
            data['pdb'] = open(pdbf, 'rb')
            rv = c.post('/job', data=data)
            self.assertEqual(rv.status_code, 200)
            r = re.compile(b'Your job has been submitted.*'
                           b'You can check on your job',
                           re.MULTILINE | re.DOTALL)
            self.assertRegex(rv.data, r)

            # Successful submission (with email)
            data['email'] = 'test@test.com'
            data['pdb'] = open(pdbf, 'rb')
            rv = c.post('/job', data=data)
            self.assertEqual(rv.status_code, 200)
            r = re.compile(
                b'Your job has been submitted.*You will be notified.*'
                b'You can check on your job', re.MULTILINE | re.DOTALL)
            self.assertRegex(rv.data, r)

    def test_check_loop_selection(self):
        """Test check_loop_selection()"""
        modloop.submit.check_loop_selection("anything")
        self.assertRaises(saliweb.frontend.InputValidationError,
                          modloop.submit.check_loop_selection, "")

    def test_check_pdb_name(self):
        """Test check_pdb_name()"""
        modloop.submit.check_pdb_name("anything")
        self.assertRaises(saliweb.frontend.InputValidationError,
                          modloop.submit.check_pdb_name, "")

    def test_parse_loop_selection(self):
        """Test parse_loop_selection()"""
        (loops, start_res, start_id, end_res, end_id,
         loop_data) = modloop.submit.parse_loop_selection('1::5::16:A:30:A:')
        self.assertEqual(loop_data, ['1', ' ', '5', ' ', '16', 'A', '30', 'A'])
        self.assertEqual(start_res, [1, 16])
        self.assertEqual(start_id, [' ', 'A'])
        self.assertEqual(end_res, [5, 30])
        self.assertEqual(end_id, [' ', 'A'])

        # Negative residue numbers are OK
        (loops, start_res, start_id, end_res, end_id,
         loop_data) = modloop.submit.parse_loop_selection('-5:A:1:A:')
        self.assertEqual(start_res, [-5])
        self.assertEqual(end_res, [1])

        # Wrong number of colons
        self.assertRaises(
            saliweb.frontend.InputValidationError,
            modloop.submit.parse_loop_selection, '1::5::16:A:30:')

        # Loop that spans chains
        self.assertRaises(
            saliweb.frontend.InputValidationError,
            modloop.submit.parse_loop_selection, '1::5::16:A:20:B:')

        # Loop too long
        self.assertRaises(
            saliweb.frontend.InputValidationError,
            modloop.submit.parse_loop_selection, '1::50::16:A:20:B:')

        # Non-numeric residue
        self.assertRaises(
            saliweb.frontend.InputValidationError,
            modloop.submit.parse_loop_selection, '1::5A::16:A:20:B:')

        # Loop of negative length
        self.assertRaises(
            saliweb.frontend.InputValidationError,
            modloop.submit.parse_loop_selection, '10::5::16:A:20:B:')

        # Too many residues
        self.assertRaises(
            saliweb.frontend.InputValidationError,
            modloop.submit.parse_loop_selection, '1::10::20:A:31:A:')

        # No residues
        self.assertRaises(
            saliweb.frontend.InputValidationError,
            modloop.submit.parse_loop_selection, '')

        # Empty first residue
        self.assertRaises(
            saliweb.frontend.InputValidationError,
            modloop.submit.parse_loop_selection, '::10::20:A:31:A:')

    def test_read_pdb_file_pdb(self):
        """Test read_pdb_file() in PDB format"""
        with tempfile.TemporaryDirectory() as tmpdir:
            pdb = os.path.join(tmpdir, 'test.pdb')
            with open(pdb, 'w') as fh:
                for chain in (' ', 'A'):
                    for resid in range(1, 11):
                        fh.write(
                            "ATOM      1  CA  ALA %1s%4d      "
                            "18.511  -1.416  15.632  1.00  6.84           C\n"
                            % (chain, resid))

            # Successful read
            with open(pdb, 'rb') as fh:
                fs = FileStorage(stream=fh, filename='test.pdb')
                contents, pdbext = modloop.submit.read_pdb_file(
                    fs, 2, [1, 1], [' ', 'A'], [5, 5], [' ', 'A'])
            r = re.compile(
                b'^ATOM\\s+1\\s+CA\\s+ALA     1.*ATOM\\s+1\\s+CA\\s+ALA A  10',
                re.MULTILINE | re.DOTALL)
            self.assertEqual(pdbext, '.pdb')
            self.assertRegex(b"".join(contents), r)

            # Loop not found in ATOM records
            with open(pdb, 'rb') as fh:
                fs = FileStorage(stream=fh, filename='test.pdb')
                self.assertRaises(
                    saliweb.frontend.InputValidationError,
                    modloop.submit.read_pdb_file, fs, 2, [1, 1], [' ', 'A'],
                    [5, 15], [' ', 'A'])

    def test_read_pdb_file_cif(self):
        """Test read_pdb_file() in mmCIF format"""
        with tempfile.TemporaryDirectory() as tmpdir:
            pdb = os.path.join(tmpdir, 'test.cif')
            with open(pdb, 'w') as fh:
                fh.write("""
loop_
_atom_site.group_PDB
_atom_site.id
_atom_site.type_symbol
_atom_site.label_atom_id
_atom_site.label_alt_id
_atom_site.label_comp_id
_atom_site.label_asym_id
_atom_site.label_entity_id
_atom_site.label_seq_id
_atom_site.pdbx_PDB_ins_code
_atom_site.Cartn_x
_atom_site.Cartn_y
_atom_site.Cartn_z
_atom_site.occupancy
_atom_site.B_iso_or_equiv
_atom_site.pdbx_formal_charge
_atom_site.auth_seq_id
_atom_site.auth_comp_id
_atom_site.auth_asym_id
_atom_site.auth_atom_id
_atom_site.pdbx_PDB_model_num
""")
                fh.write("HETATM 1 C CA . ALA X 1 . ? "
                         "18.511  -1.416  15.632  1.00 "
                         "6.84 ? . ALA X CA 1\n")
                for chain in ('A', 'B'):
                    for resid in range(1, 11):
                        fh.write(
                            "ATOM 1 C CA . ALA %s 1 %d ? "
                            "18.511  -1.416  15.632  1.00 "
                            "6.84 ? %d ALA %s CA 1\n"
                            % (chain, resid, resid, chain))

            # Successful read
            with open(pdb, 'rb') as fh:
                fs = FileStorage(stream=fh, filename='test.cif')
                contents, pdbext = modloop.submit.read_pdb_file(
                    fs, 2, [1, 1], ['A', 'B'], [5, 5], ['A', 'B'])
            r = re.compile(
                rb'^loop_.*_atom_site\.auth_atom_id.*ATOM 1 C CA',
                re.MULTILINE | re.DOTALL)
            self.assertEqual(pdbext, '.cif')
            self.assertRegex(b"".join(contents), r)

            # Loop not found in ATOM records
            with open(pdb, 'rb') as fh:
                fs = FileStorage(stream=fh, filename='test.cif')
                self.assertRaises(
                    saliweb.frontend.InputValidationError,
                    modloop.submit.read_pdb_file, fs, 2, [1, 1], [' ', 'A'],
                    [5, 15], [' ', 'A'])

    def test_read_pdb_file_invalid_cif(self):
        """Test read_pdb_file() with invalid mmCIF input"""
        with tempfile.TemporaryDirectory() as tmpdir:
            pdb = os.path.join(tmpdir, 'test.cif')
            with open(pdb, 'w') as fh:
                fh.write("loop_\n_atom_site.group_PDB\n_bad_cat.id\n")
            with open(pdb, 'rb') as fh:
                fs = FileStorage(stream=fh, filename='test.cif')
                self.assertRaises(
                    saliweb.frontend.InputValidationError,
                    modloop.submit.read_pdb_file, fs, 2, [1, 1], [' ', 'A'],
                    [5, 15], [' ', 'A'])


if __name__ == '__main__':
    unittest.main()
