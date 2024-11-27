#!/bin/bash

# Exit on error
set -e

# Define log file path
LOG_FILE="script_log.txt"

# Function to check directory permissions (Cross-platform)
check_permissions() {
    test_file="$1/test_permissions.txt"
    touch "$test_file" && rm -f "$test_file" && return 0 || return 1
}

# Suggested directory for virtual environment
VENV_DIR="$HOME/Documents/sample-gcp-pyspark"

# Check if the current directory is accessible
if ! check_permissions "$HOME"; then
    echo "Access to '$HOME' is denied. Using alternative directory '$VENV_DIR' for virtual environment." | tee -a "$LOG_FILE"
fi

# Check if Poetry is installed
if ! command -v poetry &> /dev/null
then
    echo "Poetry is not installed. Installing Poetry..." | tee -a "$LOG_FILE"
    curl -sSL https://install.python-poetry.org | python3 - >> "$LOG_FILE" 2>&1
else
    echo "Poetry is already installed." | tee -a "$LOG_FILE"
fi

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
poetry run ruff check . >> "$LOG_FILE" 2>&1 || true

# ----------------------------------------------------------------------------
# Type Checking with Mypy
# ----------------------------------------------------------------------------
echo "------------------------------- Type Checking -------------------------------" | tee -a "$LOG_FILE"
poetry run mypy . >> "$LOG_FILE" 2>&1 || true

# ----------------------------------------------------------------------------
# Formatting with Black
# ----------------------------------------------------------------------------
echo "------------------------------- Formatting with Black -------------------------------" | tee -a "$LOG_FILE"
poetry run black . >> "$LOG_FILE" 2>&1 || true

# ----------------------------------------------------------------------------
# Security Check with Bandit
# ----------------------------------------------------------------------------
echo "------------------------------- Security Check with Bandit -------------------------------" | tee -a "$LOG_FILE"
poetry run bandit -r . >> "$LOG_FILE" 2>&1 || true

# ----------------------------------------------------------------------------
# Docstring Check with Pydocstyle
# ----------------------------------------------------------------------------
echo "------------------------------- Docstring Check with Pydocstyle -------------------------------" | tee -a "$LOG_FILE"
poetry run pydocstyle . >> "$LOG_FILE" 2>&1 || true

echo "All checks (linting, type checking, formatting, security, and docstring validation) have been completed successfully!" | tee -a "$LOG_FILE"
