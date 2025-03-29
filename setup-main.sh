#!/bin/bash

# Server Setup Main Script
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

# Source all script files
source "$SCRIPT_DIR/setup-utils.sh"
source "$SCRIPT_DIR/setup-checks.sh"
source "$SCRIPT_DIR/setup-services.sh"
source "$SCRIPT_DIR/setup-resources.sh"
source "$SCRIPT_DIR/setup-directories.sh"
source "$SCRIPT_DIR/setup-credentials.sh"

# Default values
DEFAULT_DATA_DIR="/opt/docker"
DEFAULT_BACKUP_DIR="/opt/backup"
DEFAULT_TIMEZONE="UTC"

# Main function
main() {
    print_header "Server Setup Script"
    
    # Check if running as root
    check_root
    
    # Check if Docker is installed
    check_docker
    
    # Check if required commands are available
    check_commands
    
    # Prompt for basic information
    print_header "Basic Information"
    
    # Prompt for domain name
    DOMAIN=$(prompt_domain)
    print_info "Domain: $DOMAIN"
    
    # Prompt for email address
    EMAIL=$(prompt_email)
    print_info "Email: $EMAIL"
    
    # Prompt for data directory
    DATA_DIR=$(prompt_with_default "Enter the data directory" "$DEFAULT_DATA_DIR")
    print_info "Data directory: $DATA_DIR"
    
    # Prompt for backup directory
    BACKUP_DIR=$(prompt_with_default "Enter the backup directory" "$DEFAULT_BACKUP_DIR")
    print_info "Backup directory: $BACKUP_DIR"
    
    # Prompt for timezone
    TIMEZONE=$(prompt_timezone)
    print_info "Timezone: $TIMEZONE"
    
    # Prompt for services to enable
    print_header "Services"
    
    # Initialize service flags
    ENABLE_MARIADB=false
    ENABLE_POSTGRES=false
    ENABLE_REDIS=false
    ENABLE_VAULTWARDEN=false
    ENABLE_GRAFANA=false
    ENABLE_PROMETHEUS=false
    ENABLE_DOCMOST=false
    ENABLE_CODE_SERVER=false
    ENABLE_HOMEASSISTANT=false
    ENABLE_OWNCLOUD=false
    ENABLE_PORTAINER=false
    ENABLE_ITTOOLS=false
    ENABLE_LOKI=false
    ENABLE_BORGMATIC=false
    ENABLE_WIREGUARD=false
    
    # Prompt for each service
    prompt_services
    
    # Prompt for resource limits
    print_header "Resource Limits"
    
    # Initialize resource limits arrays
    declare -A MEMORY_LIMITS
    declare -A CPU_LIMITS
    
    # Prompt for resource limits for each service
    prompt_resource_limits
    
    # Generate credentials
    print_header "Generating Credentials"
    generate_credentials
    
    # Create directory structure
    create_directory_structure
    
    # Generate configuration files
    generate_configurations
    
    # Generate Docker Compose file
    print_header "Generating Docker Compose File"
    generate_docker_compose "$DATA_DIR/compose/docker-compose.yml" "$DOMAIN"
    
    # Generate .env file
    generate_env_file "$DATA_DIR/compose/.env"
    
    # Save credentials to a secure file
    print_header "Saving Credentials"
    save_credentials
    
    # Start services
    print_header "Starting Services"
    
    if prompt_yes_no "Do you want to start the services now?"; then
        cd "$DATA_DIR/compose"
        docker-compose pull
        docker-compose up -d
        
        print_success "Services started"
        
        # Print DNS information
        print_header "DNS Information"
        cat "$DATA_DIR/dns_info.txt"
        
        print_header "Setup Complete"
        print_info "Your server has been set up successfully"
        print_info "You can access your services at https://$DOMAIN"
        print_info "Credentials have been saved to $DATA_DIR/credentials.txt"
        print_info "DNS information has been saved to $DATA_DIR/dns_info.txt"
        print_info "Make sure to configure your DNS records as described in the DNS information"
    else
        print_info "Services not started"
        print_info "You can start them later with the following commands:"
        echo "cd $DATA_DIR/compose"
        echo "docker-compose pull"
        echo "docker-compose up -d"
        
        print_header "Setup Complete"
        print_info "Your server has been set up successfully"
        print_info "Credentials have been saved to $DATA_DIR/credentials.txt"
        print_info "DNS information has been saved to $DATA_DIR/dns_info.txt"
        print_info "Make sure to configure your DNS records as described in the DNS information"
    fi
}

# Run main function
main
