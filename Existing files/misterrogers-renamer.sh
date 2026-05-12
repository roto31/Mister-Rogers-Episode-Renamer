#!/bin/bash
# Mister Rogers' Neighborhood Episode Renamer - Bash Wrapper
# 
# Simple shell script to invoke the Python renamer without typing the full python3 command.
# 
# Installation:
#   1. Save this file as "misterrogers-renamer" in ~/bin/ or /usr/local/bin/
#   2. Make executable: chmod +x ~/bin/misterrogers-renamer
#   3. Use: misterrogers-renamer /path/to/videos/
#
# Alternatively, add an alias to ~/.zshrc or ~/.bash_profile:
#   alias mrn-rename='python3 /path/to/misterrogers_renamer.py'
#

# Configuration - adjust these paths to match your system
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_RENAMER="${SCRIPT_DIR}/misterrogers_renamer.py"

# Fallback paths if not found in same directory
if [ ! -f "$PYTHON_RENAMER" ]; then
    PYTHON_RENAMER="$(dirname "$0")/misterrogers_renamer.py"
fi

if [ ! -f "$PYTHON_RENAMER" ]; then
    echo "Error: Could not find misterrogers_renamer.py"
    echo "Expected location: ${SCRIPT_DIR}/misterrogers_renamer.py"
    exit 1
fi

# Check Python is available
if ! command -v python3 &> /dev/null; then
    echo "Error: Python 3 is not installed"
    echo "Install with: brew install python3"
    exit 1
fi

# Pass all arguments to the Python script
exec python3 "$PYTHON_RENAMER" "$@"
