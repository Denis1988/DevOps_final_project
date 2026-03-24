import time
import requests
import pytest
import subprocess
import os

def test_flask_is_running():
    """Verify the pre-compiled Flask engine is up and responding."""
    url = "http://localhost:5000"
    max_retries = 5
    
    # 1. Start the compiled binary in the background
    # We use preexec_fn=os.setsid so we can cleanly kill it later
    process = subprocess.Popen(
        ["./seyoawe.linux"], 
        stdout=subprocess.PIPE, 
        stderr=subprocess.PIPE,
        preexec_fn=os.setsid
    )
    
    try:
        # 2. Poll the server until it responds (give it time to boot)
        success = False
        for _ in range(max_retries):
            try:
                response = requests.get(url)
                # If we get ANY status code, the server is running!
                if response.status_code in [200, 404, 401, 403]:
                    success = True
                    break
            except requests.exceptions.ConnectionError:
                # Server not ready yet, wait and try again
                time.sleep(2)
        
        # 3. Assert that the server eventually responded
        if not success:
            pytest.fail("Engine binary did not start or is not accessible on port 5000")
            
    finally:
        # 4. Clean up: ALWAYS kill the background binary so it doesn't hang the test suite
        import signal
        try:
            os.killpg(os.getpgid(process.pid), signal.SIGTERM)
        except ProcessLookupError:
            pass # Process already died