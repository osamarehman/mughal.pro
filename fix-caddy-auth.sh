#!/bin/bash

# Caddy Authentication Fix Script
# This script removes authentication directives from Caddy configuration

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

# Function to find and fix Caddy configuration
fix_caddy_config() {
    print_header "Finding Caddy Configuration File"
    
    # Common locations for Caddy configuration
    LOCATIONS=(
        "/opt/docker/caddy/Caddyfile"
        "/opt/docker/data/caddy/config/Caddyfile"
        "/opt/docker/compose/caddy/Caddyfile"
        "/opt/docker/compose/data/caddy/config/Caddyfile"
    )
    
    FOUND=false
    
    for LOCATION in "${LOCATIONS[@]}"; do
        if [ -f "$LOCATION" ]; then
            print_success "Found Caddy configuration at: $LOCATION"
            FOUND=true
            
            # Backup the original file
            print_info "Backing up original Caddy configuration file..."
            cp "$LOCATION" "$LOCATION.bak"
            print_success "Backup created at: $LOCATION.bak"
            
            # Check for authentication directives
            if grep -q "forward_auth" "$LOCATION" || grep -q "basicauth" "$LOCATION" || grep -q "authentication" "$LOCATION"; then
                print_info "Found authentication directives in Caddy configuration"
                print_info "Removing authentication directives..."
                
                # Create a temporary file
                local temp_file=$(mktemp)
                
                # Remove authentication directives
                sed '/forward_auth/d; /basicauth/d; /authentication/d' "$LOCATION" > "$temp_file"
                
                # Replace the original file with the fixed one
                mv "$temp_file" "$LOCATION"
                
                print_success "Authentication directives removed from Caddy configuration"
                
                # Restart Caddy container
                print_info "Restarting Caddy container..."
                docker restart caddy
                
                if [ $? -eq 0 ]; then
                    print_success "Caddy container restarted"
                else
                    print_error "Failed to restart Caddy container"
                    print_info "Try restarting it manually: docker restart caddy"
                fi
            else
                print_info "No authentication directives found in Caddy configuration"
                
                # Check for other potential authentication mechanisms
                if grep -q "authelia" "$LOCATION"; then
                    print_warning "Found references to Authelia in Caddy configuration"
                    print_info "Removing Authelia references..."
                    
                    # Create a temporary file
                    local temp_file=$(mktemp)
                    
                    # Remove Authelia references
                    sed '/authelia/d' "$LOCATION" > "$temp_file"
                    
                    # Replace the original file with the fixed one
                    mv "$temp_file" "$LOCATION"
                    
                    print_success "Authelia references removed from Caddy configuration"
                    
                    # Restart Caddy container
                    print_info "Restarting Caddy container..."
                    docker restart caddy
                    
                    if [ $? -eq 0 ]; then
                        print_success "Caddy container restarted"
                    else
                        print_error "Failed to restart Caddy container"
                        print_info "Try restarting it manually: docker restart caddy"
                    fi
                fi
            fi
        fi
    done
    
    if [ "$FOUND" = false ]; then
        print_warning "Caddy configuration file not found in common locations"
        print_info "Checking for Caddy container..."
        
        if docker ps -a | grep -q caddy; then
            print_info "Caddy container found"
            print_info "Checking Caddy container configuration..."
            
            # Get Caddy container ID
            local caddy_id=$(docker ps -a --filter "name=caddy" --format "{{.ID}}")
            
            # Check if Caddy is using a mounted configuration file
            local mount_point=$(docker inspect --format '{{range .Mounts}}{{if eq .Destination "/etc/caddy/Caddyfile"}}{{.Source}}{{end}}{{end}}' "$caddy_id")
            
            if [ -n "$mount_point" ]; then
                print_info "Caddy is using a mounted configuration file at: $mount_point"
                
                # Backup the original file
                print_info "Backing up original Caddy configuration file..."
                cp "$mount_point" "$mount_point.bak"
                print_success "Backup created at: $mount_point.bak"
                
                # Check for authentication directives
                if grep -q "forward_auth" "$mount_point" || grep -q "basicauth" "$mount_point" || grep -q "authentication" "$mount_point"; then
                    print_info "Found authentication directives in Caddy configuration"
                    print_info "Removing authentication directives..."
                    
                    # Create a temporary file
                    local temp_file=$(mktemp)
                    
                    # Remove authentication directives
                    sed '/forward_auth/d; /basicauth/d; /authentication/d' "$mount_point" > "$temp_file"
                    
                    # Replace the original file with the fixed one
                    mv "$temp_file" "$mount_point"
                    
                    print_success "Authentication directives removed from Caddy configuration"
                    
                    # Restart Caddy container
                    print_info "Restarting Caddy container..."
                    docker restart caddy
                    
                    if [ $? -eq 0 ]; then
                        print_success "Caddy container restarted"
                    else
                        print_error "Failed to restart Caddy container"
                        print_info "Try restarting it manually: docker restart caddy"
                    fi
                else
                    print_info "No authentication directives found in Caddy configuration"
                    
                    # Check for other potential authentication mechanisms
                    if grep -q "authelia" "$mount_point"; then
                        print_warning "Found references to Authelia in Caddy configuration"
                        print_info "Removing Authelia references..."
                        
                        # Create a temporary file
                        local temp_file=$(mktemp)
                        
                        # Remove Authelia references
                        sed '/authelia/d' "$mount_point" > "$temp_file"
                        
                        # Replace the original file with the fixed one
                        mv "$temp_file" "$mount_point"
                        
                        print_success "Authelia references removed from Caddy configuration"
                        
                        # Restart Caddy container
                        print_info "Restarting Caddy container..."
                        docker restart caddy
                        
                        if [ $? -eq 0 ]; then
                            print_success "Caddy container restarted"
                        else
                            print_error "Failed to restart Caddy container"
                            print_info "Try restarting it manually: docker restart caddy"
                        fi
                    fi
                fi
            else
                print_warning "Caddy is not using a mounted configuration file"
                print_info "Creating a new Caddy container with default configuration..."
                
                # Stop and remove the Caddy container
                print_info "Stopping and removing Caddy container..."
                docker stop caddy
                docker rm caddy
                
                # Get the current network
                local network=$(docker inspect --format '{{range $key, $value := .NetworkSettings.Networks}}{{$key}}{{end}}' "$caddy_id" 2>/dev/null || echo "compose_proxy")
                print_info "Detected network: $network"
                
                # Create a new Caddy container with default configuration
                print_info "Creating new Caddy container with default configuration..."
                docker run -d \
                    --name caddy \
                    --network $network \
                    --restart unless-stopped \
                    -p 80:80 \
                    -p 443:443 \
                    caddy:2
                
                if [ $? -eq 0 ]; then
                    print_success "Caddy container recreated with default configuration"
                else
                    print_error "Failed to recreate Caddy container"
                    print_info "Try recreating it manually"
                fi
            fi
        else
            print_error "Caddy container not found"
            print_info "Make sure Caddy is installed and running"
        fi
    fi
}

# Function to check if authentication is still required
check_auth_required() {
    print_header "Checking if Authentication is Still Required"
    
    # Get the server's IP address
    local ip_address=$(hostname -I | awk '{print $1}')
    print_info "Server IP address: $ip_address"
    
    # Check if curl is installed
    if ! command -v curl &> /dev/null; then
        print_warning "curl is not installed, skipping authentication check"
        print_info "Install curl to check if authentication is still required: apt-get install -y curl"
        return 0
    fi
    
    # Check if authentication is required
    print_info "Checking if authentication is required..."
    local http_code=$(curl -s -o /dev/null -w "%{http_code}" "http://$ip_address")
    
    if [ "$http_code" = "401" ] || [ "$http_code" = "407" ]; then
        print_error "Authentication is still required (HTTP code: $http_code)"
        print_info "You may need to manually edit the Caddy configuration or check other authentication mechanisms"
    elif [ "$http_code" = "200" ] || [ "$http_code" = "302" ] || [ "$http_code" = "301" ]; then
        print_success "Authentication is not required (HTTP code: $http_code)"
        print_info "You should now be able to access your services without authentication"
    else
        print_warning "Unexpected HTTP code: $http_code"
        print_info "You may need to manually check if authentication is still required"
    fi
}

# Function to fix Docker Compose configuration
fix_docker_compose() {
    print_header "Fixing Docker Compose Configuration"
    
    # Common locations for Docker Compose configuration
    LOCATIONS=(
        "/opt/docker/compose/docker-compose.yml"
        "/opt/docker/docker-compose.yml"
    )
    
    FOUND=false
    
    for LOCATION in "${LOCATIONS[@]}"; do
        if [ -f "$LOCATION" ]; then
            print_success "Found Docker Compose configuration at: $LOCATION"
            FOUND=true
            
            # Backup the original file
            print_info "Backing up original Docker Compose configuration file..."
            cp "$LOCATION" "$LOCATION.bak"
            print_success "Backup created at: $LOCATION.bak"
            
            # Check for Authelia service
            if grep -q "authelia:" "$LOCATION"; then
                print_info "Found Authelia service in Docker Compose configuration"
                print_info "Disabling Authelia service..."
                
                # Create a temporary file
                local temp_file=$(mktemp)
                
                # Comment out Authelia service
                awk '/authelia:/{flag=1} flag && /^  [a-z]/{flag=0} {if(flag) {print "# " $0} else {print}}' "$LOCATION" > "$temp_file"
                
                # Replace the original file with the fixed one
                mv "$temp_file" "$LOCATION"
                
                print_success "Authelia service disabled in Docker Compose configuration"
            else
                print_info "No Authelia service found in Docker Compose configuration"
            fi
            
            # Check for Authelia references in other services
            if grep -q "authelia" "$LOCATION"; then
                print_info "Found Authelia references in Docker Compose configuration"
                print_info "Removing Authelia references..."
                
                # Create a temporary file
                local temp_file=$(mktemp)
                
                # Remove Authelia references
                sed '/authelia/d' "$LOCATION" > "$temp_file"
                
                # Replace the original file with the fixed one
                mv "$temp_file" "$LOCATION"
                
                print_success "Authelia references removed from Docker Compose configuration"
            fi
        fi
    done
    
    if [ "$FOUND" = false ]; then
        print_warning "Docker Compose configuration file not found in common locations"
    fi
}

# Main function
main() {
    print_header "Caddy Authentication Fix Script"
    print_info "This script removes authentication directives from Caddy configuration"
    
    # Check if running as root
    if [ "$(id -u)" -ne 0 ]; then
        print_warning "This script may need root privileges to access some configuration files"
        print_info "Consider running with sudo if you encounter permission errors"
    fi
    
    # Fix Caddy configuration
    fix_caddy_config
    
    # Fix Docker Compose configuration
    fix_docker_compose
    
    # Check if authentication is still required
    check_auth_required
    
    print_header "Next Steps"
    print_info "1. If authentication is still required, try restarting all containers:"
    print_info "   docker restart \$(docker ps -q)"
    print_info "2. If issues persist, consider running the cleanup script:"
    print_info "   sudo ./cleanup-docker.sh"
    print_info "3. Then run the setup script again to recreate all containers:"
    print_info "   sudo ./setup.sh"
    print_info "4. For more troubleshooting options, see troubleshooting_checklist.md"
}

# Run main function
main
