#!/bin/bash

# Server Setup Script
# This script automates the setup of a Docker-based server with various services
# It prompts for necessary information and generates configuration files

# Exit on error
set -e

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source helper scripts
source "$SCRIPT_DIR/docker-compose-services.sh"
source "$SCRIPT_DIR/config-generator.sh"

# Default values
DEFAULT_DATA_DIR="/opt/docker"
DEFAULT_BACKUP_DIR="/opt/backup"
DEFAULT_TIMEZONE="UTC"

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

# Check if running as root
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        print_error "This script must be run as root"
        exit 1
    fi
}

# Check if Docker is installed
check_docker() {
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed"
        print_info "Please install Docker before running this script"
        print_info "You can install Docker using the following command:"
        echo "curl -fsSL https://get.docker.com | sh"
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        print_error "Docker Compose is not installed"
        print_info "Please install Docker Compose before running this script"
        print_info "You can install Docker Compose using the following command:"
        echo "curl -L \"https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)\" -o /usr/local/bin/docker-compose"
        echo "chmod +x /usr/local/bin/docker-compose"
        exit 1
    fi
}

# Check if required commands are available
check_commands() {
    local missing_commands=()
    
    for cmd in openssl curl jq; do
        if ! command -v $cmd &> /dev/null; then
            missing_commands+=($cmd)
        fi
    done
    
    if [ ${#missing_commands[@]} -gt 0 ]; then
        print_error "The following commands are required but not installed: ${missing_commands[*]}"
        print_info "Please install them before running this script"
        print_info "You can install them using the following command:"
        echo "apt-get update && apt-get install -y ${missing_commands[*]}"
        exit 1
    fi
}

# Function to generate a secure password
generate_password() {
    openssl rand -base64 32  # Increased to 32 bytes for better security
}

# Function to generate a secure token
generate_token() {
    openssl rand -hex 32
}

# Function to generate an Argon2 hash
generate_argon2_hash() {
    local password=$1
    
    # Try using native argon2 if available
    if command -v argon2 &> /dev/null; then
        echo -n "$password" | argon2 "$(openssl rand -hex 8)" -id -t 3 -m 16 -p 4 -l 32 -e
    else
        # Fall back to Docker
        docker run --rm authelia/authelia:latest authelia crypto hash generate argon2 --password "$password"
    fi
}

# Function to prompt for yes/no
prompt_yes_no() {
    local prompt=$1
    local default=${2:-y}
    
    local yn
    while true; do
        read -p "$prompt [${default}]: " yn
        yn=${yn:-$default}
        case $yn in
            [Yy]* ) return 0;;
            [Nn]* ) return 1;;
            * ) echo "Please answer yes or no.";;
        esac
    done
}

# Function to prompt for a value with a default
prompt_with_default() {
    local prompt=$1
    local default=$2
    local value
    
    read -p "$prompt [$default]: " value
    echo ${value:-$default}
}

# Function to prompt for a password with confirmation
prompt_password() {
    local prompt=$1
    local generate=${2:-true}
    local password
    
    if $generate && prompt_yes_no "Generate a secure password automatically?"; then
        password=$(generate_password)
        echo "Generated password: $password"
        echo "$password"
        return
    fi
    
    while true; do
        read -s -p "$prompt: " password
        echo
        read -s -p "Confirm password: " password2
        echo
        
        if [ "$password" = "$password2" ]; then
            echo "$password"
            return
        else
            echo "Passwords do not match. Please try again."
        fi
    done
}

# Function to prompt for a domain name
prompt_domain() {
    local domain
    
    while true; do
        read -p "Enter your domain name (e.g., example.com): " domain
        
        if [[ $domain =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{1,61}[a-zA-Z0-9]\.[a-zA-Z]{2,}$ ]]; then
            echo "$domain"
            return
        else
            echo "Invalid domain name. Please enter a valid domain name."
        fi
    done
}

# Function to prompt for an email address
prompt_email() {
    local email
    
    while true; do
        read -p "Enter your email address: " email
        
        if [[ $email =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
            echo "$email"
            return
        else
            echo "Invalid email address. Please enter a valid email address."
        fi
    done
}

# Function to prompt for a timezone
prompt_timezone() {
    local timezone
    
    # Get current timezone
    local current_timezone=$(timedatectl | grep "Time zone" | awk '{print $3}')
    
    # If current timezone is not available, use default
    current_timezone=${current_timezone:-$DEFAULT_TIMEZONE}
    
    # Prompt for timezone
    read -p "Enter your timezone [$current_timezone]: " timezone
    
    # Use default if empty
    timezone=${timezone:-$current_timezone}
    
    echo "$timezone"
}

# Function to prompt for resource limits
prompt_resource_limits() {
    local service=$1
    local memory_limit
    local cpu_limit
    
    if prompt_yes_no "Do you want to set resource limits for $service?"; then
        read -p "Enter memory limit for $service (e.g., 512m, 1g): " memory_limit
        read -p "Enter CPU limit for $service (e.g., 0.5, 1): " cpu_limit
        
        MEMORY_LIMITS[$service]=$memory_limit
        CPU_LIMITS[$service]=$cpu_limit
        
        print_info "Resource limits set for $service: Memory: $memory_limit, CPU: $cpu_limit"
    fi
}

# Function to create directory structure
create_directory_structure() {
    print_header "Creating Directory Structure"
    
    # Create main directories
    mkdir -p "$DATA_DIR"/{authelia,caddy,mariadb,redis,vaultwarden,grafana,prometheus,docmost,postgres}/config
    mkdir -p "$DATA_DIR/compose"
    mkdir -p "$DATA_DIR/caddy/site"
    mkdir -p "$DATA_DIR/caddy/data"
    
    # Create additional directories based on enabled services
    if $ENABLE_BORGMATIC; then
        mkdir -p "$DATA_DIR/borgmatic/config/scripts"
    fi
    
    if $ENABLE_LOKI; then
        mkdir -p "$DATA_DIR/loki/config"
        mkdir -p "$DATA_DIR/loki/data"
    fi
    
    if $ENABLE_CODE_SERVER; then
        mkdir -p "$DATA_DIR/code-server/config"
        mkdir -p "$DATA_DIR/code-server/data"
    fi
    
    if $ENABLE_HOMEASSISTANT; then
        mkdir -p "$DATA_DIR/homeassistant/config"
    fi
    
    if $ENABLE_OWNCLOUD; then
        mkdir -p "$DATA_DIR/owncloud/data"
    fi
    
    if $ENABLE_PORTAINER; then
        mkdir -p "$DATA_DIR/portainer/data"
    fi
    
    if $ENABLE_WIREGUARD; then
        mkdir -p "$DATA_DIR/wireguard/config"
    fi
    
    # Create backup directory
    mkdir -p "$BACKUP_DIR"
    
    # Set proper permissions
    chown -R $SUDO_USER:$SUDO_USER "$DATA_DIR"
    chown -R $SUDO_USER:$SUDO_USER "$BACKUP_DIR"
    
    print_success "Directory structure created"
}

# Function to generate configuration files
generate_configurations() {
    print_header "Generating Configuration Files"
    
    # Generate Caddy configuration
    generate_caddy_config "$DATA_DIR/caddy/config" "$DOMAIN" "$EMAIL"
    
    # Generate Authelia configuration
    generate_authelia_config "$DATA_DIR/authelia/config" "$DOMAIN" "$JWT_SECRET" "admin" "$ADMIN_HASH" "user" "$USER_HASH" "$EMAIL"
    
    # Generate MariaDB configuration if enabled
    if $ENABLE_MARIADB; then
        generate_mariadb_config "$DATA_DIR/mariadb/config"
    fi
    
    # Generate Redis configuration if enabled
    if $ENABLE_REDIS; then
        generate_redis_config "$DATA_DIR/redis"
    fi
    
    # Generate Prometheus configuration if enabled
    if $ENABLE_PROMETHEUS; then
        generate_prometheus_config "$DATA_DIR/prometheus/config" "$DOMAIN"
    fi
    
    # Generate Loki configuration if enabled
    if $ENABLE_LOKI; then
        generate_loki_config "$DATA_DIR/loki/config"
    fi
    
    # Generate Borgmatic configuration if enabled
    if $ENABLE_BORGMATIC; then
        generate_borgmatic_config "$DATA_DIR/borgmatic/config"
    fi
    
    # Generate welcome page
    generate_welcome_page "$DATA_DIR/caddy/site" "$DOMAIN"
    
    # Generate DNS information
    generate_dns_info "$DOMAIN" "$DATA_DIR/dns_info.txt"
    
    # Generate backup information
    generate_backup_info "$DATA_DIR/backup_info.txt" "$DATA_DIR" "$BACKUP_DIR"
    
    print_success "Configuration files generated"
}

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
    if prompt_yes_no "Enable MariaDB (MySQL database)?"; then
        ENABLE_MARIADB=true
        print_info "MariaDB enabled"
    fi
    
    if prompt_yes_no "Enable PostgreSQL database?"; then
        ENABLE_POSTGRES=true
        print_info "PostgreSQL enabled"
    fi
    
    if prompt_yes_no "Enable Redis (cache)?"; then
        ENABLE_REDIS=true
        print_info "Redis enabled"
    fi
    
    if prompt_yes_no "Enable Vaultwarden (password manager)?"; then
        ENABLE_VAULTWARDEN=true
        print_info "Vaultwarden enabled"
    fi
    
    if prompt_yes_no "Enable Grafana (monitoring dashboard)?"; then
        ENABLE_GRAFANA=true
        print_info "Grafana enabled"
    fi
    
    if prompt_yes_no "Enable Prometheus (monitoring system)?"; then
        ENABLE_PROMETHEUS=true
        print_info "Prometheus enabled"
    fi
    
    if prompt_yes_no "Enable DocMost (documentation)?"; then
        ENABLE_DOCMOST=true
        print_info "DocMost enabled"
        
        # DocMost requires PostgreSQL and Redis
        if ! $ENABLE_POSTGRES; then
            print_warning "DocMost requires PostgreSQL. Enabling PostgreSQL."
            ENABLE_POSTGRES=true
        fi
        
        if ! $ENABLE_REDIS; then
            print_warning "DocMost requires Redis. Enabling Redis."
            ENABLE_REDIS=true
        fi
    fi
    
    if prompt_yes_no "Enable Code Server (VS Code in browser)?"; then
        ENABLE_CODE_SERVER=true
        print_info "Code Server enabled"
    fi
    
    if prompt_yes_no "Enable Home Assistant (home automation)?"; then
        ENABLE_HOMEASSISTANT=true
        print_info "Home Assistant enabled"
    fi
    
    if prompt_yes_no "Enable OwnCloud (file storage)?"; then
        ENABLE_OWNCLOUD=true
        print_info "OwnCloud enabled"
        
        # OwnCloud requires MariaDB
        if ! $ENABLE_MARIADB; then
            print_warning "OwnCloud requires MariaDB. Enabling MariaDB."
            ENABLE_MARIADB=true
        fi
    fi
    
    if prompt_yes_no "Enable Portainer (Docker management)?"; then
        ENABLE_PORTAINER=true
        print_info "Portainer enabled"
    fi
    
    if prompt_yes_no "Enable IT Tools (collection of IT tools)?"; then
        ENABLE_ITTOOLS=true
        print_info "IT Tools enabled"
    fi
    
    if prompt_yes_no "Enable Loki (log aggregation)?"; then
        ENABLE_LOKI=true
        print_info "Loki enabled"
    fi
    
    if prompt_yes_no "Enable Borgmatic (backups)?"; then
        ENABLE_BORGMATIC=true
        print_info "Borgmatic enabled"
    fi
    
    if prompt_yes_no "Enable WireGuard (VPN)?"; then
        ENABLE_WIREGUARD=true
        print_info "WireGuard enabled"
    fi
    
    # Prompt for resource limits
    print_header "Resource Limits"
    
    # Initialize resource limits arrays
    declare -A MEMORY_LIMITS
    declare -A CPU_LIMITS
    
    # Prompt for resource limits for each service
    if prompt_yes_no "Do you want to set resource limits for services?"; then
        prompt_resource_limits "caddy"
        prompt_resource_limits "authelia"
        
        if $ENABLE_MARIADB; then
            prompt_resource_limits "mariadb"
        fi
        
        if $ENABLE_POSTGRES; then
            prompt_resource_limits "postgres"
        fi
        
        if $ENABLE_REDIS; then
            prompt_resource_limits "redis"
        fi
        
        if $ENABLE_VAULTWARDEN; then
            prompt_resource_limits "vaultwarden"
        fi
        
        if $ENABLE_GRAFANA; then
            prompt_resource_limits "grafana"
        fi
        
        if $ENABLE_PROMETHEUS; then
            prompt_resource_limits "prometheus"
        fi
        
        if $ENABLE_DOCMOST; then
            prompt_resource_limits "docmost"
        fi
        
        if $ENABLE_CODE_SERVER; then
            prompt_resource_limits "code-server"
        fi
        
        if $ENABLE_HOMEASSISTANT; then
            prompt_resource_limits "homeassistant"
        fi
        
        if $ENABLE_OWNCLOUD; then
            prompt_resource_limits "owncloud"
        fi
        
        if $ENABLE_PORTAINER; then
            prompt_resource_limits "portainer"
        fi
        
        if $ENABLE_ITTOOLS; then
            prompt_resource_limits "ittools"
        fi
        
        if $ENABLE_LOKI; then
            prompt_resource_limits "loki"
        fi
        
        if $ENABLE_BORGMATIC; then
            prompt_resource_limits "borgmatic"
        fi
        
        if $ENABLE_WIREGUARD; then
            prompt_resource_limits "wireguard"
        fi
    fi
    
    # Generate passwords and tokens
    print_header "Generating Passwords and Tokens"
    
    # Generate JWT secret
    JWT_SECRET=$(generate_token)
    print_info "JWT secret generated"
    
    # Generate admin password
    ADMIN_PASSWORD=$(prompt_password "Enter admin password")
    print_info "Admin password set"
    
    # Generate user password
    USER_PASSWORD=$(prompt_password "Enter user password")
    print_info "User password set"
    
    # Generate admin hash
    print_info "Generating admin password hash..."
    ADMIN_HASH=$(generate_argon2_hash "$ADMIN_PASSWORD")
    print_info "Admin password hash generated"
    
    # Generate user hash
    print_info "Generating user password hash..."
    USER_HASH=$(generate_argon2_hash "$USER_PASSWORD")
    print_info "User password hash generated"
    
    # Generate MariaDB passwords if enabled
    if $ENABLE_MARIADB; then
        MARIADB_ROOT_PASSWORD=$(prompt_password "Enter MariaDB root password")
        print_info "MariaDB root password set"
        
        MARIADB_USER="dbuser"
        MARIADB_PASSWORD=$(prompt_password "Enter MariaDB user password")
        print_info "MariaDB user password set"
        
        MARIADB_DATABASE="appdb"
        print_info "MariaDB database: $MARIADB_DATABASE"
    fi
    
    # Generate PostgreSQL passwords if enabled
    if $ENABLE_POSTGRES; then
        POSTGRES_USER="pguser"
        POSTGRES_PASSWORD=$(prompt_password "Enter PostgreSQL password")
        print_info "PostgreSQL password set"
        
        POSTGRES_DB="appdb"
        print_info "PostgreSQL database: $POSTGRES_DB"
    fi
    
    # Generate Vaultwarden token if enabled
    if $ENABLE_VAULTWARDEN; then
        VAULTWARDEN_ADMIN_TOKEN=$(prompt_password "Enter Vaultwarden admin token")
        print_info "Vaultwarden admin token set"
        
        print_info "Generating Vaultwarden hashed admin token..."
        VAULTWARDEN_HASHED_TOKEN=$(generate_argon2_hash "$VAULTWARDEN_ADMIN_TOKEN")
        print_info "Vaultwarden hashed admin token generated"
    fi
    
    # Generate Grafana admin password if enabled
    if $ENABLE_GRAFANA; then
        GF_SECURITY_ADMIN_PASSWORD=$(prompt_password "Enter Grafana admin password")
        print_info "Grafana admin password set"
    fi
    
    # Generate DocMost app secret if enabled
    if $ENABLE_DOCMOST; then
        APP_SECRET=$(generate_token)
        print_info "DocMost app secret generated"
        
        # Set database URLs
        POSTGRES_URL="postgresql://$POSTGRES_USER:$POSTGRES_PASSWORD@postgres:5432/$POSTGRES_DB"
        REDIS_URL="redis://redis:6379"
        print_info "DocMost database URLs set"
    fi
    
    # Generate WireGuard configuration if enabled
    if $ENABLE_WIREGUARD; then
        SERVERURL=$(prompt_with_default "Enter WireGuard server URL (public IP or domain)" "auto")
        print_info "WireGuard server URL: $SERVERURL"
        
        SERVERPORT=$(prompt_with_default "Enter WireGuard server port" "51820")
        print_info "WireGuard server port: $SERVERPORT"
        
        PEERS=$(prompt_with_default "Enter number of WireGuard peers" "3")
        print_info "WireGuard peers: $PEERS"
        
        PEERDNS=$(prompt_with_default "Enter WireGuard peer DNS" "auto")
        print_info "WireGuard peer DNS: $PEERDNS"
        
        INTERNAL_SUBNET=$(prompt_with_default "Enter WireGuard internal subnet" "10.13.13.0")
        print_info "WireGuard internal subnet: $INTERNAL_SUBNET"
    fi
    
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
    
    # Create credentials file
    cat > "$DATA_DIR/credentials.txt" << EOF
# Server Credentials
# Generated on $(date)
# KEEP THIS FILE SECURE!

# Domain
DOMAIN=$DOMAIN
EMAIL=$EMAIL

# Authelia
ADMIN_USER=admin
ADMIN_PASSWORD=$ADMIN_PASSWORD
USER_USER=user
USER_PASSWORD=$USER_PASSWORD
JWT_SECRET=$JWT_SECRET

EOF
    
    # Add service-specific credentials
    if $ENABLE_MARIADB; then
        cat >> "$DATA_DIR/credentials.txt" << EOF
# MariaDB
MARIADB_ROOT_PASSWORD=$MARIADB_ROOT_PASSWORD
MARIADB_USER=$MARIADB_USER
MARIADB_PASSWORD=$MARIADB_PASSWORD
MARIADB_DATABASE=$MARIADB_DATABASE

EOF
    fi
    
    if $ENABLE_POSTGRES; then
        cat >> "$DATA_DIR/credentials.txt" << EOF
# PostgreSQL
POSTGRES_USER=$POSTGRES_USER
POSTGRES_PASSWORD=$POSTGRES_PASSWORD
POSTGRES_DB=$POSTGRES_DB

EOF
    fi
    
    if $ENABLE_VAULTWARDEN; then
        cat >> "$DATA_DIR/credentials.txt" << EOF
# Vaultwarden
VAULTWARDEN_ADMIN_TOKEN=$VAULTWARDEN_ADMIN_TOKEN

EOF
    fi
    
    if $ENABLE_GRAFANA; then
        cat >> "$DATA_DIR/credentials.txt" << EOF
# Grafana
GF_SECURITY_ADMIN_PASSWORD=$GF_SECURITY_ADMIN_PASSWORD

EOF
    fi
    
    if $ENABLE_DOCMOST; then
        cat >> "$DATA_DIR/credentials.txt" << EOF
# DocMost
APP_SECRET=$APP_SECRET
POSTGRES_URL=$POSTGRES_URL
REDIS_URL=$REDIS_URL

EOF
    fi
    
    # Set secure permissions on credentials file
    chmod 600 "$DATA_DIR/credentials.txt"
    chown $SUDO_USER:$SUDO_USER "$DATA_DIR/credentials.txt"
    
    print_success "Credentials saved to $DATA_DIR/credentials.txt"
    print_warning "SECURITY NOTICE: This file contains sensitive information in plaintext."
    print_warning "Consider encrypting or securely deleting this file after setup."
    print_warning "For production use, consider using Docker secrets or a secrets management tool."
    
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
