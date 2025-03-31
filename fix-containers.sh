#!/bin/bash

# Comprehensive Fix Script for Container Issues
# This script fixes configuration issues and restarts problematic containers

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

# Function to check if a script exists and is executable
check_script() {
    local script=$1
    if [ ! -f "$script" ]; then
        print_error "Script not found: $script"
        return 1
    fi
    
    if [ ! -x "$script" ]; then
        print_info "Making script executable: $script"
        chmod +x "$script"
    fi
    
    return 0
}

# Function to fix Redis configuration
fix_redis_configuration() {
    print_header "Fixing Redis Configuration"
    
    # Check for both fix-redis-config.sh and radis-fix.sh (typo in user's script)
    if check_script "./fix-redis-config.sh"; then
        print_info "Running Redis configuration fix script..."
        ./fix-redis-config.sh
        
        if [ $? -eq 0 ]; then
            print_success "Redis configuration fixed"
        else
            print_error "Failed to fix Redis configuration"
            print_info "Continuing with container fixes..."
        fi
    elif check_script "./radis-fix.sh"; then
        print_info "Running Redis configuration fix script (radis-fix.sh)..."
        ./radis-fix.sh
        
        if [ $? -eq 0 ]; then
            print_success "Redis configuration fixed"
        else
            print_error "Failed to fix Redis configuration"
            print_info "Continuing with container fixes..."
        fi
    else
        print_warning "Redis configuration fix script not found"
        print_info "Continuing with container fixes..."
    fi
}

# Function to fix Authelia hash
fix_authelia_hash() {
    print_header "Fixing Authelia Hash"
    
    if check_script "./fix-authelia-hash.sh"; then
        print_info "Running Authelia hash fix script..."
        ./fix-authelia-hash.sh
        
        if [ $? -eq 0 ]; then
            print_success "Authelia hash fixed"
        else
            print_error "Failed to fix Authelia hash"
            print_info "Continuing with container fixes..."
        fi
    else
        print_warning "Authelia hash fix script not found"
        print_info "Continuing with container fixes..."
    fi
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
    print_info "Stopping and removing Authelia container..."
    docker stop authelia
    docker rm authelia
    
    print_success "Authelia container stopped and removed"
    print_warning "Services will now be accessible without authentication"
    print_info "See AUTHELIA_DISABLE_NOTES.md for more information"
    
    # Run the Caddy authentication fix script if it exists
    if check_script "./fix-caddy-auth.sh"; then
        print_info "Running Caddy authentication fix script..."
        ./fix-caddy-auth.sh
        
        if [ $? -eq 0 ]; then
            print_success "Caddy authentication configuration fixed"
        else
            print_error "Failed to fix Caddy authentication configuration"
            print_info "Continuing with container fixes..."
        fi
    else
        print_warning "Caddy authentication fix script not found"
        print_info "You may need to manually edit the Caddy configuration to remove authentication"
        print_info "Consider creating and running fix-caddy-auth.sh to remove authentication directives"
    fi
}

# Function to fix Redis container
fix_redis() {
    print_header "Fixing Redis Container"
    
    # Check if Redis container exists
    if ! docker ps -a | grep -q redis; then
        print_error "Redis container not found"
        return 1
    fi
    
    # Get the current network
    local network=$(docker inspect --format '{{range $key, $value := .NetworkSettings.Networks}}{{$key}}{{end}}' redis 2>/dev/null || echo "compose_backend")
    print_info "Detected network: $network"
    
    # Get the current timezone
    local timezone=$(docker inspect --format '{{range $index, $value := .Config.Env}}{{if eq (index (split $value "=") 0) "TZ"}}{{index (split $value "=") 1}}{{end}}{{end}}' redis 2>/dev/null || echo "Etc/UTC")
    print_info "Detected timezone: $timezone"
    
    # Stop and remove the Redis container
    print_info "Stopping and removing Redis container..."
    docker stop redis
    docker rm redis
    
    # Create a new Redis container with simplified configuration
    print_info "Creating new Redis container with simplified configuration..."
    docker run -d \
        --name redis \
        --network $network \
        --restart unless-stopped \
        -e TZ=$timezone \
        redis:6 redis-server --appendonly yes --protected-mode no
    
    if [ $? -eq 0 ]; then
        print_success "Redis container recreated with simplified configuration"
    else
        print_error "Failed to recreate Redis container"
    fi
}

# Function to fix Prometheus container
fix_prometheus() {
    print_header "Fixing Prometheus Container"
    
    # Check if Prometheus container exists
    if ! docker ps -a | grep -q prometheus; then
        print_error "Prometheus container not found"
        return 1
    fi
    
    # Get the current network - use compose_monitoring instead of compose_monitoringcompose_proxy
    local network=$(docker inspect --format '{{range $key, $value := .NetworkSettings.Networks}}{{$key}}{{end}}' prometheus 2>/dev/null || echo "compose_monitoring")
    print_info "Detected network: $network"
    
    # Get the current timezone
    local timezone=$(docker inspect --format '{{range $index, $value := .Config.Env}}{{if eq (index (split $value "=") 0) "TZ"}}{{index (split $value "=") 1}}{{end}}{{end}}' prometheus 2>/dev/null || echo "Etc/UTC")
    print_info "Detected timezone: $timezone"
    
    # Stop and remove the Prometheus container
    print_info "Stopping and removing Prometheus container..."
    docker stop prometheus
    docker rm prometheus
    
    # Check if the network exists
    if ! docker network ls | grep -q "$network"; then
        print_warning "Network $network does not exist"
        print_info "Creating network $network..."
        docker network create $network
        
        if [ $? -ne 0 ]; then
            print_error "Failed to create network $network"
            print_info "Using default bridge network instead"
            network="bridge"
        else
            print_success "Network $network created"
        fi
    fi
    
    # Create a new Prometheus container with default configuration
    print_info "Creating new Prometheus container with default configuration..."
    docker run -d \
        --name prometheus \
        --network $network \
        --restart unless-stopped \
        -e TZ=$timezone \
        prom/prometheus:latest
    
    if [ $? -eq 0 ]; then
        print_success "Prometheus container recreated with default configuration"
    else
        print_error "Failed to recreate Prometheus container"
    fi
}

# Function to fix Grafana container
fix_grafana() {
    print_header "Fixing Grafana Container"
    
    # Check if Grafana container exists
    if ! docker ps -a | grep -q grafana; then
        print_error "Grafana container not found"
        return 1
    fi
    
    # Get the current network - use compose_monitoring instead of compose_monitoringcompose_proxy
    local network=$(docker inspect --format '{{range $key, $value := .NetworkSettings.Networks}}{{$key}}{{end}}' grafana 2>/dev/null || echo "compose_monitoring")
    print_info "Detected network: $network"
    
    # Get the current timezone
    local timezone=$(docker inspect --format '{{range $index, $value := .Config.Env}}{{if eq (index (split $value "=") 0) "TZ"}}{{index (split $value "=") 1}}{{end}}{{end}}' grafana 2>/dev/null || echo "Etc/UTC")
    print_info "Detected timezone: $timezone"
    
    # Stop and remove the Grafana container
    print_info "Stopping and removing Grafana container..."
    docker stop grafana
    docker rm grafana
    
    # Check if the network exists
    if ! docker network ls | grep -q "$network"; then
        print_warning "Network $network does not exist"
        print_info "Creating network $network..."
        docker network create $network
        
        if [ $? -ne 0 ]; then
            print_error "Failed to create network $network"
            print_info "Using default bridge network instead"
            network="bridge"
        else
            print_success "Network $network created"
        fi
    fi
    
    # Create a new Grafana container with default configuration
    print_info "Creating new Grafana container with default configuration..."
    docker run -d \
        --name grafana \
        --network $network \
        --restart unless-stopped \
        -e "GF_SECURITY_ADMIN_PASSWORD=admin" \
        -e "GF_USERS_ALLOW_SIGN_UP=false" \
        -e TZ=$timezone \
        grafana/grafana:latest
    
    if [ $? -eq 0 ]; then
        print_success "Grafana container recreated with default configuration"
        print_info "Default admin credentials: admin/admin"
        print_warning "Please change the default password after logging in"
    else
        print_error "Failed to recreate Grafana container"
    fi
}

# Function to fix Loki container
fix_loki() {
    print_header "Fixing Loki Container"
    
    # Check if Loki container exists
    if ! docker ps -a | grep -q loki; then
        print_error "Loki container not found"
        return 1
    fi
    
    # Get the current network
    local network=$(docker inspect --format '{{range $key, $value := .NetworkSettings.Networks}}{{$key}}{{end}}' loki 2>/dev/null || echo "compose_monitoring")
    print_info "Detected network: $network"
    
    # Get the current timezone
    local timezone=$(docker inspect --format '{{range $index, $value := .Config.Env}}{{if eq (index (split $value "=") 0) "TZ"}}{{index (split $value "=") 1}}{{end}}{{end}}' loki 2>/dev/null || echo "Etc/UTC")
    print_info "Detected timezone: $timezone"
    
    # Stop and remove the Loki container
    print_info "Stopping and removing Loki container..."
    docker stop loki
    docker rm loki
    
    # Check if the network exists
    if ! docker network ls | grep -q "$network"; then
        print_warning "Network $network does not exist"
        print_info "Creating network $network..."
        docker network create $network
        
        if [ $? -ne 0 ]; then
            print_error "Failed to create network $network"
            print_info "Using default bridge network instead"
            network="bridge"
        else
            print_success "Network $network created"
        fi
    fi
    
    # Create a new Loki container with default configuration
    print_info "Creating new Loki container with default configuration..."
    docker run -d \
        --name loki \
        --network $network \
        --restart unless-stopped \
        -e TZ=$timezone \
        grafana/loki:latest
    
    if [ $? -eq 0 ]; then
        print_success "Loki container recreated with default configuration"
    else
        print_error "Failed to recreate Loki container"
    fi
}

# Function to fix Promtail container
fix_promtail() {
    print_header "Fixing Promtail Container"
    
    # Check if Promtail container exists
    if ! docker ps -a | grep -q promtail; then
        print_error "Promtail container not found"
        return 1
    fi
    
    # Get the current network
    local network=$(docker inspect --format '{{range $key, $value := .NetworkSettings.Networks}}{{$key}}{{end}}' promtail 2>/dev/null || echo "compose_monitoring")
    print_info "Detected network: $network"
    
    # Get the current timezone
    local timezone=$(docker inspect --format '{{range $index, $value := .Config.Env}}{{if eq (index (split $value "=") 0) "TZ"}}{{index (split $value "=") 1}}{{end}}{{end}}' promtail 2>/dev/null || echo "Etc/UTC")
    print_info "Detected timezone: $timezone"
    
    # Stop and remove the Promtail container
    print_info "Stopping and removing Promtail container..."
    docker stop promtail
    docker rm promtail
    
    # Check if the network exists
    if ! docker network ls | grep -q "$network"; then
        print_warning "Network $network does not exist"
        print_info "Creating network $network..."
        docker network create $network
        
        if [ $? -ne 0 ]; then
            print_error "Failed to create network $network"
            print_info "Using default bridge network instead"
            network="bridge"
        else
            print_success "Network $network created"
        fi
    fi
    
    # Create a new Promtail container with default configuration
    print_info "Creating new Promtail container with default configuration..."
    docker run -d \
        --name promtail \
        --network $network \
        --restart unless-stopped \
        -e TZ=$timezone \
        grafana/promtail:latest
    
    if [ $? -eq 0 ]; then
        print_success "Promtail container recreated with default configuration"
    else
        print_error "Failed to recreate Promtail container"
    fi
}

# Function to check container status
check_container_status() {
    print_header "Checking Container Status"
    
    # Get list of containers
    local containers=$(docker ps -a --format "{{.Names}}")
    
    if [ -z "$containers" ]; then
        print_warning "No containers found"
        return 0
    fi
    
    # Check each container
    for container in $containers; do
        local status=$(docker inspect --format "{{.State.Status}}" "$container")
        local restarts=$(docker inspect --format "{{.RestartCount}}" "$container" 2>/dev/null || echo "N/A")
        
        if [ "$status" = "running" ]; then
            if [ "$restarts" -gt 5 ] 2>/dev/null; then
                print_warning "Container $container is running but has restarted $restarts times"
                print_info "Check logs for errors: docker logs $container"
            else
                print_success "Container $container is running (Restarts: $restarts)"
            fi
        else
            print_error "Container $container is not running (Status: $status)"
            print_info "Check logs for errors: docker logs $container"
        fi
    done
}

# Main function
main() {
    print_header "Comprehensive Container Fix Script"
    print_info "This script will fix configuration issues and restart problematic containers"
    
    # Check if running as root
    if [ "$(id -u)" -ne 0 ]; then
        print_warning "This script may need root privileges to access some configuration files"
        print_info "Consider running with sudo if you encounter permission errors"
    fi
    
    # Fix configuration files first
    fix_redis_configuration
    fix_authelia_hash
    
    # Ask user if they want to disable Authelia
    read -p "Do you want to disable Authelia authentication? (y/n): " disable_auth
    if [[ "$disable_auth" =~ ^[Yy]$ ]]; then
        disable_authelia
    else
        print_info "Keeping Authelia enabled"
    fi
    
    # Fix containers
    fix_redis
    fix_prometheus
    fix_grafana
    fix_loki
    fix_promtail
    
    # Check container status
    check_container_status
    
    print_header "Next Steps"
    print_info "1. Check container logs for any remaining issues:"
    print_info "   docker logs [container_name]"
    print_info "2. If issues persist, consider running the cleanup script:"
    print_info "   sudo ./cleanup-docker.sh"
    print_info "3. Then run the setup script again to recreate all containers:"
    print_info "   sudo ./setup.sh"
    print_info "4. For more troubleshooting options, see troubleshooting_checklist.md"
}

# Run main function
main
