#!/bin/bash

# Script to make all troubleshooting scripts executable

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print functions
print_header() {
    echo -e "\n${BLUE}=== $1 ===${NC}\n"
}

print_info() {
    echo -e "${BLUE}INFO:${NC} $1"
}

print_success() {
    echo -e "${GREEN}SUCCESS:${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}WARNING:${NC} $1"
}

print_error() {
    echo -e "${RED}ERROR:${NC} $1"
}

# Main function
main() {
    print_header "Making Troubleshooting Scripts Executable"
    print_info "This script will make all troubleshooting scripts executable"
    
    # List of scripts to make executable
    scripts=(
        "fix-containers.sh"
        "fix-caddy.sh"
        "fix-caddy-auth.sh"
        "fix-owncloud.sh"
        "fix-remaining-issues.sh"
        "fix-authelia-hash.sh"
        "fix-redis-config.sh"
        "check-container-configs.sh"
        "cleanup-docker.sh"
        "setup.sh"
        "setup-main.sh"
        "setup-directories.sh"
        "setup-credentials.sh"
        "setup-services.sh"
        "setup-resources.sh"
        "setup-utils.sh"
        "setup-checks.sh"
    )
    
    # Make each script executable
    for script in "${scripts[@]}"; do
        if [ -f "$script" ]; then
            print_info "Making $script executable..."
            chmod +x "$script"
            if [ $? -eq 0 ]; then
                print_success "$script is now executable"
            else
                print_error "Failed to make $script executable"
            fi
        else
            print_warning "$script not found, skipping"
        fi
    done
    
    # Make all .sh files executable
    print_info "Making all .sh files in the current directory executable..."
    for script in *.sh; do
        if [ -f "$script" ]; then
            chmod +x "$script"
            if [ $? -eq 0 ]; then
                print_success "$script is now executable"
            else
                print_error "Failed to make $script executable"
            fi
        fi
    done
    
    print_header "All Scripts Are Now Executable"
    print_info "You can now run the scripts directly, for example:"
    print_info "  ./fix-containers.sh"
    print_info "  ./fix-caddy.sh"
    print_info "  ./fix-owncloud.sh"
    print_info "  ./fix-remaining-issues.sh"
}

# Run main function
main
