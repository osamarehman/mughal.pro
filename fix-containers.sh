#!/bin/bash

# Fix script for container issues
# This script directly modifies Docker containers to fix restarting issues

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

# Function to directly stop Authelia container
disable_authelia() {
    print_header "Disabling Authelia"
    
    # Check if Authelia container exists
    if ! docker ps -a | grep -q authelia; then
        print_error "Authelia container not found"
        return 1
    fi
    
    # Stop and remove the Authelia container
    docker stop authelia
    docker rm authelia
    
    print_success "Authelia container stopped and removed"
}

# Function to fix Redis container
fix_redis() {
    print_header "Fixing Redis"
    
    # Check if Redis container exists
    if ! docker ps -a | grep -q redis; then
        print_error "Redis container not found"
        return 1
    fi
    
    # Stop and remove the Redis container
    docker stop redis
    docker rm redis
    
    # Create a new Redis container with simplified configuration
    docker run -d \
        --name redis \
        --network mughal_proxy \
        --restart unless-stopped \
        -e TZ=Asia/Karachi \
        redis:6 redis-server --appendonly yes --protected-mode no
    
    print_success "Redis container recreated with simplified configuration"
}

# Function to fix Prometheus container
fix_prometheus() {
    print_header "Fixing Prometheus"
    
    # Check if Prometheus container exists
    if ! docker ps -a | grep -q prometheus; then
        print_error "Prometheus container not found"
        return 1
    fi
    
    # Stop and remove the Prometheus container
    docker stop prometheus
    docker rm prometheus
    
    # Create a new Prometheus container with default configuration
    docker run -d \
        --name prometheus \
        --network mughal_proxy \
        --restart unless-stopped \
        -e TZ=Asia/Karachi \
        prom/prometheus:latest
    
    print_success "Prometheus container recreated with default configuration"
}

# Function to fix Grafana container
fix_grafana() {
    print_header "Fixing Grafana"
    
    # Check if Grafana container exists
    if ! docker ps -a | grep -q grafana; then
        print_error "Grafana container not found"
        return 1
    fi
    
    # Stop and remove the Grafana container
    docker stop grafana
    docker rm grafana
    
    # Create a new Grafana container with default configuration
    docker run -d \
        --name grafana \
        --network mughal_proxy \
        --restart unless-stopped \
        -e "GF_SECURITY_ADMIN_PASSWORD=7oUP8mSKBiqYU1CgiafX5spsRlORb13LJFUXFkKpSw" \
        -e "GF_USERS_ALLOW_SIGN_UP=false" \
        -e TZ=Asia/Karachi \
        grafana/grafana:latest
    
    print_success "Grafana container recreated with default configuration"
}

# Function to fix Loki container
fix_loki() {
    print_header "Fixing Loki"
    
    # Check if Loki container exists
    if ! docker ps -a | grep -q loki; then
        print_error "Loki container not found"
        return 1
    fi
    
    # Stop and remove the Loki container
    docker stop loki
    docker rm loki
    
    # Create a new Loki container with default configuration
    docker run -d \
        --name loki \
        --network mughal_proxy \
        --restart unless-stopped \
        -e TZ=Asia/Karachi \
        grafana/loki:latest
    
    print_success "Loki container recreated with default configuration"
}

# Function to fix Promtail container
fix_promtail() {
    print_header "Fixing Promtail"
    
    # Check if Promtail container exists
    if ! docker ps -a | grep -q promtail; then
        print_error "Promtail container not found"
        return 1
    fi
    
    # Stop and remove the Promtail container
    docker stop promtail
    docker rm promtail
    
    # Create a new Promtail container with default configuration
    docker run -d \
        --name promtail \
        --network mughal_proxy \
        --restart unless-stopped \
        -e TZ=Asia/Karachi \
        grafana/promtail:latest
    
    print_success "Promtail container recreated with default configuration"
}

# Main function
main() {
    print_header "Container Fix Script"
    print_info "This script will directly fix restarting containers"
    
    # Disable Authelia
    disable_authelia
    
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
    
    print_header "Container Status"
    
    # Show container status
    docker ps -a
    
    print_success "Containers fixed"
    print_info "Check container logs with: docker logs [container_name]"
    print_warning "Note: Authelia has been disabled. Services are accessible without authentication."
}

# Run main function
main
