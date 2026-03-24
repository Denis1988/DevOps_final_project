import subprocess
import os
import shutil

# Assumes tests are run from the directory containing sawectl.py
CLI_SCRIPT = "python3 sawectl/sawectl.py"

def test_init_module():
    """Test generating a new module."""
    # Note: Because we will run this inside the sawectl folder, 
    # the module_dir should just be "modules/test_slack_module"
    module_dir = "sawectl/modules/test_slack_module"
    if os.path.exists(module_dir):
        shutil.rmtree(module_dir)
        
    # Add cwd="sawectl" and run just "python3 sawectl.py"
    result = subprocess.run("python3 sawectl.py init module test_slack_module", shell=True, capture_output=True, text=True, cwd="sawectl")
    assert result.returncode == 0, f"Init module failed: {result.stderr}"
    assert os.path.exists(f"{module_dir}/module.yaml")
    assert os.path.exists(f"{module_dir}/test_slack_module.py")

def test_init_workflow():
    """Test generating a new minimal workflow file."""
    workflow_file = "workflows/test_flow.yaml"
    if os.path.exists(workflow_file):
        os.remove(workflow_file)
        
    result = subprocess.run(f"{CLI_SCRIPT} init workflow test_flow", shell=True, capture_output=True, text=True)
    assert result.returncode == 0, f"Init workflow failed: {result.stderr}"
    assert os.path.exists(workflow_file)

def test_validate_modules():
    """Test that generated module manifests are valid."""
    result = subprocess.run(f"{CLI_SCRIPT} validate-modules", shell=True, capture_output=True, text=True)
    assert result.returncode == 0, f"Module validation failed: {result.stderr}"

def test_validate_workflow():
    """Test that the generated workflow is valid."""
    result = subprocess.run(f"{CLI_SCRIPT} validate-workflow --workflow workflows/test_flow.yaml", shell=True, capture_output=True, text=True)
    assert result.returncode == 0, f"Workflow validation failed: {result.stderr}"