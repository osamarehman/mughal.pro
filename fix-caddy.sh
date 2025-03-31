#!/bin/bash

# Script to fix Caddy container issues

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

# Main function
main() {
    print_header "Caddy Container Fix Script"
    print_info "This script will fix issues with the Caddy container"
    
    # Check if Caddy container exists
    if ! docker ps -a | grep -q caddy; then
        print_error "Caddy container not found"
        exit 1
    fi
    
    # Get Caddy logs to identify the issue
    print_info "Checking Caddy logs for errors..."
    docker logs caddy 2>&1 | tail -n 50 > caddy_logs.txt
    
    # Check for common errors in Caddy logs
    if grep -q "permission denied" caddy_logs.txt; then
        print_warning "Caddy has permission issues"
        print_info "Fixing Caddy permissions..."
        
        # Fix permissions for Caddy data directory
        if [ -d "/opt/docker/data/caddy" ]; then
            print_info "Fixing permissions for Caddy data directory..."
            sudo chown -R 1000:1000 /opt/docker/data/caddy
            print_success "Caddy data directory permissions fixed"
        fi
        
        # Fix permissions for Caddy config directory
        if [ -d "/opt/docker/caddy/config" ]; then
            print_info "Fixing permissions for Caddy config directory..."
            sudo chown -R 1000:1000 /opt/docker/caddy/config
            print_success "Caddy config directory permissions fixed"
        elif [ -d "/opt/docker/caddy" ]; then
            print_info "Fixing permissions for Caddy directory..."
            sudo chown -R 1000:1000 /opt/docker/caddy
            print_success "Caddy directory permissions fixed"
        fi
    fi
    
    # Determine the Caddyfile location
    print_header "Finding Caddy Configuration File"
    
    caddyfile_location=""
    
    # Check common locations for Caddyfile
    if [ -f "/opt/docker/caddy/config/Caddyfile" ]; then
        caddyfile_location="/opt/docker/caddy/config/Caddyfile"
        print_info "Found Caddyfile at: $caddyfile_location"
    elif [ -f "/opt/docker/caddy/Caddyfile" ]; then
        caddyfile_location="/opt/docker/caddy/Caddyfile"
        print_info "Found Caddyfile at: $caddyfile_location"
    elif [ -f "/opt/docker/data/caddy/Caddyfile" ]; then
        caddyfile_location="/opt/docker/data/caddy/Caddyfile"
        print_info "Found Caddyfile at: $caddyfile_location"
    else
        print_warning "Caddyfile not found in common locations"
        
        # Check if Caddy container exists
        print_info "Checking for Caddy container..."
        if docker ps -a | grep -q caddy; then
            print_info "Caddy container found"
            print_info "Checking Caddy container configuration..."
            
            # Get the Caddy container ID
            caddy_id=$(docker ps -a --filter "name=caddy" --format "{{.ID}}")
            
            # Check if Caddy is using mounted volumes
            mount_points=$(docker inspect --format '{{range .Mounts}}{{.Source}}:{{.Destination}} {{end}}' "$caddy_id")
            
            # Look for Caddyfile mount
            if [[ $mount_points == *"/etc/caddy/Caddyfile"* ]]; then
                # Extract the source path for the Caddyfile
                caddyfile_location=$(echo "$mount_points" | grep -o "[^:]*:/etc/caddy/Caddyfile" | cut -d':' -f1)
                print_info "Caddy is using a mounted configuration file at: $caddyfile_location"
            else
                print_warning "Caddy container does not have a mounted Caddyfile"
                print_info "Creating a new Caddyfile..."
                
                # Create a directory for Caddy configuration
                sudo mkdir -p /opt/docker/caddy/config
                caddyfile_location="/opt/docker/caddy/config/Caddyfile"
            fi
        else
            print_error "Caddy container not found"
            exit 1
        fi
    fi
    
    # Backup the original Caddyfile if it exists
    if [ -f "$caddyfile_location" ]; then
        print_info "Backing up original Caddy configuration file..."
        sudo cp "$caddyfile_location" "${caddyfile_location}.bak"
        print_success "Backup created at: ${caddyfile_location}.bak"
    fi
    
    # Check for authentication directives in Caddyfile
    if [ -f "$caddyfile_location" ] && grep -q "forward_auth" "$caddyfile_location"; then
        print_info "Found authentication directives in Caddy configuration"
        print_info "Removing authentication directives..."
        
        # Create a temporary file
        temp_file=$(mktemp)
        
        # Remove forward_auth directives
        sudo grep -v "forward_auth" "$caddyfile_location" > "$temp_file"
        sudo cp "$temp_file" "$caddyfile_location"
        
        # Remove the temporary file
        rm "$temp_file"
        
        print_success "Authentication directives removed from Caddy configuration"
    elif [ -f "$caddyfile_location" ] && grep -q "basicauth" "$caddyfile_location"; then
        print_info "Found basic authentication directives in Caddy configuration"
        print_info "Removing basic authentication directives..."
        
        # Create a temporary file
        temp_file=$(mktemp)
        
        # Remove basicauth directives
        sudo grep -v "basicauth" "$caddyfile_location" > "$temp_file"
        sudo cp "$temp_file" "$caddyfile_location"
        
        # Remove the temporary file
        rm "$temp_file"
        
        print_success "Basic authentication directives removed from Caddy configuration"
    elif [ -f "$caddyfile_location" ]; then
        print_info "No authentication directives found in Caddy configuration"
    fi
    
    # Check for Authelia references in Caddyfile
    if [ -f "$caddyfile_location" ] && grep -q "authelia" "$caddyfile_location"; then
        print_warning "Found references to Authelia in Caddy configuration"
        print_info "Removing Authelia references..."
        
        # Create a temporary file
        temp_file=$(mktemp)
        
        # Remove lines containing "authelia"
        sudo grep -v "authelia" "$caddyfile_location" > "$temp_file"
        sudo cp "$temp_file" "$caddyfile_location"
        
        # Remove the temporary file
        rm "$temp_file"
        
        print_success "Authelia references removed from Caddy configuration"
    fi
    
    # Create a simplified Caddyfile
    print_header "Creating Simplified Caddyfile"
    
    # Backup the original Caddyfile again with timestamp
    if [ -f "$caddyfile_location" ]; then
        timestamp=$(date +%Y%m%d%H%M%S)
        sudo cp "$caddyfile_location" "${caddyfile_location}.bak.$timestamp"
        print_info "Additional backup created at: ${caddyfile_location}.bak.$timestamp"
    fi
    
    # Create a simplified Caddyfile
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
    
    print_success "Simplified Caddyfile created at: $caddyfile_location"
    
    # Restart Caddy container
    print_info "Restarting Caddy container..."
    docker restart caddy
    
    if [ $? -eq 0 ]; then
        print_success "Caddy container restarted"
    else
        print_error "Failed to restart Caddy container"
        
        # Try to recreate the Caddy container
        print_info "Trying to recreate Caddy container..."
        
        # Get the current network
        network=$(docker inspect --format '{{range $key, $value := .NetworkSettings.Networks}}{{$key}}{{end}}' caddy 2>/dev/null || echo "compose_proxy")
        
        # Stop and remove the Caddy container
        docker stop caddy
        docker rm caddy
        
        # Create a new Caddy container
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
            print_success "Caddy container recreated"
        else
            print_error "Failed to recreate Caddy container"
            print_info "Please check Docker logs for more information"
        fi
    fi
    
    # Check Docker Compose configuration for Authelia references
    print_header "Fixing Docker Compose Configuration"
    
    # Find Docker Compose file
    compose_file=""
    if [ -f "/opt/docker/compose/docker-compose.yml" ]; then
        compose_file="/opt/docker/compose/docker-compose.yml"
        print_success "Found Docker Compose configuration at: $compose_file"
    elif [ -f "/opt/docker/docker-compose.yml" ]; then
        compose_file="/opt/docker/docker-compose.yml"
        print_success "Found Docker Compose configuration at: $compose_file"
    else
        print_warning "Docker Compose configuration not found"
    fi
    
    # Check for Authelia service in Docker Compose file
    if [ -n "$compose_file" ]; then
        # Backup the original Docker Compose file
        print_info "Backing up original Docker Compose configuration file..."
        sudo cp "$compose_file" "${compose_file}.bak"
        print_success "Backup created at: ${compose_file}.bak"
        
        # Check if Authelia service is defined
        if grep -q "authelia:" "$compose_file"; then
            print_info "Found Authelia service in Docker Compose configuration"
            print_info "Commenting out Authelia service..."
            
            # Create a temporary file
            temp_file=$(mktemp)
            
            # Comment out Authelia service
            awk '/authelia:/{flag=1} flag && /^[a-z]/{flag=0} {if(flag) print "# " $0; else print}' "$compose_file" > "$temp_file"
            sudo cp "$temp_file" "$compose_file"
            
            # Remove the temporary file
            rm "$temp_file"
            
            print_success "Authelia service commented out in Docker Compose configuration"
        else
            print_info "No Authelia service found in Docker Compose configuration"
        fi
    fi
    
    # Check if authentication is still required
    print_header "Checking if Authentication is Still Required"
    
    # Get the server IP address
    server_ip=$(hostname -I | awk '{print $1}')
    print_info "Server IP address: $server_ip"
    
    # Check if authentication is required
    print_info "Checking if authentication is required..."
    http_code=$(curl -s -o /dev/null -w "%{http_code}" "http://$server_ip" 2>/dev/null)
    
    if [ "$http_code" = "401" ]; then
        print_warning "Authentication is still required (HTTP code: $http_code)"
        print_info "You may need to restart all containers or check other configuration files"
    elif [ "$http_code" = "200" ]; then
        print_success "Authentication is no longer required (HTTP code: $http_code)"
    else
        print_warning "Unexpected HTTP code: $http_code"
        print_info "You may need to manually check if authentication is still required"
    fi
    
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
