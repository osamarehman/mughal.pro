#!/bin/bash

# Redis Configuration Fix Script
# This script fixes the Redis configuration file by moving comments to separate lines

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

# Function to fix Redis configuration
fix_redis_config() {
    local redis_dir=$1
    local redis_conf="$redis_dir/redis.conf"
    
    if [ ! -f "$redis_conf" ]; then
        print_error "Redis configuration file not found at: $redis_conf"
        return 1
    fi
    
    print_info "Backing up original Redis configuration file..."
    cp "$redis_conf" "$redis_conf.bak"
    print_success "Backup created at: $redis_conf.bak"
    
    print_info "Fixing Redis configuration file..."
    
    # Create a temporary file
    local temp_file=$(mktemp)
    
    # Process the file line by line
    while IFS= read -r line; do
        # Check if the line contains a configuration directive followed by a comment
        if [[ "$line" =~ ^[a-z].+[^\\]#.* ]]; then
            # Extract the directive and the comment
            directive=$(echo "$line" | sed -E 's/^([^#]+)#.*/\1/')
            comment=$(echo "$line" | sed -E 's/^[^#]+#(.*)/# \1/')
            
            # Write the comment and directive on separate lines
            echo "$comment" >> "$temp_file"
            echo "$directive" >> "$temp_file"
        else
            # Write the line as is
            echo "$line" >> "$temp_file"
        fi
    done < "$redis_conf"
    
    # Replace the original file with the fixed one
    mv "$temp_file" "$redis_conf"
    
    print_success "Redis configuration file fixed"
    
    # Check if the fix was successful
    if grep -q "^[a-z].*#" "$redis_conf"; then
        print_warning "Some inline comments may still be present in the Redis configuration file"
        print_info "You may need to manually edit the file to fix these issues"
    else
        print_success "No inline comments found in the fixed Redis configuration file"
    fi
}

# Function to find Redis configuration files
find_redis_configs() {
    print_header "Searching for Redis Configuration Files"
    
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
            
            # Check if the file contains inline comments
            if grep -q "^[a-z].*#" "$LOCATION"; then
                print_warning "Found inline comments in Redis configuration file"
                print_info "Fixing Redis configuration file..."
                fix_redis_config "$(dirname "$LOCATION")"
            else
                print_success "No inline comments found in Redis configuration file"
            fi
        fi
    done
    
    if [ "$FOUND" = false ]; then
        print_warning "Redis configuration file not found in common locations"
        print_info "Checking for Redis configuration in the current directory..."
        
        if [ -f "./redis.conf" ]; then
            print_info "Found Redis configuration in the current directory"
            
            # Check if the file contains inline comments
            if grep -q "^[a-z].*#" "./redis.conf"; then
                print_warning "Found inline comments in Redis configuration file"
                print_info "Fixing Redis configuration file..."
                fix_redis_config "."
            else
                print_success "No inline comments found in Redis configuration file"
            fi
        else
            print_error "Redis configuration file not found"
            print_info "Please specify the path to the Redis configuration file as an argument"
            print_info "Example: $0 /path/to/redis/config/dir"
            exit 1
        fi
    fi
}

# Function to fix Redis configuration in setup-resources.sh
fix_setup_resources() {
    print_header "Fixing Redis Configuration Generation in setup-resources.sh"
    
    if [ ! -f "setup-resources.sh" ]; then
        print_error "setup-resources.sh not found in the current directory"
        return 1
    fi
    
    print_info "Backing up original setup-resources.sh file..."
    cp "setup-resources.sh" "setup-resources.sh.bak"
    print_success "Backup created at: setup-resources.sh.bak"
    
    print_info "Fixing Redis configuration generation in setup-resources.sh..."
    
    # Use sed to fix the Redis configuration generation
    sed -i 's/requirepass ""  # No password by default/# No password by default, set in environment if needed\nrequirepass ""/g' "setup-resources.sh"
    sed -i 's/logfile ""  # Log to stdout/# Log to stdout\nlogfile ""/g' "setup-resources.sh"
    
    print_success "Redis configuration generation fixed in setup-resources.sh"
}

# Main function
main() {
    print_header "Redis Configuration Fix Script"
    print_info "This script fixes the Redis configuration file by moving comments to separate lines"
    
    # Check if running as root
    if [ "$(id -u)" -ne 0 ]; then
        print_warning "This script may need root privileges to access some configuration files"
        print_info "Consider running with sudo if you encounter permission errors"
    fi
    
    # Check if a path was provided as an argument
    if [ $# -eq 1 ]; then
        if [ -d "$1" ]; then
            print_info "Using provided directory: $1"
            fix_redis_config "$1"
        else
            print_error "Provided path is not a directory: $1"
            exit 1
        fi
    else
        # Find and fix Redis configuration files
        find_redis_configs
        
        # Fix Redis configuration generation in setup-resources.sh
        fix_setup_resources
    fi
    
    print_header "Next Steps"
    print_info "1. Clean up your Docker environment:"
    print_info "   sudo ./cleanup-docker.sh"
    print_info "2. Run the setup.sh script again to recreate your containers:"
    print_info "   sudo ./setup.sh"
    print_info "3. Check the Redis container logs to verify it's working correctly:"
    print_info "   docker logs redis"
}

# Run main function
main "$@"
