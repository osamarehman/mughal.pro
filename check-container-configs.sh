#!/bin/bash

# Container Configuration Check Script
# This script checks for common configuration issues in Docker container configuration files

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

# Function to check Redis configuration
check_redis_config() {
    print_header "Checking Redis Configuration"
    
    # Common locations for Redis configuration
    LOCATIONS=(
        "/opt/docker/redis/redis.conf"
        "/opt/docker/data/redis/redis.conf"
        "/opt/docker/compose/redis/redis.conf"
        "/opt/docker/compose/data/redis/redis.conf"
    )
    
    FOUND=false
    
    for LOCATION in "${LOCATIONS[@]}"; do
        if [ -f "$LOCATION" ]; then
            print_info "Found Redis configuration at: $LOCATION"
            FOUND=true
            
            # Check for inline comments
            if grep -q "^[a-z].*#" "$LOCATION"; then
                print_error "Found inline comments in Redis configuration file"
                print_info "Redis doesn't support comments on the same line as configuration directives"
                print_info "Run fix-redis-config.sh to fix this issue"
            else
                print_success "No inline comments found in Redis configuration"
            fi
            
            # Check for other common issues
            if grep -q "^bind 127.0.0.1" "$LOCATION"; then
                print_warning "Redis is configured to listen only on localhost"
                print_info "This may prevent other containers from connecting to Redis"
                print_info "Consider changing 'bind 127.0.0.1' to 'bind 0.0.0.0'"
            fi
            
            if grep -q "^protected-mode yes" "$LOCATION" && ! grep -q "^requirepass" "$LOCATION"; then
                print_warning "Redis is in protected mode but no password is set"
                print_info "This may prevent other containers from connecting to Redis"
                print_info "Consider setting a password or disabling protected mode"
            fi
        fi
    done
    
    if [ "$FOUND" = false ]; then
        print_warning "Redis configuration file not found in common locations"
    fi
}

# Function to check Prometheus configuration
check_prometheus_config() {
    print_header "Checking Prometheus Configuration"
    
    # Common locations for Prometheus configuration
    LOCATIONS=(
        "/opt/docker/prometheus/prometheus.yml"
        "/opt/docker/data/prometheus/config/prometheus.yml"
        "/opt/docker/compose/prometheus/prometheus.yml"
        "/opt/docker/compose/data/prometheus/config/prometheus.yml"
    )
    
    FOUND=false
    
    for LOCATION in "${LOCATIONS[@]}"; do
        if [ -f "$LOCATION" ]; then
            print_info "Found Prometheus configuration at: $LOCATION"
            FOUND=true
            
            # Check for YAML syntax
            if command -v yamllint &> /dev/null; then
                print_info "Checking YAML syntax..."
                if ! yamllint -d relaxed "$LOCATION" &> /dev/null; then
                    print_error "YAML syntax errors found in Prometheus configuration"
                    yamllint -d relaxed "$LOCATION"
                else
                    print_success "YAML syntax is valid"
                fi
            else
                print_info "yamllint not installed, skipping YAML syntax check"
            fi
            
            # Check for common issues
            if ! grep -q "scrape_interval:" "$LOCATION"; then
                print_warning "No scrape_interval found in Prometheus configuration"
                print_info "This may cause issues with metrics collection"
            fi
            
            if ! grep -q "evaluation_interval:" "$LOCATION"; then
                print_warning "No evaluation_interval found in Prometheus configuration"
                print_info "This may cause issues with alert evaluation"
            fi
        fi
    done
    
    if [ "$FOUND" = false ]; then
        print_warning "Prometheus configuration file not found in common locations"
    fi
}

# Function to check Grafana configuration
check_grafana_config() {
    print_header "Checking Grafana Configuration"
    
    # Common locations for Grafana configuration
    LOCATIONS=(
        "/opt/docker/grafana/grafana.ini"
        "/opt/docker/data/grafana/config/grafana.ini"
        "/opt/docker/compose/grafana/grafana.ini"
        "/opt/docker/compose/data/grafana/config/grafana.ini"
    )
    
    FOUND=false
    
    for LOCATION in "${LOCATIONS[@]}"; do
        if [ -f "$LOCATION" ]; then
            print_info "Found Grafana configuration at: $LOCATION"
            FOUND=true
            
            # Check for common issues
            if grep -q "^domain = localhost" "$LOCATION"; then
                print_warning "Grafana domain is set to localhost"
                print_info "This may cause issues with authentication and cookies"
            fi
            
            if grep -q "^root_url = http://" "$LOCATION"; then
                print_warning "Grafana root_url is using HTTP instead of HTTPS"
                print_info "This may cause issues with secure cookies and authentication"
            fi
        fi
    done
    
    if [ "$FOUND" = false ]; then
        print_warning "Grafana configuration file not found in common locations"
    fi
}

# Function to check Loki configuration
check_loki_config() {
    print_header "Checking Loki Configuration"
    
    # Common locations for Loki configuration
    LOCATIONS=(
        "/opt/docker/loki/loki-config.yaml"
        "/opt/docker/data/loki/config/loki-config.yaml"
        "/opt/docker/compose/loki/loki-config.yaml"
        "/opt/docker/compose/data/loki/config/loki-config.yaml"
    )
    
    FOUND=false
    
    for LOCATION in "${LOCATIONS[@]}"; do
        if [ -f "$LOCATION" ]; then
            print_info "Found Loki configuration at: $LOCATION"
            FOUND=true
            
            # Check for YAML syntax
            if command -v yamllint &> /dev/null; then
                print_info "Checking YAML syntax..."
                if ! yamllint -d relaxed "$LOCATION" &> /dev/null; then
                    print_error "YAML syntax errors found in Loki configuration"
                    yamllint -d relaxed "$LOCATION"
                else
                    print_success "YAML syntax is valid"
                fi
            else
                print_info "yamllint not installed, skipping YAML syntax check"
            fi
            
            # Check for common issues
            if ! grep -q "storage:" "$LOCATION"; then
                print_warning "No storage configuration found in Loki configuration"
                print_info "This may cause issues with data persistence"
            fi
        fi
    done
    
    if [ "$FOUND" = false ]; then
        print_warning "Loki configuration file not found in common locations"
    fi
}

# Function to check Authelia configuration
check_authelia_config() {
    print_header "Checking Authelia Configuration"
    
    # Common locations for Authelia configuration
    LOCATIONS=(
        "/opt/docker/authelia/configuration.yml"
        "/opt/docker/data/authelia/config/configuration.yml"
        "/opt/docker/compose/authelia/configuration.yml"
        "/opt/docker/compose/data/authelia/config/configuration.yml"
    )
    
    FOUND=false
    
    for LOCATION in "${LOCATIONS[@]}"; do
        if [ -f "$LOCATION" ]; then
            print_info "Found Authelia configuration at: $LOCATION"
            FOUND=true
            
            # Check for YAML syntax
            if command -v yamllint &> /dev/null; then
                print_info "Checking YAML syntax..."
                if ! yamllint -d relaxed "$LOCATION" &> /dev/null; then
                    print_error "YAML syntax errors found in Authelia configuration"
                    yamllint -d relaxed "$LOCATION"
                else
                    print_success "YAML syntax is valid"
                fi
            else
                print_info "yamllint not installed, skipping YAML syntax check"
            fi
            
            # Check for common issues
            if ! grep -q "jwt_secret:" "$LOCATION"; then
                print_warning "No jwt_secret found in Authelia configuration"
                print_info "This may cause issues with authentication"
            fi
            
            if ! grep -q "encryption_key:" "$LOCATION"; then
                print_warning "No encryption_key found in Authelia configuration"
                print_info "This may cause issues with data encryption"
            fi
        fi
    done
    
    # Check users database
    for LOCATION in "${LOCATIONS[@]}"; do
        USERS_DB="${LOCATION%/*}/users_database.yml"
        if [ -f "$USERS_DB" ]; then
            print_info "Found Authelia users database at: $USERS_DB"
            
            # Check for YAML syntax
            if command -v yamllint &> /dev/null; then
                print_info "Checking YAML syntax..."
                if ! yamllint -d relaxed "$USERS_DB" &> /dev/null; then
                    print_error "YAML syntax errors found in Authelia users database"
                    yamllint -d relaxed "$USERS_DB"
                else
                    print_success "YAML syntax is valid"
                fi
            else
                print_info "yamllint not installed, skipping YAML syntax check"
            fi
            
            # Check for password hashes
            if grep -q "password: \"\"" "$USERS_DB"; then
                print_error "Empty password found in Authelia users database"
                print_info "This will prevent users from logging in"
            fi
            
            if grep -q "password: \"[^$]" "$USERS_DB"; then
                print_warning "Password hash doesn't start with $ in Authelia users database"
                print_info "This may indicate an invalid hash format"
                print_info "Run fix-authelia-hash.sh to fix this issue"
            fi
        fi
    done
    
    if [ "$FOUND" = false ]; then
        print_warning "Authelia configuration file not found in common locations"
    fi
}

# Function to check Caddy configuration
check_caddy_config() {
    print_header "Checking Caddy Configuration"
    
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
            print_info "Found Caddy configuration at: $LOCATION"
            FOUND=true
            
            # Check for common issues
            if ! grep -q "email" "$LOCATION"; then
                print_warning "No email address found in Caddy configuration"
                print_info "This may cause issues with Let's Encrypt certificate generation"
            fi
            
            # Check for reverse proxy configurations
            if ! grep -q "reverse_proxy" "$LOCATION"; then
                print_warning "No reverse_proxy directives found in Caddy configuration"
                print_info "This may indicate that Caddy is not properly configured to proxy requests to your services"
            fi
        fi
    done
    
    if [ "$FOUND" = false ]; then
        print_warning "Caddy configuration file not found in common locations"
    fi
}

# Function to check Docker Compose configuration
check_docker_compose() {
    print_header "Checking Docker Compose Configuration"
    
    # Common locations for Docker Compose configuration
    LOCATIONS=(
        "/opt/docker/compose/docker-compose.yml"
        "/opt/docker/docker-compose.yml"
    )
    
    FOUND=false
    
    for LOCATION in "${LOCATIONS[@]}"; do
        if [ -f "$LOCATION" ]; then
            print_info "Found Docker Compose configuration at: $LOCATION"
            FOUND=true
            
            # Check for YAML syntax
            if command -v yamllint &> /dev/null; then
                print_info "Checking YAML syntax..."
                if ! yamllint -d relaxed "$LOCATION" &> /dev/null; then
                    print_error "YAML syntax errors found in Docker Compose configuration"
                    yamllint -d relaxed "$LOCATION"
                else
                    print_success "YAML syntax is valid"
                fi
            else
                print_info "yamllint not installed, skipping YAML syntax check"
            fi
            
            # Check for common issues
            if ! grep -q "version:" "$LOCATION"; then
                print_warning "No version specified in Docker Compose configuration"
                print_info "This may cause compatibility issues"
            fi
            
            # Check for network configurations
            if ! grep -q "networks:" "$LOCATION"; then
                print_warning "No networks defined in Docker Compose configuration"
                print_info "This may cause issues with container communication"
            fi
            
            # Check for volume configurations
            if ! grep -q "volumes:" "$LOCATION"; then
                print_warning "No volumes defined in Docker Compose configuration"
                print_info "This may cause issues with data persistence"
            fi
        fi
    done
    
    if [ "$FOUND" = false ]; then
        print_warning "Docker Compose configuration file not found in common locations"
    fi
}

# Function to check container status
check_container_status() {
    print_header "Checking Container Status"
    
    # Check if Docker is running
    if ! docker info &> /dev/null; then
        print_error "Docker is not running or you don't have permission to access it"
        print_info "Try running with sudo or check if Docker service is running"
        return 1
    fi
    
    # Get list of containers
    CONTAINERS=$(docker ps -a --format "{{.Names}}")
    
    if [ -z "$CONTAINERS" ]; then
        print_warning "No containers found"
        return 0
    fi
    
    # Check each container
    for CONTAINER in $CONTAINERS; do
        STATUS=$(docker inspect --format "{{.State.Status}}" "$CONTAINER")
        RESTARTS=$(docker inspect --format "{{.RestartCount}}" "$CONTAINER" 2>/dev/null || echo "N/A")
        
        if [ "$STATUS" = "running" ]; then
            if [ "$RESTARTS" -gt 5 ] 2>/dev/null; then
                print_warning "Container $CONTAINER is running but has restarted $RESTARTS times"
                print_info "Check logs for errors: docker logs $CONTAINER"
            else
                print_success "Container $CONTAINER is running (Restarts: $RESTARTS)"
            fi
        else
            print_error "Container $CONTAINER is not running (Status: $STATUS)"
            print_info "Check logs for errors: docker logs $CONTAINER"
        fi
    done
}

# Main function
main() {
    print_header "Container Configuration Check Script"
    print_info "This script checks for common configuration issues in Docker container configuration files"
    
    # Check if running as root
    if [ "$(id -u)" -ne 0 ]; then
        print_warning "This script may need root privileges to access some configuration files"
        print_info "Consider running with sudo if you encounter permission errors"
    fi
    
    # Check container status
    check_container_status
    
    # Check configuration files
    check_redis_config
    check_prometheus_config
    check_grafana_config
    check_loki_config
    check_authelia_config
    check_caddy_config
    check_docker_compose
    
    print_header "Recommendations"
    print_info "1. Fix any errors or warnings reported above"
    print_info "2. Run the cleanup-docker.sh script to clean up your Docker environment:"
    print_info "   sudo ./cleanup-docker.sh"
    print_info "3. Run the setup.sh script again to recreate your containers:"
    print_info "   sudo ./setup.sh"
    print_info "4. Check the container logs to verify they're working correctly:"
    print_info "   docker logs <container_name>"
}

# Run main function
main
