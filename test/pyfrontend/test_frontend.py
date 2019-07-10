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
        self.assertIn('ModLoop: Modeling of Loops in Protein Structures',
                      rv.data)
        self.assertIn('ModLoop is a web server for automated modeling of loops',
                      rv.data)
        self.assertIn('Enter loop segments', rv.data)

    def test_contact(self):
        """Test contact page"""
        c = modloop.app.test_client()
        rv = c.get('/contact')
        self.assertIn('Please address inquiries to', rv.data)

    def test_help(self):
        """Test help page"""
        c = modloop.app.test_client()
        rv = c.get('/help')
        self.assertIn('Central bond too short', rv.data)

    def test_download(self):
        """Test download page"""
        c = modloop.app.test_client()
        rv = c.get('/download')
        self.assertIn('The ModLoop protocol is part of Modeller', rv.data)

    def test_queue(self):
        """Test queue page"""
        c = modloop.app.test_client()
        rv = c.get('/job')
        self.assertIn('No pending or running jobs', rv.data)


if __name__ == '__main__':
    unittest.main()
