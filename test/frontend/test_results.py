import unittest
import saliweb.test
import re

# Import the modloop frontend with mocks
modloop = saliweb.test.import_mocked_frontend("modloop", __file__,
                                              '../../frontend')


class Tests(saliweb.test.TestCase):
    """Check results page"""

    def test_results_file(self):
        """Test download of results files"""
        with saliweb.test.make_frontend_job('testjob') as j:
            for fname in ('bad.log', 'output.pdb', 'failure.log'):
                j.make_file(fname)
            c = modloop.app.test_client()
            # Prohibited file (that exists)
            rv = c.get('/job/testjob/bad.log?passwd=%s' % j.passwd)
            self.assertEqual(rv.status_code, 404)
            # Good files
            rv = c.get('/job/testjob/failure.log?passwd=%s' % j.passwd)
            self.assertEqual(rv.status_code, 200)
            rv = c.get('/job/testjob/output.pdb?passwd=%s' % j.passwd)
            self.assertEqual(rv.status_code, 200)

    def test_ok_job(self):
        """Test display of OK job"""
        with saliweb.test.make_frontend_job('testjob2') as j:
            j.make_file("output.pdb")
            c = modloop.app.test_client()
            for endpoint in ('job', 'results.cgi'):
                rv = c.get('/%s/testjob2?passwd=%s' % (endpoint, j.passwd))
                r = re.compile(
                        b'Job.*testjob.*has completed.*output\\.pdb.*'
                        b'Download output PDB', re.MULTILINE | re.DOTALL)
                self.assertRegex(rv.data, r)

    def test_failed_job(self):
        """Test display of failed job"""
        with saliweb.test.make_frontend_job('testjob3') as j:
            c = modloop.app.test_client()
            rv = c.get('/job/testjob3?passwd=%s' % j.passwd)
            r = re.compile(
                b'Your ModLoop job.*testjob.*failed to produce any output.*'
                b'please see the.*#errors.*help page.*For more information, '
                b'you can.*failure\\.log.*download the MODELLER log file.*'
                b'contact us', re.MULTILINE | re.DOTALL)
            self.assertRegex(rv.data, r)


if __name__ == '__main__':
    unittest.main()
