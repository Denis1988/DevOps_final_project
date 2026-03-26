import time
import requests
import pytest
import subprocess
import os

def test_flask_is_running():
    """Verify the pre-compiled Flask engine is up and responding."""
    url = "http://localhost:5000"
    max_retries = 5
    
    # Start the compiled binary
    process = subprocess.Popen(
        ["./seyoawe.linux"], 
        stdout=subprocess.PIPE, 
        stderr=subprocess.PIPE,
        preexec_fn=os.setsid
    )
    
    try:
        # Check immediately if it crashed on boot
        time.sleep(1) 
        if process.poll() is not None:
            stdout, stderr = process.communicate()
            pytest.fail(f"Binary crashed immediately!\nSTDOUT:\n{stdout.decode()}\nSTDERR:\n{stderr.decode()}")
            
        success = False
        for _ in range(max_retries):
            try:
                response = requests.get(url)
                if response.status_code in [200, 404, 401, 403]:
                    success = True
                    break
            except requests.exceptions.ConnectionError:
                time.sleep(2)
        
        if not success:
            process.poll()
            stdout_data, stderr_data = process.communicate()
            pytest.fail(f"Engine failed to answer port 5000!\nSTDERR:\n{stderr_data.decode()}\nSTDOUT:\n{stdout_data.decode()}")
            
    finally:
        import signal
        try:
            os.killpg(os.getpgid(process.pid), signal.SIGTERM)
        except ProcessLookupError:
            pass