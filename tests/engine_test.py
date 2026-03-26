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
        success = False
        for _ in range(max_retries):
            try:
                response = requests.get(url)
                if response.status_code in [200, 404, 401, 403]:
                    success = True
                    break
            except requests.exceptions.ConnectionError:
                time.sleep(2)
        
        # 3. If it fails, pull the error logs from the binary and print them
        if not success:
            process.poll() # Check if process crashed
            stdout_data, stderr_data = process.communicate()
            error_msg = f"Engine failed to start!\n"
            if stderr_data:
                error_msg += f"STDERR: {stderr_data.decode('utf-8')}\n"
            if stdout_data:
                error_msg += f"STDOUT: {stdout_data.decode('utf-8')}\n"
            
            pytest.fail(error_msg)
            
    finally:
        import signal
        try:
            os.killpg(os.getpgid(process.pid), signal.SIGTERM)
        except ProcessLookupError:
            pass