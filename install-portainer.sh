#!/bin/bash

# Portainer Installation Script for Debian 12
# This script installs Docker and Portainer CE on Debian 12
# It requires su/root access

# Exit on error
set -e

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

# Function to check if running as root
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        print_error "This script must be run as root"
        exit 1
    fi
    print_success "Running with root privileges"
}

# Function to install Docker
install_docker() {
    print_header "Installing Docker"
    
    # Check if Docker is already installed
    if command -v docker &> /dev/null; then
        print_success "Docker is already installed"
        return 0
    fi
    
    print_info "Installing Docker..."
    
    # Update package index
    apt-get update
    
    # Install prerequisites
    apt-get install -y \
        ca-certificates \
        curl \
        gnupg \
        lsb-release
    
    # Add Docker's official GPG key
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc
    
    # Set up the Docker repository
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Update package index again
    apt-get update
    
    # Install Docker Engine
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Start and enable Docker service
    systemctl start docker
    systemctl enable docker
    
    print_success "Docker installed successfully"
    
    # Verify Docker installation
    print_info "Verifying Docker installation..."
    if docker run --rm hello-world &> /dev/null; then
        print_success "Docker is working correctly"
    else
        print_error "Docker verification failed. Please check Docker installation manually."
        exit 1
    fi
}

# Function to install Portainer
install_portainer() {
    print_header "Installing Portainer"
    
    # Create directory for Portainer data
    mkdir -p /opt/portainer/data
    
    # Check if Portainer is already running
    if docker ps --format '{{.Names}}' | grep -q "^portainer$"; then
        print_warning "Portainer is already running. Stopping and removing..."
        docker stop portainer
        docker rm portainer
    fi
    
    # Check if Portainer container exists but is not running
    if docker ps -a --format '{{.Names}}' | grep -q "^portainer$"; then
        print_warning "Portainer container exists but is not running. Removing..."
        docker rm portainer
    fi
    
    # Pull the latest Portainer image
    print_info "Pulling the latest Portainer image..."
    docker pull portainer/portainer-ce:latest
    
    # Run Portainer container
    print_info "Starting Portainer container..."
    docker run -d \
        --name portainer \
        --restart=always \
        -p 8000:8000 \
        -p 9000:9000 \
        -p 9443:9443 \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -v /opt/portainer/data:/data \
        portainer/portainer-ce:latest
    
    # Verify Portainer is running
    if docker ps --format '{{.Names}}' | grep -q "^portainer$"; then
        print_success "Portainer installed and running"
        
        # Get server IP address
        SERVER_IP=$(hostname -I | awk '{print $1}')
        print_info "You can access Portainer at:"
        print_info "- HTTP: http://${SERVER_IP}:9000"
        print_info "- HTTPS: https://${SERVER_IP}:9443"
        print_info "Initial setup will require you to create an admin user"
    else
        print_error "Portainer installation failed. Please check Docker logs for more information."
        docker logs portainer
        exit 1
    fi
}

# Function to create a docker-compose.yml file
create_docker_compose() {
    print_header "Creating Docker Compose File"
    
    # Create directory for Docker Compose files
    mkdir -p /opt/docker/compose
    
    # Create docker-compose.yml file
    cat > /opt/docker/compose/docker-compose.yml << EOF
version: '3'

services:
  portainer:
    image: portainer/portainer-ce:latest
    container_name: portainer
    restart: unless-stopped
    security_opt:
      - no-new-privileges:true
    ports:
      - "8000:8000"
      - "9000:9000"
      - "9443:9443"
    volumes:
      - /etc/localtime:/etc/localtime:ro
      - /var/run/docker.sock:/var/run/docker.sock
      - /opt/portainer/data:/data
EOF
    
    print_success "Docker Compose file created at /opt/docker/compose/docker-compose.yml"
    print_info "You can use this to deploy Portainer using Docker Compose"
    print_info "Run 'cd /opt/docker/compose && docker compose up -d' to start Portainer"
}

# Main function
main() {
    print_header "Portainer Installation Script for Debian 12"
    
    # Check if running as root
    check_root
    
    # Install Docker
    install_docker
    
    # Install Portainer
    install_portainer
    
    # Create docker-compose.yml file
    create_docker_compose
    
    print_header "Installation Complete"
    print_success "Portainer has been successfully installed"
    
    # Get server IP address
    SERVER_IP=$(hostname -I | awk '{print $1}')
    
    print_info "You can access Portainer at:"
    print_info "- HTTP: http://${SERVER_IP}:9000"
    print_info "- HTTPS: https://${SERVER_IP}:9443"
    
    print_header "Next Steps"
    print_info "1. To run Docker commands without sudo, add your user to the docker group:"
    print_info "   sudo usermod -aG docker YOUR_USERNAME"
    print_info "   (Log out and log back in for this to take effect)"
    print_info "2. Access Portainer web interface and complete the initial setup"
    print_info "3. Use Portainer to manage your Docker containers, images, networks, and volumes"
}

# Run main function
main
