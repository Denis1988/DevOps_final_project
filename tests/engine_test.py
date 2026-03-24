import requests
import time
import pytest

def test_flask_is_running():
    """Verify the Flask engine is up and responding."""
    url = "http://localhost:5000"
    max_retries = 5
    
    for _ in range(max_retries):
        try:
            # Send a request to the server. Even if the route doesn't exist (404),
            # receiving an HTTP status code proves Flask is running.
            response = requests.get(url)
            assert response.status_code in [200, 404, 401, 403]
            return
        except requests.exceptions.ConnectionError:
            # If the container is still booting, wait and retry
            time.sleep(2)
            
    pytest.fail("Engine (Flask server) did not start or is not accessible on port 5000")