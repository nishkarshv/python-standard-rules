#!/bin/bash

# Exit on error
set -e

# Function to check directory permissions (Cross-platform)
check_permissions() {
    test_file="$1/test_permissions.txt"
    touch "$test_file" && rm -f "$test_file" && return 0 || return 1
}

# Function to expand ~ to full path and resolve . to current directory
expand_tilde_and_dot() {
    local path="$1"
    # Replace ~ with $HOME and resolve . to current working directory
    path="${path//\~/$HOME}"
    if [[ "$path" == "." ]]; then
        path=$(pwd)  # Resolve . to the current directory
    fi
    echo "$path"
}

# Prompt user for input
read -p "Enter the directory to create the virtual environment: " VENV_DIR
read -p "Enter the directory to scan the code (project folder): " CODE_DIR
read -p "Enter the folder to store the log file: " LOG_DIR

# Expand tilde (~) and resolve . to current directory in the directories
VENV_DIR=$(expand_tilde_and_dot "$VENV_DIR")
CODE_DIR=$(expand_tilde_and_dot "$CODE_DIR")
LOG_DIR=$(expand_tilde_and_dot "$LOG_DIR")

# Default log file name
LOG_FILE="$LOG_DIR/script_log.txt"

# Default virtual environment directory
DEFAULT_VENV_DIR="$HOME/Documents/default_venv"

# Check if the provided directories exist, if not, exit
if [[ ! -d "$CODE_DIR" ]]; then
    echo "Directory to scan the code ($CODE_DIR) does not exist. Please create it first."
    exit 1
fi

if [[ ! -d "$LOG_DIR" ]]; then
    echo "Log directory ($LOG_DIR) does not exist. Please create it first."
    exit 1
fi

# Check if the provided virtual environment directory exists and is accessible
if [[ ! -d "$VENV_DIR" ]] || ! check_permissions "$VENV_DIR"; then
    echo "Directory for virtual environment ($VENV_DIR) does not exist or is not accessible. Using default directory ($DEFAULT_VENV_DIR) for virtual environment." | tee -a "$LOG_FILE"
    VENV_DIR="$DEFAULT_VENV_DIR"
    # Create the default virtual environment directory if it doesn't exist
    if [[ ! -d "$VENV_DIR" ]]; then
        mkdir -p "$VENV_DIR"
        echo "Created default virtual environment directory at $VENV_DIR" | tee -a "$LOG_FILE"
    fi
fi

# Echo the path of the virtual environment directory
echo "Using virtual environment directory: $VENV_DIR" | tee -a "$LOG_FILE"

# Check if Poetry is installed
if ! command -v poetry &> /dev/null
then
    echo "Poetry is not installed. Installing Poetry..." | tee -a "$LOG_FILE"
    curl -sSL https://install.python-poetry.org | python3 - >> "$LOG_FILE" 2>&1
else
    echo "Poetry is already installed." | tee -a "$LOG_FILE"
fi

# Set Poetry to create virtual environments in the project directory
poetry config virtualenvs.in-project true >> "$LOG_FILE" 2>&1

# Create the virtual environment if it doesn't exist
echo "Creating virtual environment with Poetry..." | tee -a "$LOG_FILE"
poetry env use python >> "$LOG_FILE" 2>&1

# Install development tools
DEVELOPMENT_TOOLS=(black mypy ruff bandit pydocstyle)

for tool in "${DEVELOPMENT_TOOLS[@]}"; do
    echo "Checking if $tool is installed..." | tee -a "$LOG_FILE"
    if ! poetry show "$tool" &> /dev/null; then
        echo "$tool is not installed. Installing $tool..." | tee -a "$LOG_FILE"
        poetry add --group dev "$tool" >> "$LOG_FILE" 2>&1
    else
        echo "$tool is already installed." | tee -a "$LOG_FILE"
    fi
done

# Install project dependencies
echo "Installing project dependencies using Poetry..." | tee -a "$LOG_FILE"
poetry install >> "$LOG_FILE" 2>&1

# ----------------------------------------------------------------------------
# Lint Checking with Ruff
# ----------------------------------------------------------------------------
echo "------------------------------- Lint Checking -------------------------------" | tee -a "$LOG_FILE"
poetry run ruff check "$CODE_DIR" >> "$LOG_FILE" 2>&1 || true

# ----------------------------------------------------------------------------
# Type Checking with Mypy
# ----------------------------------------------------------------------------
echo "------------------------------- Type Checking -------------------------------" | tee -a "$LOG_FILE"
poetry run mypy "$CODE_DIR" >> "$LOG_FILE" 2>&1 || true

# ----------------------------------------------------------------------------
# Formatting with Black
# ----------------------------------------------------------------------------
echo "------------------------------- Formatting with Black -------------------------------" | tee -a "$LOG_FILE"
poetry run black "$CODE_DIR" >> "$LOG_FILE" 2>&1 || true

# ----------------------------------------------------------------------------
# Security Check with Bandit
# ----------------------------------------------------------------------------
echo "------------------------------- Security Check with Bandit -------------------------------" | tee -a "$LOG_FILE"
poetry run bandit -r "$CODE_DIR" >> "$LOG_FILE" 2>&1 || true

# ----------------------------------------------------------------------------
# Docstring Check with Pydocstyle
# ----------------------------------------------------------------------------
echo "------------------------------- Docstring Check with Pydocstyle -------------------------------" | tee -a "$LOG_FILE"
poetry run pydocstyle "$CODE_DIR" >> "$LOG_FILE" 2>&1 || true

echo "All checks (linting, type checking, formatting, security, and docstring validation) have been completed successfully!" | tee -a "$LOG_FILE"
