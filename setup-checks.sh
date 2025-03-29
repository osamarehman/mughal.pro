#!/bin/bash

# Server Setup Checks Script
# This script contains functions to check if the system has the required dependencies

# Check if running as root
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        print_error "This script must be run as root"
        return 1
    fi
    return 0
}

# Check if Docker is installed and install if needed
check_docker() {
    # Set flags to track Docker status
    DOCKER_INSTALLED=false
    DOCKER_COMPOSE_INSTALLED=false
    DOCKER_RUNNING=false
    
    # Check if Docker is installed
    if ! command -v docker &> /dev/null; then
        print_warning "Docker is not installed"
        
        if prompt_yes_no "Would you like to install Docker now?"; then
            print_info "Installing Docker..."
            
            # Install Docker using the official script
            curl -fsSL https://get.docker.com -o get-docker.sh
            
            # Execute the script and capture the result
            if sh get-docker.sh; then
                print_success "Docker installed successfully"
                DOCKER_INSTALLED=true
                
                # Start and enable Docker service
                if systemctl start docker && systemctl enable docker; then
                    print_success "Docker service started and enabled"
                    DOCKER_RUNNING=true
                else
                    print_warning "Failed to start Docker service"
                fi
                
                # Add current user to docker group
                if [ -n "$SUDO_USER" ]; then
                    if usermod -aG docker $SUDO_USER; then
                        print_info "Added user $SUDO_USER to the docker group"
                        print_info "You may need to log out and back in for this to take effect"
                    else
                        print_warning "Failed to add user to docker group"
                    fi
                fi
            else
                print_warning "Docker installation failed"
                print_info "The script will continue, but Docker-dependent features will be disabled"
            fi
            
            # Clean up
            rm -f get-docker.sh
        else
            print_info "Docker installation skipped"
            print_info "The script will continue, but Docker-dependent features will be disabled"
        fi
    else
        print_success "Docker is installed"
        DOCKER_INSTALLED=true
        
        # Check if Docker is running
        if docker info &>/dev/null; then
            print_success "Docker is running"
            DOCKER_RUNNING=true
        else
            print_warning "Docker is installed but not running"
            
            if prompt_yes_no "Would you like to start Docker now?"; then
                if systemctl start docker && systemctl enable docker; then
                    print_success "Docker service started and enabled"
                    DOCKER_RUNNING=true
                else
                    print_warning "Failed to start Docker service"
                    print_info "The script will continue, but Docker-dependent features may not work"
                fi
            else
                print_info "Docker will not be started"
                print_info "The script will continue, but Docker-dependent features may not work"
            fi
        fi
    fi
    
    # Check for Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        print_warning "Docker Compose is not installed"
        
        # Only attempt to install Docker Compose if Docker is installed
        if $DOCKER_INSTALLED && prompt_yes_no "Would you like to install Docker Compose now?"; then
            print_info "Installing Docker Compose..."
            
            # Try to get the latest version, with fallback
            COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4 || echo "v2.20.0")
            
            # Install Docker Compose
            if curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose && chmod +x /usr/local/bin/docker-compose; then
                print_success "Docker Compose installed successfully"
                DOCKER_COMPOSE_INSTALLED=true
            else
                print_warning "Docker Compose installation failed"
                print_info "The script will continue, but Docker Compose features will be disabled"
            fi
        else
            print_info "Docker Compose installation skipped"
            print_info "The script will continue, but Docker Compose features will be disabled"
        fi
    else
        print_success "Docker Compose is installed"
        DOCKER_COMPOSE_INSTALLED=true
    fi
    
    # Set global variables to track Docker status
    export DOCKER_INSTALLED
    export DOCKER_COMPOSE_INSTALLED
    export DOCKER_RUNNING
    
    # Provide summary
    print_info "Docker status summary:"
    print_info "- Docker installed: $(if $DOCKER_INSTALLED; then echo "Yes"; else echo "No"; fi)"
    print_info "- Docker running: $(if $DOCKER_RUNNING; then echo "Yes"; else echo "No"; fi)"
    print_info "- Docker Compose installed: $(if $DOCKER_COMPOSE_INSTALLED; then echo "Yes"; else echo "No"; fi)"
}

# Check if required commands are available and install if needed
check_commands() {
    local missing_commands=()
    local failed_installs=()
    local all_installed=true
    
    # Define required and optional commands
    local required_commands=(openssl curl)
    local optional_commands=(jq argon2)
    
    # Check required commands
    for cmd in "${required_commands[@]}"; do
        if ! command -v $cmd &> /dev/null; then
            missing_commands+=($cmd)
            all_installed=false
        fi
    done
    
    # Check optional commands
    for cmd in "${optional_commands[@]}"; do
        if ! command -v $cmd &> /dev/null; then
            print_warning "Optional command '$cmd' is not installed"
        fi
    done
    
    # Install missing required commands
    if [ ${#missing_commands[@]} -gt 0 ]; then
        print_warning "The following required commands are not installed: ${missing_commands[*]}"
        
        if prompt_yes_no "Would you like to install the missing commands now?"; then
            print_info "Installing missing commands..."
            
            # Try to detect package manager
            if command -v apt-get &> /dev/null; then
                print_info "Using apt package manager"
                
                # Update package lists
                if ! apt-get update; then
                    print_warning "Failed to update package lists"
                fi
                
                # Install each command individually to track failures
                for cmd in "${missing_commands[@]}"; do
                    print_info "Installing $cmd..."
                    if apt-get install -y $cmd; then
                        print_success "$cmd installed successfully"
                    else
                        print_warning "Failed to install $cmd"
                        failed_installs+=($cmd)
                    fi
                done
            elif command -v yum &> /dev/null; then
                print_info "Using yum package manager"
                
                # Install each command individually to track failures
                for cmd in "${missing_commands[@]}"; do
                    print_info "Installing $cmd..."
                    if yum install -y $cmd; then
                        print_success "$cmd installed successfully"
                    else
                        print_warning "Failed to install $cmd"
                        failed_installs+=($cmd)
                    fi
                done
            elif command -v dnf &> /dev/null; then
                print_info "Using dnf package manager"
                
                # Install each command individually to track failures
                for cmd in "${missing_commands[@]}"; do
                    print_info "Installing $cmd..."
                    if dnf install -y $cmd; then
                        print_success "$cmd installed successfully"
                    else
                        print_warning "Failed to install $cmd"
                        failed_installs+=($cmd)
                    fi
                done
            else
                print_warning "Could not detect package manager (apt, yum, or dnf)"
                print_warning "Please install the following commands manually: ${missing_commands[*]}"
                failed_installs=("${missing_commands[@]}")
            fi
            
            # Check if all installations were successful
            if [ ${#failed_installs[@]} -eq 0 ]; then
                print_success "All missing commands installed successfully"
                all_installed=true
            else
                print_warning "Failed to install some commands: ${failed_installs[*]}"
                print_warning "The script will continue, but some features may not work properly"
            fi
        else
            print_info "Command installation skipped"
            print_info "The script will continue, but some features may not work properly"
            failed_installs=("${missing_commands[@]}")
        fi
    else
        print_success "All required commands are installed"
    fi
    
    # Try to install optional commands if not already present
    for cmd in "${optional_commands[@]}"; do
        if ! command -v $cmd &> /dev/null; then
            print_info "Attempting to install optional command: $cmd"
            
            # Try to detect package manager
            if command -v apt-get &> /dev/null; then
                apt-get install -y $cmd &> /dev/null
            elif command -v yum &> /dev/null; then
                yum install -y $cmd &> /dev/null
            elif command -v dnf &> /dev/null; then
                dnf install -y $cmd &> /dev/null
            fi
            
            # Check if installation was successful
            if command -v $cmd &> /dev/null; then
                print_success "Optional command $cmd installed successfully"
            else
                print_info "Could not install optional command $cmd"
                print_info "The script will continue with alternative methods"
            fi
        fi
    done
    
    # Set global variable to track command status
    export ALL_COMMANDS_INSTALLED=$all_installed
    
    # Return success even if some commands failed to install
    # The script will adapt to missing commands
    return 0
}

# Run all checks
run_checks() {
    print_header "System Checks"
    
    # Track overall status
    local checks_passed=true
    
    # Check if running as root
    if ! check_root; then
        print_error "Root check failed"
        print_info "This script must be run as root or with sudo"
        return 1
    fi
    
    # Check if Docker is installed
    check_docker
    
    # Check if required commands are available
    check_commands
    
    # Determine if all essential checks passed
    if $DOCKER_INSTALLED && $DOCKER_COMPOSE_INSTALLED && $DOCKER_RUNNING && $ALL_COMMANDS_INSTALLED; then
        print_success "All system checks passed successfully"
    else
        print_warning "Some system checks did not pass"
        print_info "The script will continue with limited functionality"
        
        # Summarize what's missing
        if ! $DOCKER_INSTALLED; then
            print_warning "Docker is not installed - Docker-dependent features will be disabled"
        elif ! $DOCKER_RUNNING; then
            print_warning "Docker is not running - Docker-dependent features may not work"
        fi
        
        if ! $DOCKER_COMPOSE_INSTALLED; then
            print_warning "Docker Compose is not installed - Docker Compose features will be disabled"
        fi
        
        if ! $ALL_COMMANDS_INSTALLED; then
            print_warning "Some required commands are missing - Some features may not work properly"
        fi
    fi
    
    # Always return success to allow the script to continue
    return 0
}
