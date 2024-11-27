import os
import subprocess
import sys
import argparse
import shutil
from datetime import datetime


# Function to check directory permissions
def check_permissions(directory):
    test_file = os.path.join(directory, "test_permissions.txt")
    try:
        with open(test_file, "w"):
            pass
        os.remove(test_file)
        return True
    except PermissionError:
        return False


# Function to install Poetry
def install_poetry():
    print("Poetry is not installed. Installing Poetry...")
    subprocess.run(
        ["curl", "-sSL", "https://install.python-poetry.org", "|", "python3"],
        check=True,
    )


# Function to create a virtual environment with Poetry
def create_virtualenv():
    print("Creating virtual environment with Poetry...")
    subprocess.run(["poetry", "env", "use", "python"], check=True)


# Function to install development tools
def install_tools():
    tools = ["black", "mypy", "ruff", "bandit", "pydocstyle"]
    for tool in tools:
        print(f"Checking if {tool} is installed...")
        if subprocess.call(["poetry", "show", tool]) != 0:
            print(f"{tool} is not installed. Installing {tool}...")
            subprocess.run(["poetry", "add", "--group", "dev", tool], check=True)
        else:
            print(f"{tool} is already installed.")


# Function to install project dependencies
def install_dependencies():
    print("Installing project dependencies using Poetry...")
    subprocess.run(["poetry", "install"], check=True)


# Function to run checks (Linting, Type Checking, etc.)
def run_checks(project_folder, log_file):
    checks = [
        ("Lint Checking", ["ruff", "check", "."]),
        ("Type Checking", ["mypy", "."]),
        ("Formatting with Black", ["black", "."]),
        ("Security Check with Bandit", ["bandit", "-r", "."]),
        ("Docstring Check with Pydocstyle", ["pydocstyle", "."]),
    ]

    os.chdir(
        project_folder
    )  # Change to the project folder where checks will be applied

    for description, command in checks:
        print(
            f"------------------------------- {description} -------------------------------"
        )
        try:
            result = subprocess.run(command, check=True, text=True, capture_output=True)
            # Log the output if the command was successful
            try:
                with open(log_file, "a") as f:
                    f.write(f"{description} succeeded.\n")
                    f.write(result.stdout)
            except FileNotFoundError:
                print(f"Log file not found. Output for {description}:\n{result.stdout}")
        except subprocess.CalledProcessError as e:
            # Log the error if the command fails
            try:
                with open(log_file, "a") as f:
                    f.write(f"{description} failed with error:\n")
                    f.write(e.stderr)
                    f.write("\n")
            except FileNotFoundError:
                print(f"Log file not found. Error for {description}:\n{e.stderr}")


# Main function that will parse arguments and execute the package setup and checks
def main():
    # Set up argument parsing
    parser = argparse.ArgumentParser(
        description="Setup and check your Python project with Poetry."
    )
    parser.add_argument(
        "--env-dir",
        type=str,
        required=True,
        help="Directory for the virtual environment",
    )
    parser.add_argument(
        "--log-folder",
        type=str,
        required=True,
        help="Folder to store the log file in",
    )
    parser.add_argument(
        "--project-folder",
        type=str,
        required=True,
        help="Folder where the checks will be applied",
    )

    # Parse the arguments
    args = parser.parse_args()

    # Generate a log filename dynamically based on current date and time
    timestamp = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
    log_file = os.path.join(args.log_folder, f"log_{timestamp}.txt")

    # Ensure the specified log folder exists, create it if it doesn't
    if not os.path.exists(args.log_folder):
        os.makedirs(args.log_folder)

    try:
        with open(log_file, "w") as f:
            f.write(f"Log file created: {log_file}\n")
    except FileNotFoundError:
        print(f"Log file {log_file} not found, output will be shown on stdout.")

    # Ensure the provided folder is accessible
    if not check_permissions(args.project_folder):
        print(f"Access to '{args.project_folder}' is denied.")
        try:
            with open(log_file, "a") as f:
                f.write(f"Access to '{args.project_folder}' is denied.\n")
        except FileNotFoundError:
            print(f"Log file {log_file} not found, logging to stdout.")
        return  # Don't exit, just return to finish the function.

    # Ensure Poetry is installed
    if shutil.which("poetry") is None:
        install_poetry()

    # Set the virtual environment directory
    venv_dir = args.env_dir

    # Create the virtual environment
    create_virtualenv()

    # Install development tools
    install_tools()

    # Install dependencies
    install_dependencies()

    # Run checks in the specified project folder and log results
    run_checks(args.project_folder, log_file)

    print(
        "All checks (linting, type checking, formatting, security, and docstring validation) have been completed!"
    )


if __name__ == "__main__":
    main()
