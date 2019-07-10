import unittest
import saliweb.test
import os
import re

# Import the modloop frontend with mocks
modloop = saliweb.test.import_mocked_frontend("modloop", __file__,
                                              '../../frontend')


class Tests(saliweb.test.TestCase):
    """Check submit page"""

    def test_submit_page(self):
        """Test submit page"""
        incoming = saliweb.test.TempDir()
        modloop.app.config['DIRECTORIES_INCOMING'] = incoming.tmpdir
        c = modloop.app.test_client()
        rv = c.post('/job')
        self.assertEqual(rv.status_code, 400)  # no license key

        modkey = saliweb.test.get_modeller_key()
        data={'modkey': modkey}
        rv = c.post('/job', data=data)
        self.assertEqual(rv.status_code, 400)  # no loops

        data['loops'] = '1::1::'
        rv = c.post('/job', data=data)
        self.assertEqual(rv.status_code, 400)  # no pdb file

        t = saliweb.test.TempDir()
        pdbf = os.path.join(t.tmpdir, 'test.pdb')
        with open(pdbf, 'w') as fh:
            fh.write("REMARK\n"
                     "ATOM      2  CA  ALA     1      26.711  14.576   5.091\n")

        # Successful submission (no email)
        data['pdb'] = open(pdbf)
        rv = c.post('/job', data=data)
        self.assertEqual(rv.status_code, 200)
        r = re.compile('Your job has been submitted.*You can check on your job',
                       re.MULTILINE | re.DOTALL)
        self.assertRegexpMatches(rv.data, r)

        # Successful submission (with email)
        data['email'] = 'test@test.com'
        data['pdb'] = open(pdbf)
        rv = c.post('/job', data=data)
        self.assertEqual(rv.status_code, 200)
        r = re.compile('Your job has been submitted.*You will be notified.*'
                       'You can check on your job', re.MULTILINE | re.DOTALL)
        self.assertRegexpMatches(rv.data, r)

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

        # Wrong number of colons
        self.assertRaises(saliweb.frontend.InputValidationError,
            modloop.submit.parse_loop_selection, '1::5::16:A:30:')

        # Loop that spans chains
        self.assertRaises(saliweb.frontend.InputValidationError,
            modloop.submit.parse_loop_selection, '1::5::16:A:20:B:')

        # Loop too long
        self.assertRaises(saliweb.frontend.InputValidationError,
            modloop.submit.parse_loop_selection, '1::50::16:A:20:B:')

        # Non-numeric residue
        self.assertRaises(saliweb.frontend.InputValidationError,
            modloop.submit.parse_loop_selection, '1::5A::16:A:20:B:')

        # Loop of negative length
        self.assertRaises(saliweb.frontend.InputValidationError,
            modloop.submit.parse_loop_selection, '10::5::16:A:20:B:')

        # Too many residues
        self.assertRaises(saliweb.frontend.InputValidationError,
            modloop.submit.parse_loop_selection, '1::10::20:A:31:A:')

        # No residues
        self.assertRaises(saliweb.frontend.InputValidationError,
            modloop.submit.parse_loop_selection, '')

        # Empty first residue
        self.assertRaises(saliweb.frontend.InputValidationError,
            modloop.submit.parse_loop_selection, '::10::20:A:31:A:')

    def test_read_pdb_file(self):
        """Test read_pdb_file()"""
        t = saliweb.test.TempDir()
        pdb = os.path.join(t.tmpdir, 'test.pdb')
        with open(pdb, 'w') as fh:
            for chain in (' ', 'A'):
                for resid in range(1,11):
                    fh.write("ATOM      1  CA  ALA %1s%4d      "
                        "18.511  -1.416  15.632  1.00  6.84           C\n"
                        % (chain, resid))

        # Successful read
        with open(pdb) as fh:
            contents = modloop.submit.read_pdb_file(fh, 2, [1, 1], [' ', 'A'],
                                                    [5, 5], [' ', 'A'])
        r = re.compile('^ATOM\s+1\s+CA\s+ALA     1.*ATOM\s+1\s+CA\s+ALA A  10',
                       re.MULTILINE | re.DOTALL)
        self.assertRegexpMatches("".join(contents), r)

        # Loop not found in ATOM records
        with open(pdb) as fh:
            self.assertRaises(saliweb.frontend.InputValidationError,
                modloop.submit.read_pdb_file, fh, 2, [1, 1], [' ', 'A'],
                [5, 15], [' ', 'A'])


if __name__ == '__main__':
    unittest.main()
