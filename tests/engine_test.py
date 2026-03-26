import time
import requests
import pytest
import subprocess
import os

def test_flask_is_running():
    """Verify the pre-compiled Flask engine is up and responding."""
    url = "http://localhost:8080"
    max_retries = 15  # Increased to 15 retries (30 seconds total)
    
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
            stdout, stderr = process.communicate()
            pytest.fail(f"Binary crashed instantly on boot! Exit code: {process.returncode}\nSTDERR: {stderr.decode()}\nSTDOUT: {stdout.decode()}")
            
        success = False
        for i in range(max_retries):
            try:
                response = requests.get(url, timeout=2)
                if response.status_code in [200, 404, 401, 403]:
                    success = True
                    break
            except (requests.exceptions.ConnectionError, requests.exceptions.Timeout):
                time.sleep(2)
        
        # 3. If it failed to connect after 30 seconds, fail the test and print logs
        if not success:
            # Force kill it so we can read the output buffer
            import signal
            os.killpg(os.getpgid(process.pid), signal.SIGTERM)
            stdout, stderr = process.communicate()
            pytest.fail(f"Engine never responded to port 5000 after 30 seconds.\n--- SERVER LOGS ---\nSTDOUT: {stdout.decode()}\nSTDERR: {stderr.decode()}")
            
    finally:
        # 4. Clean up: Kill the background binary gracefully
        import signal
        try:
            os.killpg(os.getpgid(process.pid), signal.SIGTERM)
        except ProcessLookupError:
            pass