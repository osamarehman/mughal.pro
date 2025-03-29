#!/bin/bash

# Server Setup Utilities Script
# This script contains utility functions for the setup script

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

# Function to validate password for script safety
validate_password() {
    local password=$1
    
    # Check for characters that might break shell scripts
    if [[ "$password" == *"'"* || "$password" == *"\""* || "$password" == *"\\"* || 
          "$password" == *";"* || "$password" == *"&"* || "$password" == *"|"* || 
          "$password" == *">"* || "$password" == *"<"* || "$password" == *"("* || 
          "$password" == *")"* || "$password" == *"{"* || "$password" == *"}"* || 
          "$password" == *"["* || "$password" == *"]"* || "$password" == *"$"* || 
          "$password" == *"#"* || "$password" == *"!"* || "$password" == *"~"* || 
          "$password" == *"`"* ]]; then
        return 1
    fi
    
    return 0
}

# Function to prompt for a password with confirmation
prompt_password() {
    local prompt=$1
    local generate=${2:-true}
    local password
    
    if $generate && prompt_yes_no "Generate a secure password automatically?"; then
        password=$(generate_password)
        # Ensure generated password is safe for shell scripts
        # Base64 encoding should be safe, but let's make sure
        password=$(echo "$password" | tr -dc 'a-zA-Z0-9_-')
        echo "Generated password: $password"
        echo "$password"
        return
    fi
    
    while true; do
        read -s -p "$prompt: " password
        echo
        
        # Validate password
        if ! validate_password "$password"; then
            echo "Password contains special characters that may break the script."
            echo "Please avoid using: ' \" \\ ; & | > < ( ) { } [ ] $ # ! ~ \`"
            continue
        fi
        
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

# Function to generate a secure password
generate_password() {
    # Generate a secure password and filter out potentially problematic characters
    openssl rand -base64 32 | tr -dc 'a-zA-Z0-9_-'  # Filter to only include safe characters
}

# Function to generate a secure token
generate_token() {
    # Hex output is already safe (only contains 0-9 and a-f)
    openssl rand -hex 32
}

# Function to generate an Argon2 hash
generate_argon2_hash() {
    local password=$1
    local hash=""
    
    # Try using native argon2 if available
    if command -v argon2 &> /dev/null; then
        hash=$(echo -n "$password" | argon2 "$(openssl rand -hex 8)" -id -t 3 -m 16 -p 4 -l 32 -e 2>/dev/null)
        if [ $? -eq 0 ] && [ -n "$hash" ]; then
            echo "$hash"
            return 0
        fi
        print_warning "Native argon2 failed, falling back to Docker method"
    fi
    
    # Fall back to Docker
    if command -v docker &> /dev/null; then
        # Check if Docker is running
        if docker info &>/dev/null; then
            hash=$(docker run --rm authelia/authelia:latest authelia crypto hash generate argon2 --password "$password" 2>/dev/null)
            if [ $? -eq 0 ] && [ -n "$hash" ]; then
                echo "$hash"
                return 0
            fi
            print_warning "Docker method failed for Argon2 hash generation"
        else
            print_warning "Docker is not running, cannot generate Argon2 hash"
        fi
    else
        print_warning "Docker is not available, cannot generate Argon2 hash"
    fi
    
    # Final fallback - use a simple hash if everything else fails
    # This is not as secure but prevents the script from failing
    print_warning "Falling back to simple hash method (less secure)"
    echo "$(echo -n "${password}$(openssl rand -hex 8)" | sha256sum | awk '{print $1}')"
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

# Function to save credentials
save_credentials() {
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
}
