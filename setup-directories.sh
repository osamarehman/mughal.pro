#!/bin/bash

# Server Setup Directories Script
# This script contains functions for creating the directory structure

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
    if [ -n "$SUDO_USER" ]; then
        chown -R $SUDO_USER:$SUDO_USER "$DATA_DIR"
        chown -R $SUDO_USER:$SUDO_USER "$BACKUP_DIR"
    else
        # If not run with sudo, set permissions to current user
        chown -R $(whoami):$(whoami) "$DATA_DIR"
        chown -R $(whoami):$(whoami) "$BACKUP_DIR"
    fi
    
    print_success "Directory structure created"
}
