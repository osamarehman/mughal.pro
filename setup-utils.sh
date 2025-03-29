#!/bin/bash

# Server Setup Utilities Script
# This script contains utility functions for the setup script

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

# Function to prompt for yes/no
prompt_yes_no() {
    local prompt=$1
    local default=${2:-y}
    
    local yn
    while true; do
        read -p "$prompt [${default}]: " yn
        yn=${yn:-$default}
        case $yn in
            [Yy]* ) return 0;;
            [Nn]* ) return 1;;
            * ) echo "Please answer yes or no.";;
        esac
    done
}

# Function to prompt for a value with a default
prompt_with_default() {
    local prompt=$1
    local default=$2
    local value
    
    read -p "$prompt [$default]: " value
    echo ${value:-$default}
}

# Function to validate password for script safety
validate_password() {
    local password=$1
    
    # Check for characters that might break shell scripts
    if [[ "$password" == *"'"* || "$password" == *"\""* || "$password" == *"\\"* || 
          "$password" == *";"* || "$password" == *"&"* || "$password" == *"|"* || 
          "$password" == *">"* || "$password" == *"<"* || "$password" == *"("* || 
          "$password" == *")"* || "$password" == *"{"* || "$password" == *"}"* || 
          "$password" == *"["* || "$password" == *"]"* || "$password" == *"$"* || 
          "$password" == *"#"* || "$password" == *"!"* || "$password" == *"~"* || 
          "$password" == *"\`"* ]]; then
        return 1
    fi
    
    return 0
}

# Function to prompt for a password with confirmation
prompt_password() {
    local prompt=$1
    local generate=${2:-true}
    local password
    
    if $generate && prompt_yes_no "Generate a secure password automatically?"; then
        password=$(generate_password)
        # Ensure generated password is safe for shell scripts
        # Base64 encoding should be safe, but let's make sure
        password=$(echo "$password" | tr -dc 'a-zA-Z0-9_-')
        # Print to stderr so it doesn't get captured in variable assignment
        echo "Generated password: $password" >&2
        # Return just the password
        echo "$password"
        return
    fi
    
    while true; do
        read -s -p "$prompt: " password
        echo
        
        # Validate password
        if ! validate_password "$password"; then
            echo "Password contains special characters that may break the script."
            echo "Please avoid using: ' \" \\ ; & | > < ( ) { } [ ] $ # ! ~ \`"
            continue
        fi
        
        read -s -p "Confirm password: " password2
        echo
        
        if [ "$password" = "$password2" ]; then
            echo "$password"
            return
        else
            echo "Passwords do not match. Please try again."
        fi
    done
}

# Function to prompt for a domain name
prompt_domain() {
    local domain
    
    while true; do
        read -p "Enter your domain name (e.g., example.com): " domain
        
        if [[ $domain =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{1,61}[a-zA-Z0-9]\.[a-zA-Z]{2,}$ ]]; then
            echo "$domain"
            return
        else
            echo "Invalid domain name. Please enter a valid domain name."
        fi
    done
}

# Function to prompt for an email address
prompt_email() {
    local email
    
    while true; do
        read -p "Enter your email address: " email
        
        if [[ $email =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
            echo "$email"
            return
        else
            echo "Invalid email address. Please enter a valid email address."
        fi
    done
}

# Function to prompt for a timezone
prompt_timezone() {
    local timezone
    
    # Get current timezone
    local current_timezone=$(timedatectl | grep "Time zone" | awk '{print $3}')
    
    # If current timezone is not available, use default
    current_timezone=${current_timezone:-$DEFAULT_TIMEZONE}
    
    # Prompt for timezone
    read -p "Enter your timezone [$current_timezone]: " timezone
    
    # Use default if empty
    timezone=${timezone:-$current_timezone}
    
    echo "$timezone"
}

# Function to generate a secure password
generate_password() {
    # Generate a secure password and filter out potentially problematic characters
    openssl rand -base64 32 | tr -dc 'a-zA-Z0-9_-'  # Filter to only include safe characters
}

# Function to generate a secure token
generate_token() {
    # Hex output is already safe (only contains 0-9 and a-f)
    openssl rand -hex 32
}

# Function to generate an Argon2 hash
generate_argon2_hash() {
    local password=$1
    local hash=""
    
    # Try using native argon2 if available
    if command -v argon2 &> /dev/null; then
        hash=$(echo -n "$password" | argon2 "$(openssl rand -hex 8)" -id -t 3 -m 16 -p 4 -l 32 -e 2>/dev/null)
        if [ $? -eq 0 ] && [ -n "$hash" ]; then
            # Escape dollar signs to prevent variable interpolation in Docker Compose
            hash=$(echo "$hash" | sed 's/\$/\$\$/g')
            echo "$hash"
            return 0
        fi
        print_warning "Native argon2 failed, falling back to Docker method"
    fi
    
    # Fall back to Docker
    if command -v docker &> /dev/null; then
        # Check if Docker is running
        if docker info &>/dev/null; then
            # Use a temporary file to avoid issues with special characters
            local temp_file=$(mktemp)
            docker run --rm authelia/authelia:latest authelia crypto hash generate argon2 --password "$password" > "$temp_file" 2>/dev/null
            if [ $? -eq 0 ] && [ -s "$temp_file" ]; then
                # Escape dollar signs to prevent variable interpolation in Docker Compose
                hash=$(cat "$temp_file" | sed 's/\$/\$\$/g')
                rm -f "$temp_file"
                echo "$hash"
                return 0
            fi
            rm -f "$temp_file"
            print_warning "Docker method failed for Argon2 hash generation"
        else
            print_warning "Docker is not running, cannot generate Argon2 hash"
        fi
    else
        print_warning "Docker is not available, cannot generate Argon2 hash"
    fi
    
    # Final fallback - use a simple hash if everything else fails
    # This is not as secure but prevents the script from failing
    print_warning "Falling back to simple hash method (less secure)"
    local simple_hash="$(echo -n "${password}$(openssl rand -hex 8)" | sha256sum | awk '{print $1}')"
    echo "$simple_hash"
}

# These functions have been moved to their respective files:
# - create_directory_structure -> setup-directories.sh
# - save_credentials -> setup-credentials.sh
