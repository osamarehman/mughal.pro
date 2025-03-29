#!/bin/bash

# Server Setup Credentials Script
# This script contains functions to handle credentials for the setup script

# Function to prompt for basic information
prompt_basic_info() {
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
}

# Function to generate passwords and tokens
generate_credentials() {
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
}
