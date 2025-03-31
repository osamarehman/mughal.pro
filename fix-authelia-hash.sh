#!/bin/bash

# Fix script for Authelia password hash generation
# This script modifies the setup-credentials.sh file to ensure proper Argon2 hash generation

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

# Function to backup the setup-credentials.sh file
backup_file() {
    print_header "Backing Up setup-credentials.sh"
    
    if [ ! -f "setup-credentials.sh" ]; then
        print_error "setup-credentials.sh not found in the current directory"
        exit 1
    fi
    
    cp setup-credentials.sh setup-credentials.sh.bak
    print_success "Backup created: setup-credentials.sh.bak"
}

# Function to fix the generate_argon2_hash function
fix_argon2_hash_function() {
    print_header "Fixing Argon2 Hash Generation"
    
    # Check if the file contains the generate_argon2_hash function
    if ! grep -q "generate_argon2_hash" setup-credentials.sh; then
        print_error "generate_argon2_hash function not found in setup-credentials.sh"
        exit 1
    fi
    
    print_info "Modifying generate_argon2_hash function..."
    
    # Create a temporary file with the fixed function
    cat > temp_function.sh << 'EOF'
# Generate Argon2 hash for password
generate_argon2_hash() {
    local password=$1
    local hash=""
    
    print_info "Generating Argon2 hash..."
    
    # Method 1: Use Docker to generate hash with Authelia container
    if hash docker 2>/dev/null; then
        hash=$(docker run --rm authelia/authelia:latest authelia crypto hash generate argon2 --password "$password" 2>/dev/null)
        if [ -n "$hash" ]; then
            echo "$hash"
            return 0
        fi
    fi
    
    # Method 2: Use argon2 command if available
    if hash argon2 2>/dev/null; then
        # Create a temporary file with the password
        local temp_file=$(mktemp)
        echo -n "$password" > "$temp_file"
        
        # Generate hash
        hash=$(argon2 "$temp_file" -id -t 3 -m 12 -p 1 -l 32 -e)
        rm "$temp_file"
        
        if [ -n "$hash" ]; then
            echo "$hash"
            return 0
        fi
    fi
    
    # Method 3: Use Python if available
    if hash python3 2>/dev/null; then
        if python3 -c "import argon2" 2>/dev/null; then
            hash=$(python3 -c "
from argon2 import PasswordHasher
ph = PasswordHasher(time_cost=3, memory_cost=4096, parallelism=1, hash_len=32, salt_len=16)
print(ph.hash('$password'))
" 2>/dev/null)
            
            if [ -n "$hash" ]; then
                echo "$hash"
                return 0
            fi
        fi
    fi
    
    # Method 4: Use Node.js if available
    if hash node 2>/dev/null; then
        hash=$(node -e "
const crypto = require('crypto');
const argon2 = require('argon2');
async function hash() {
    try {
        const hashed = await argon2.hash('$password', {
            type: argon2.argon2id,
            timeCost: 3,
            memoryCost: 4096,
            parallelism: 1,
            hashLength: 32,
            saltLength: 16
        });
        console.log(hashed);
    } catch (err) {
        console.error(err);
    }
}
hash();
" 2>/dev/null)
        
        if [ -n "$hash" ]; then
            echo "$hash"
            return 0
        fi
    fi
    
    # Fallback: Generate a placeholder hash that will be recognized by Authelia
    # This is not secure and should be replaced with a proper hash
    print_warning "Could not generate proper Argon2 hash. Using placeholder hash."
    echo '$argon2id$v=19$m=65536,t=3,p=4$c2FsdHNhbHRzYWx0c2FsdA$qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq'
}
EOF
    
    # Replace the function in the file
    sed -i '/# Generate Argon2 hash for password/,/^}/c\' setup-credentials.sh
    sed -i '/# Generate Argon2 hash for password/r temp_function.sh' setup-credentials.sh
    
    # Remove the temporary file
    rm temp_function.sh
    
    print_success "generate_argon2_hash function updated"
}

# Function to check if the fix was applied correctly
verify_fix() {
    print_header "Verifying Fix"
    
    if grep -q "authelia/authelia:latest authelia crypto hash generate argon2" setup-credentials.sh; then
        print_success "Fix applied successfully"
    else
        print_error "Fix may not have been applied correctly"
        print_info "Please check setup-credentials.sh manually"
    fi
}

# Main function
main() {
    print_header "Authelia Hash Fix Script"
    print_info "This script will fix the Argon2 hash generation for Authelia passwords"
    
    # Backup the file
    backup_file
    
    # Fix the generate_argon2_hash function
    fix_argon2_hash_function
    
    # Verify the fix
    verify_fix
    
    print_header "Next Steps"
    print_info "1. Run the cleanup-docker.sh script to clean up your Docker environment"
    print_info "2. Run the setup.sh script again to recreate your containers"
    print_info "3. Check the Authelia logs to verify it's working correctly:"
    print_info "   docker logs authelia"
}

# Run main function
main
