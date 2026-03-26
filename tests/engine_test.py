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
    process = subprocess.Popen(
        ["./seyoawe.linux"], 
        stdout=subprocess.PIPE, 
        stderr=subprocess.PIPE,
        preexec_fn=os.setsid
    )
    
    try:
        # Give it a tiny bit of time, then check if it crashed instantly
        time.sleep(2)
        if process.poll() is not None:
            pytest.fail(f"Binary crashed instantly on boot! Exit code: {process.returncode}")
            
        success = False
        for _ in range(max_retries):
            try:
                response = requests.get(url)
                if response.status_code in [200, 404, 401, 403]:
                    success = True
                    break
            except requests.exceptions.ConnectionError:
                time.sleep(2)
        
        # 3. If it failed to connect after retries, fail the test
        if not success:
            pytest.fail("Engine booted, but never responded to port 5000 after 10 seconds.")
            
    finally:
        # 4. Clean up: Kill the background binary forcefully
        import signal
        try:
            os.killpg(os.getpgid(process.pid), signal.SIGTERM)
        except ProcessLookupError:
            pass