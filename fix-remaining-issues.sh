#!/bin/bash

# Script to fix remaining issues with Caddy and ownCloud containers

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

# Function to fix Caddy container
fix_caddy() {
    print_header "Fixing Caddy Container"
    
    # Check if Caddy container exists
    if ! docker ps -a | grep -q caddy; then
        print_error "Caddy container not found"
        return 1
    fi
    
    # Get Caddy logs to identify the issue
    print_info "Checking Caddy logs for errors..."
    docker logs caddy 2>&1 | tail -n 50 > caddy_logs.txt
    
    # Check for common errors in Caddy logs
    if grep -q "permission denied" caddy_logs.txt; then
        print_warning "Caddy has permission issues"
        print_info "Fixing Caddy permissions..."
        
        # Get the Caddy container ID
        local caddy_id=$(docker ps -a --filter "name=caddy" --format "{{.ID}}")
        
        # Check if Caddy is using mounted volumes
        local mount_points=$(docker inspect --format '{{range .Mounts}}{{.Source}}:{{.Destination}} {{end}}' "$caddy_id")
        
        print_info "Caddy mount points: $mount_points"
        
        # Fix permissions for Caddy data directory
        if [[ $mount_points == *"/opt/docker/data/caddy"* ]]; then
            print_info "Fixing permissions for Caddy data directory..."
            sudo chown -R 1000:1000 /opt/docker/data/caddy
            print_success "Caddy data directory permissions fixed"
        fi
        
        # Fix permissions for Caddy config directory
        if [[ $mount_points == *"/opt/docker/caddy/config"* ]]; then
            print_info "Fixing permissions for Caddy config directory..."
            sudo chown -R 1000:1000 /opt/docker/caddy/config
            print_success "Caddy config directory permissions fixed"
        fi
    fi
    
    # Check for network issues
    if grep -q "dial tcp: lookup" caddy_logs.txt; then
        print_warning "Caddy has network resolution issues"
        print_info "Fixing Caddy network configuration..."
        
        # Get the current network
        local network=$(docker inspect --format '{{range $key, $value := .NetworkSettings.Networks}}{{$key}}{{end}}' caddy 2>/dev/null || echo "compose_proxy")
        print_info "Detected network: $network"
        
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
    fi
    
    # Create a simplified Caddyfile
    print_info "Creating a simplified Caddyfile..."
    
    # Determine the Caddyfile location
    local caddyfile_location="/opt/docker/caddy/config/Caddyfile"
    if [ ! -d "/opt/docker/caddy/config" ]; then
        if [ -d "/opt/docker/caddy" ]; then
            caddyfile_location="/opt/docker/caddy/Caddyfile"
        else
            print_warning "Caddy config directory not found at common locations"
            print_info "Creating Caddy config directory..."
            sudo mkdir -p /opt/docker/caddy/config
            caddyfile_location="/opt/docker/caddy/config/Caddyfile"
        fi
    fi
    
    # Backup the original Caddyfile if it exists
    if [ -f "$caddyfile_location" ]; then
        print_info "Backing up original Caddyfile..."
        sudo cp "$caddyfile_location" "${caddyfile_location}.bak.$(date +%Y%m%d%H%M%S)"
        print_success "Backup created"
    fi
    
    # Create a simplified Caddyfile
    print_info "Writing simplified Caddyfile to $caddyfile_location..."
    cat << EOF | sudo tee "$caddyfile_location" > /dev/null
{
    # Global options
    admin off
    persist_config off
    auto_https off
}

:80 {
    # Respond with a simple welcome page
    respond "Welcome to your server! Your services are running."
}

# Add your service-specific configurations below
# Example:
# service.example.com {
#     reverse_proxy service:port
# }
EOF
    
    print_success "Simplified Caddyfile created"
    
    # Recreate the Caddy container
    print_info "Recreating Caddy container..."
    
    # Stop and remove the Caddy container
    docker stop caddy
    docker rm caddy
    
    # Create a new Caddy container with simplified configuration
    docker run -d \
        --name caddy \
        --network $network \
        --restart unless-stopped \
        -p 80:80 \
        -p 443:443 \
        -v "$caddyfile_location:/etc/caddy/Caddyfile" \
        -v "/opt/docker/data/caddy:/data" \
        caddy:2
    
    if [ $? -eq 0 ]; then
        print_success "Caddy container recreated with simplified configuration"
    else
        print_error "Failed to recreate Caddy container"
    fi
}

# Function to fix ownCloud container
fix_owncloud() {
    print_header "Fixing ownCloud Container"
    
    # Check if ownCloud container exists
    if ! docker ps -a | grep -q owncloud; then
        print_error "ownCloud container not found"
        return 1
    fi
    
    # Get ownCloud logs to identify the issue
    print_info "Checking ownCloud logs for errors..."
    docker logs owncloud 2>&1 | tail -n 50 > owncloud_logs.txt
    
    # Check for common errors in ownCloud logs
    if grep -q "permission denied" owncloud_logs.txt; then
        print_warning "ownCloud has permission issues"
        print_info "Fixing ownCloud permissions..."
        
        # Get the ownCloud container ID
        local owncloud_id=$(docker ps -a --filter "name=owncloud" --format "{{.ID}}")
        
        # Check if ownCloud is using mounted volumes
        local mount_points=$(docker inspect --format '{{range .Mounts}}{{.Source}}:{{.Destination}} {{end}}' "$owncloud_id")
        
        print_info "ownCloud mount points: $mount_points"
        
        # Fix permissions for ownCloud data directory
        if [[ $mount_points == *"/opt/docker/data/owncloud"* ]]; then
            print_info "Fixing permissions for ownCloud data directory..."
            sudo chown -R 1000:1000 /opt/docker/data/owncloud
            print_success "ownCloud data directory permissions fixed"
        fi
    fi
    
    # Check for database connection issues
    if grep -q "could not connect to server: Connection refused" owncloud_logs.txt; then
        print_warning "ownCloud has database connection issues"
        print_info "Checking if MariaDB/MySQL container is running..."
        
        if docker ps | grep -q mariadb; then
            print_info "MariaDB container is running"
            print_info "Checking if ownCloud is on the same network as MariaDB..."
            
            # Get the networks for ownCloud and MariaDB
            local owncloud_networks=$(docker inspect --format '{{range $key, $value := .NetworkSettings.Networks}}{{$key}} {{end}}' owncloud)
            local mariadb_networks=$(docker inspect --format '{{range $key, $value := .NetworkSettings.Networks}}{{$key}} {{end}}' mariadb)
            
            print_info "ownCloud networks: $owncloud_networks"
            print_info "MariaDB networks: $mariadb_networks"
            
            # Check if they share a network
            local shared_network=false
            for network in $owncloud_networks; do
                if [[ $mariadb_networks == *"$network"* ]]; then
                    shared_network=true
                    print_info "ownCloud and MariaDB share network: $network"
                    break
                fi
            done
            
            if [ "$shared_network" = false ]; then
                print_warning "ownCloud and MariaDB do not share a network"
                print_info "Connecting ownCloud to MariaDB's network..."
                
                # Get the first network of MariaDB
                local mariadb_network=$(echo $mariadb_networks | awk '{print $1}')
                
                # Connect ownCloud to MariaDB's network
                docker network connect $mariadb_network owncloud
                
                if [ $? -eq 0 ]; then
                    print_success "ownCloud connected to MariaDB's network: $mariadb_network"
                else
                    print_error "Failed to connect ownCloud to MariaDB's network"
                fi
            fi
        else
            print_error "MariaDB container is not running"
            print_info "Please make sure MariaDB is running before starting ownCloud"
        fi
    fi
    
    # Restart the ownCloud container
    print_info "Restarting ownCloud container..."
    docker restart owncloud
    
    if [ $? -eq 0 ]; then
        print_success "ownCloud container restarted"
    else
        print_error "Failed to restart ownCloud container"
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
    print_header "Fixing Remaining Container Issues"
    print_info "This script will fix issues with Caddy and ownCloud containers"
    
    # Check if running as root
    if [ "$(id -u)" -ne 0 ]; then
        print_warning "This script may need root privileges to access some configuration files"
        print_info "Consider running with sudo if you encounter permission errors"
    fi
    
    # Fix Caddy container
    fix_caddy
    
    # Fix ownCloud container
    fix_owncloud
    
    # Check container status
    check_container_status
    
    print_header "Next Steps"
    print_info "1. Check container logs for any remaining issues:"
    print_info "   docker logs <container_name>"
    print_info "2. If issues persist, consider running the cleanup script:"
    print_info "   sudo ./cleanup-docker.sh"
    print_info "3. Then run the setup script again to recreate all containers:"
    print_info "   sudo ./setup.sh"
    print_info "4. For more troubleshooting options, see troubleshooting_checklist.md"
}

# Run main function
main
