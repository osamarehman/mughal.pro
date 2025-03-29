#!/bin/bash

# Fix script for container issues
# This script disables Authelia and fixes other restarting containers

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

# Function to disable Authelia in Docker Compose
disable_authelia() {
    print_header "Disabling Authelia"
    
    # Check if Docker Compose file exists
    if [ ! -f "/opt/docker/docker-compose.yml" ]; then
        print_error "Docker Compose file not found at /opt/docker/docker-compose.yml"
        return 1
    fi
    
    # Backup the current Docker Compose file
    cp /opt/docker/docker-compose.yml /opt/docker/docker-compose.yml.bak
    print_info "Backed up docker-compose.yml"
    
    # Comment out the Authelia service in the Docker Compose file
    sed -i '/# Authelia authentication server/,/proxy/s/^/#/' /opt/docker/docker-compose.yml
    print_success "Disabled Authelia service in Docker Compose file"
}

# Function to update Caddy configuration to remove Authelia authentication
update_caddy_config() {
    print_header "Updating Caddy Configuration"
    
    # Check if Caddy config file exists
    if [ ! -f "/opt/docker/data/caddy/config/Caddyfile" ]; then
        print_error "Caddy config file not found at /opt/docker/data/caddy/config/Caddyfile"
        return 1
    fi
    
    # Backup the current Caddyfile
    cp /opt/docker/data/caddy/config/Caddyfile /opt/docker/data/caddy/config/Caddyfile.bak
    print_info "Backed up Caddyfile"
    
    # Remove Authelia-related configuration from Caddyfile
    # 1. Remove the Authelia reverse proxy block
    sed -i '/# Reverse proxy for Authelia/,/}/d' /opt/docker/data/caddy/config/Caddyfile
    
    # 2. Remove all forward_auth blocks
    sed -i '/# Authentication with Authelia/,/}/d' /opt/docker/data/caddy/config/Caddyfile
    
    # 3. Comment out the Authelia subdomain block
    sed -i '/authelia\./,/}/s/^/#/' /opt/docker/data/caddy/config/Caddyfile
    
    print_success "Updated Caddy configuration to remove Authelia authentication"
}

# Function to fix Redis configuration
fix_redis() {
    print_header "Fixing Redis"
    
    # Check if Redis config directory exists
    if [ ! -d "/opt/docker/data/redis" ]; then
        print_error "Redis config directory not found at /opt/docker/data/redis"
        return 1
    fi
    
    # Backup the current redis.conf
    cp /opt/docker/data/redis/redis.conf /opt/docker/data/redis/redis.conf.bak
    print_info "Backed up redis.conf"
    
    # Create a simpler redis.conf that should work reliably
    cat > /opt/docker/data/redis/redis.conf << EOF
# Redis configuration file
bind 0.0.0.0
protected-mode no
port 6379
dir /data
EOF
    
    print_success "Updated Redis configuration with simplified settings"
}

# Function to fix Prometheus configuration
fix_prometheus() {
    print_header "Fixing Prometheus"
    
    # Check if Prometheus config directory exists
    if [ ! -d "/opt/docker/data/prometheus/config" ]; then
        print_error "Prometheus config directory not found at /opt/docker/data/prometheus/config"
        return 1
    fi
    
    # Ensure Prometheus data directory has correct permissions
    mkdir -p /opt/docker/data/prometheus/data
    chmod 777 /opt/docker/data/prometheus/data
    
    print_success "Fixed Prometheus data directory permissions"
}

# Function to fix Grafana configuration
fix_grafana() {
    print_header "Fixing Grafana"
    
    # Check if Grafana data directory exists
    if [ ! -d "/opt/docker/data/grafana/data" ]; then
        print_error "Grafana data directory not found at /opt/docker/data/grafana/data"
        return 1
    fi
    
    # Ensure Grafana data directory has correct permissions
    chmod -R 777 /opt/docker/data/grafana/data
    
    print_success "Fixed Grafana data directory permissions"
}

# Function to fix Loki configuration
fix_loki() {
    print_header "Fixing Loki"
    
    # Check if Loki config directory exists
    if [ ! -d "/opt/docker/data/loki/config" ]; then
        print_error "Loki config directory not found at /opt/docker/data/loki/config"
        return 1
    fi
    
    # Ensure Loki data directory has correct permissions
    mkdir -p /opt/docker/data/loki/data
    chmod -R 777 /opt/docker/data/loki/data
    
    print_success "Fixed Loki data directory permissions"
}

# Function to fix Promtail configuration
fix_promtail() {
    print_header "Fixing Promtail"
    
    # Check if Promtail config directory exists
    if [ ! -d "/opt/docker/data/loki/config" ]; then
        print_error "Promtail config directory not found at /opt/docker/data/loki/config"
        return 1
    fi
    
    # Update Promtail configuration to fix common issues
    cat > /opt/docker/data/loki/config/promtail-config.yaml << EOF
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://loki:3100/loki/api/v1/push

scrape_configs:
  - job_name: system
    static_configs:
      - targets:
          - localhost
        labels:
          job: varlogs
          __path__: /var/log/*log
EOF
    
    print_success "Updated Promtail configuration"
}

# Main function
main() {
    print_header "Container Fix Script"
    print_info "This script will disable Authelia and fix other restarting containers"
    
    # Disable Authelia in Docker Compose
    disable_authelia
    
    # Update Caddy configuration
    update_caddy_config
    
    # Fix Redis
    fix_redis
    
    # Fix Prometheus
    fix_prometheus
    
    # Fix Grafana
    fix_grafana
    
    # Fix Loki
    fix_loki
    
    # Fix Promtail
    fix_promtail
    
    print_header "Restarting Containers"
    
    # Restart containers
    cd /opt/docker
    docker-compose down
    docker-compose up -d
    
    print_success "Containers restarted with Authelia disabled"
    print_info "Check container status with: docker-compose ps"
    print_info "Check container logs with: docker-compose logs [service]"
    print_warning "Note: Authentication is now disabled. Services are accessible without authentication."
}

# Run main function
main
