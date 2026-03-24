import pytest
from app import app  # Replace 'app' with whatever file your Flask app object lives in

@pytest.fixture
def client():
    """Create a Flask test client fixture."""
    app.config['TESTING'] = True
    with app.test_client() as client:
        yield client

def test_flask_is_running(client):
    """Verify the Flask engine is up and responding."""
    # Send a request using the test client, not requests.get()
    response = client.get('/')
    
    # Check that we get a response back (200, 404, etc. all prove Flask processed the request)
    assert response.status_code in [200, 404, 401, 403]