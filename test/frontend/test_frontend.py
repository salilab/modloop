import unittest
import saliweb.test

# Import the modloop frontend with mocks
modloop = saliweb.test.import_mocked_frontend("modloop", __file__,
                                              '../../frontend')


class Tests(saliweb.test.TestCase):
    """Check custom ModLoop Job class"""

    def test_index(self):
        """Test index page"""
        c = modloop.app.test_client()
        rv = c.get('/')
        self.assertIn(b'ModLoop: Modeling of Loops in Protein Structures',
                      rv.data)
        self.assertIn(b'ModLoop is a web server for automated modeling of',
                      rv.data)
        self.assertIn(b'Enter loop segments', rv.data)

    def test_contact(self):
        """Test contact page"""
        c = modloop.app.test_client()
        rv = c.get('/contact')
        self.assertIn(b'Please address inquiries to', rv.data)

    def test_help(self):
        """Test help page"""
        c = modloop.app.test_client()
        rv = c.get('/help')
        self.assertIn(b'Central bond too short', rv.data)

    def test_download(self):
        """Test download page"""
        c = modloop.app.test_client()
        rv = c.get('/download')
        self.assertIn(b'The ModLoop protocol is part of Modeller', rv.data)

    def test_queue(self):
        """Test queue page"""
        c = modloop.app.test_client()
        rv = c.get('/job')
        self.assertIn(b'No pending or running jobs', rv.data)


if __name__ == '__main__':
    unittest.main()
