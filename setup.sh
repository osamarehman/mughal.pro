#!/bin/bash

# Server Setup Script
# This script is the main entry point for the server setup process
# It sources all other script files and runs the main function

# Exit on error
set -e

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Make all script files executable
chmod +x "$SCRIPT_DIR/setup-utils.sh"
chmod +x "$SCRIPT_DIR/setup-checks.sh"
chmod +x "$SCRIPT_DIR/setup-services.sh"
chmod +x "$SCRIPT_DIR/setup-resources.sh"
chmod +x "$SCRIPT_DIR/setup-directories.sh"
chmod +x "$SCRIPT_DIR/setup-credentials.sh"
chmod +x "$SCRIPT_DIR/setup-main.sh"

# Source all script files
source "$SCRIPT_DIR/setup-utils.sh"
source "$SCRIPT_DIR/setup-checks.sh"
source "$SCRIPT_DIR/setup-services.sh"
source "$SCRIPT_DIR/setup-resources.sh"
source "$SCRIPT_DIR/setup-directories.sh"
source "$SCRIPT_DIR/setup-credentials.sh"
source "$SCRIPT_DIR/setup-main.sh"

# Run main function
main
