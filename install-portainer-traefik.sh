#!/bin/bash

# Portainer and Traefik Installation Script for Debian 12
# This script installs Docker, Portainer CE, and Traefik on Debian 12
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

# Function to check if running as root
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        print_error "This script must be run as root"
        exit 1
    fi
    print_success "Running with root privileges"
}

# Function to remove old Docker installations
remove_old_docker() {
    print_header "Checking for old Docker installations"
    
    # Check if any conflicting packages are installed
    local old_packages=false
    for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do
        if dpkg -l | grep -q "^ii  $pkg"; then
            old_packages=true
            print_warning "Found conflicting package: $pkg"
        fi
    done
    
    if $old_packages; then
        print_info "Removing conflicting packages..."
        apt-get remove -y docker.io docker-doc docker-compose podman-docker containerd runc
        print_success "Conflicting packages removed"
    else
        print_success "No conflicting packages found"
    fi
}

# Function to check if Docker is installed and install if needed
install_docker() {
    print_header "Checking Docker Installation"
    
    if command -v docker &> /dev/null; then
        print_success "Docker is already installed"
    else
        print_info "Docker is not installed. Installing Docker..."
        
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
    fi
    
    # Check if Docker is running
    if systemctl is-active --quiet docker; then
        print_success "Docker is running"
    else
        print_warning "Docker is not running. Starting Docker..."
        systemctl start docker
        print_success "Docker started"
    fi
    
    # Verify Docker installation
    print_info "Verifying Docker installation..."
    if docker run --rm hello-world &> /dev/null; then
        print_success "Docker is working correctly"
    else
        print_warning "Docker verification failed. Please check Docker installation manually."
    fi
}

# Function to install Docker Compose
install_docker_compose() {
    print_header "Checking Docker Compose Installation"
    
    # Check if Docker Compose is already installed via plugin
    if docker compose version &> /dev/null; then
        print_success "Docker Compose plugin is already installed"
        return 0
    fi
    
    # Check if standalone Docker Compose is already installed
    if command -v docker-compose &> /dev/null; then
        print_success "Docker Compose standalone is already installed"
        return 0
    fi
    
    print_info "Docker Compose is not installed. Installing Docker Compose..."
    
    # Install Docker Compose standalone version
    COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)
    
    # If we couldn't get the latest version, use a known stable version
    if [ -z "$COMPOSE_VERSION" ]; then
        COMPOSE_VERSION="v2.23.3"
        print_warning "Could not determine latest Docker Compose version. Using $COMPOSE_VERSION instead."
    fi
    
    print_info "Installing Docker Compose $COMPOSE_VERSION..."
    
    curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    
    # Verify installation
    if docker-compose --version &> /dev/null; then
        print_success "Docker Compose installed successfully"
    else
        print_warning "Docker Compose installation may have failed. Please check manually."
    fi
}

# Function to configure Docker post-installation
configure_docker() {
    print_header "Configuring Docker"
    
    # Create docker group if it doesn't exist
    if ! getent group docker > /dev/null; then
        print_info "Creating docker group..."
        groupadd docker
        print_success "Docker group created"
    else
        print_success "Docker group already exists"
    fi
    
    # Configure Docker to start on boot
    print_info "Configuring Docker to start on boot..."
    systemctl enable docker.service
    systemctl enable containerd.service
    print_success "Docker configured to start on boot"
    
    # Configure logging driver
    print_info "Configuring Docker logging driver..."
    mkdir -p /etc/docker
    
    # Check if daemon.json exists
    if [ -f /etc/docker/daemon.json ]; then
        print_info "Existing daemon.json found, backing up..."
        cp /etc/docker/daemon.json /etc/docker/daemon.json.bak
    fi
    
    # Create or update daemon.json with log configuration
    cat > /etc/docker/daemon.json << EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF
    
    print_info "Restarting Docker to apply logging configuration..."
    systemctl restart docker
    print_success "Docker logging configured"
    
    print_info "Docker post-installation configuration complete"
    print_info "To run Docker as a non-root user, add the user to the docker group:"
    print_info "  sudo usermod -aG docker USERNAME"
    print_info "  newgrp docker"
}

# Function to create necessary directories
create_directories() {
    print_header "Creating Directories"
    
    # Create directory for Portainer data
    mkdir -p /opt/portainer/data
    
    # Create directory for Traefik data
    mkdir -p /opt/traefik/data
    
    # Create directory for Docker Compose files
    mkdir -p /opt/docker/compose
    
    print_success "Directories created"
}

# Function to create Docker network
create_docker_network() {
    print_header "Creating Docker Network"
    
    # Check if the network already exists
    if docker network ls | grep -q "proxy"; then
        print_info "Docker network 'proxy' already exists"
    else
        print_info "Creating Docker network 'proxy'..."
        docker network create proxy
        print_success "Docker network 'proxy' created"
    fi
}

# Function to install Portainer
install_portainer() {
    print_header "Installing Portainer"
    
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
        --network=proxy \
        -p 9000:9000 \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -v /opt/portainer/data:/data \
        portainer/portainer-ce:latest
    
    # Verify Portainer is running
    if docker ps --format '{{.Names}}' | grep -q "^portainer$"; then
        print_success "Portainer installed and running"
        
        # Get server IP address
        SERVER_IP=$(hostname -I | awk '{print $1}')
        print_info "You can access Portainer at http://${SERVER_IP}:9000"
        print_info "Initial setup will require you to create an admin user"
    else
        print_error "Portainer installation failed. Please check Docker logs for more information."
        docker logs portainer
    fi
}

# Function to configure and install Traefik
install_traefik() {
    print_header "Installing Traefik"
    
    # Prompt for email address for Let's Encrypt
    EMAIL=$(prompt_with_default "Enter your email address for Let's Encrypt" "admin@example.com")
    
    # Create Traefik configuration directory
    mkdir -p /opt/traefik/config
    
    # Create acme.json file for Let's Encrypt certificates
    touch /opt/traefik/acme.json
    chmod 600 /opt/traefik/acme.json
    
    # Create Traefik configuration file
    cat > /opt/traefik/config/traefik.yml << EOF
api:
  dashboard: true
  insecure: true

entryPoints:
  web:
    address: ":80"
    http:
      redirections:
        entryPoint:
          to: websecure
          scheme: https
  websecure:
    address: ":443"

providers:
  docker:
    endpoint: "unix:///var/run/docker.sock"
    exposedByDefault: false
    network: proxy

certificatesResolvers:
  letsencrypt:
    acme:
      email: ${EMAIL}
      storage: /acme.json
      httpChallenge:
        entryPoint: web
EOF
    
    # Create Traefik dynamic configuration file
    mkdir -p /opt/traefik/config/dynamic
    cat > /opt/traefik/config/dynamic/config.yml << EOF
http:
  middlewares:
    secureHeaders:
      headers:
        sslRedirect: true
        forceSTSHeader: true
        stsIncludeSubdomains: true
        stsPreload: true
        stsSeconds: 31536000
    
    portainerAuth:
      basicAuth:
        users:
          - "admin:$$apr1$$ruca84Hq$$mbjdMZBAG.KWn7vfN/SNK/"  # Default: admin/admin (change this in production)
EOF
    
    # Check if Traefik is already running
    if docker ps --format '{{.Names}}' | grep -q "^traefik$"; then
        print_warning "Traefik is already running. Stopping and removing..."
        docker stop traefik
        docker rm traefik
    fi
    
    # Check if Traefik container exists but is not running
    if docker ps -a --format '{{.Names}}' | grep -q "^traefik$"; then
        print_warning "Traefik container exists but is not running. Removing..."
        docker rm traefik
    fi
    
    # Pull the latest Traefik image
    print_info "Pulling the latest Traefik image..."
    docker pull traefik:latest
    
    # Run Traefik container
    print_info "Starting Traefik container..."
    docker run -d \
        --name traefik \
        --restart=always \
        --network=proxy \
        -p 80:80 \
        -p 443:443 \
        -p 8080:8080 \
        -v /var/run/docker.sock:/var/run/docker.sock:ro \
        -v /opt/traefik/config/traefik.yml:/traefik.yml:ro \
        -v /opt/traefik/config/dynamic:/config:ro \
        -v /opt/traefik/acme.json:/acme.json \
        -l "traefik.enable=true" \
        -l "traefik.http.routers.traefik.rule=Host(\`traefik.localhost\`)" \
        -l "traefik.http.routers.traefik.service=api@internal" \
        -l "traefik.http.routers.traefik.entrypoints=websecure" \
        -l "traefik.http.routers.traefik.middlewares=secureHeaders@file" \
        traefik:latest
    
    # Verify Traefik is running
    if docker ps --format '{{.Names}}' | grep -q "^traefik$"; then
        print_success "Traefik installed and running"
        
        # Get server IP address
        SERVER_IP=$(hostname -I | awk '{print $1}')
        print_info "You can access Traefik dashboard at http://${SERVER_IP}:8080"
    else
        print_error "Traefik installation failed. Please check Docker logs for more information."
        docker logs traefik
    fi
}

# Function to create a docker-compose.yml file for both services
create_docker_compose() {
    print_header "Creating Docker Compose File"
    
    # Prompt for domain names
    DOMAIN=$(prompt_with_default "Enter your domain name (e.g., example.com)" "example.com")
    TRAEFIK_SUBDOMAIN=$(prompt_with_default "Enter subdomain for Traefik dashboard" "traefik")
    PORTAINER_SUBDOMAIN=$(prompt_with_default "Enter subdomain for Portainer" "portainer")
    EMAIL=$(prompt_with_default "Enter your email address for Let's Encrypt" "admin@example.com")
    
    # Create docker-compose.yml file
    cat > /opt/docker/compose/docker-compose.yml << EOF
version: '3'

services:
  traefik:
    image: traefik:latest
    container_name: traefik
    restart: unless-stopped
    security_opt:
      - no-new-privileges:true
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /etc/localtime:/etc/localtime:ro
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - /opt/traefik/config/traefik.yml:/traefik.yml:ro
      - /opt/traefik/config/dynamic:/config:ro
      - /opt/traefik/acme.json:/acme.json
    networks:
      - proxy
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.traefik-secure.entrypoints=websecure"
      - "traefik.http.routers.traefik-secure.rule=Host(\`${TRAEFIK_SUBDOMAIN}.${DOMAIN}\`)"
      - "traefik.http.routers.traefik-secure.service=api@internal"
      - "traefik.http.routers.traefik-secure.middlewares=secureHeaders@file,traefik-auth"
      - "traefik.http.middlewares.traefik-auth.basicauth.users=admin:$$apr1$$ruca84Hq$$mbjdMZBAG.KWn7vfN/SNK/"  # Default: admin/admin (change this in production)

  portainer:
    image: portainer/portainer-ce:latest
    container_name: portainer
    restart: unless-stopped
    security_opt:
      - no-new-privileges:true
    volumes:
      - /etc/localtime:/etc/localtime:ro
      - /var/run/docker.sock:/var/run/docker.sock
      - /opt/portainer/data:/data
    networks:
      - proxy
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.portainer-secure.entrypoints=websecure"
      - "traefik.http.routers.portainer-secure.rule=Host(\`${PORTAINER_SUBDOMAIN}.${DOMAIN}\`)"
      - "traefik.http.routers.portainer-secure.service=portainer"
      - "traefik.http.services.portainer.loadbalancer.server.port=9000"
      - "traefik.http.routers.portainer-secure.middlewares=secureHeaders@file"

networks:
  proxy:
    external: true
EOF
    
    # Create Traefik configuration file
    mkdir -p /opt/traefik/config
    cat > /opt/traefik/config/traefik.yml << EOF
api:
  dashboard: true

entryPoints:
  web:
    address: ":80"
    http:
      redirections:
        entryPoint:
          to: websecure
          scheme: https
  websecure:
    address: ":443"

providers:
  docker:
    endpoint: "unix:///var/run/docker.sock"
    exposedByDefault: false
    network: proxy
  file:
    directory: "/config"
    watch: true

certificatesResolvers:
  letsencrypt:
    acme:
      email: ${EMAIL}
      storage: /acme.json
      httpChallenge:
        entryPoint: web
EOF
    
    # Create Traefik dynamic configuration file
    mkdir -p /opt/traefik/config/dynamic
    cat > /opt/traefik/config/dynamic/config.yml << EOF
http:
  middlewares:
    secureHeaders:
      headers:
        sslRedirect: true
        forceSTSHeader: true
        stsIncludeSubdomains: true
        stsPreload: true
        stsSeconds: 31536000
EOF
    
    # Create acme.json file for Let's Encrypt certificates
    touch /opt/traefik/acme.json
    chmod 600 /opt/traefik/acme.json
    
    print_success "Docker Compose file created at /opt/docker/compose/docker-compose.yml"
    print_info "You can use this to deploy both Traefik and Portainer together"
    print_info "Run 'cd /opt/docker/compose && docker-compose up -d' to start the services"
}

# Function to create a sample service configuration
create_sample_service() {
    print_header "Creating Sample Service Configuration"
    
    # Create sample service docker-compose file
    cat > /opt/docker/compose/sample-service.yml << EOF
version: '3'

services:
  whoami:
    image: traefik/whoami
    container_name: whoami
    restart: unless-stopped
    networks:
      - proxy
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.whoami.rule=Host(\`whoami.example.com\`)"
      - "traefik.http.routers.whoami.entrypoints=websecure"
      - "traefik.http.routers.whoami.tls.certresolver=letsencrypt"
      - "traefik.http.services.whoami.loadbalancer.server.port=80"

networks:
  proxy:
    external: true
EOF
    
    print_success "Sample service configuration created at /opt/docker/compose/sample-service.yml"
    print_info "You can use this as a template for your own services"
    print_info "Remember to replace 'whoami.example.com' with your actual domain"
}

# Main function
main() {
    print_header "Portainer and Traefik Installation Script for Debian 12"
    
    # Check if running as root
    check_root
    
    # Remove old Docker installations
    remove_old_docker
    
    # Install Docker if needed
    install_docker
    
    # Install Docker Compose if needed
    install_docker_compose
    
    # Configure Docker post-installation
    configure_docker
    
    # Create necessary directories
    create_directories
    
    # Create Docker network
    create_docker_network
    
    # Ask if user wants to install services individually or using docker-compose
    if prompt_yes_no "Do you want to install Portainer and Traefik using Docker Compose? (Recommended)"; then
        # Create docker-compose.yml file
        create_docker_compose
        
        # Create sample service configuration
        create_sample_service
        
        # Ask if user wants to start the services now
        if prompt_yes_no "Do you want to start the services now?"; then
            print_info "Starting services..."
            cd /opt/docker/compose
            docker-compose up -d
            print_success "Services started"
        else
            print_info "Services not started"
            print_info "You can start them later with the following commands:"
            print_info "cd /opt/docker/compose && docker-compose up -d"
        fi
    else
        # Install Portainer
        install_portainer
        
        # Install Traefik
        install_traefik
    fi
    
    print_header "Installation Complete"
    print_success "Portainer and Traefik have been successfully installed"
    
    # Get server IP address
    SERVER_IP=$(hostname -I | awk '{print $1}')
    
    if docker ps --format '{{.Names}}' | grep -q "^portainer$"; then
        print_info "You can access Portainer at http://${SERVER_IP}:9000"
    fi
    
    if docker ps --format '{{.Names}}' | grep -q "^traefik$"; then
        print_info "You can access Traefik dashboard at http://${SERVER_IP}:8080"
    fi
    
    print_header "Next Steps"
    print_info "1. To run Docker commands without sudo, add your user to the docker group:"
    print_info "   sudo usermod -aG docker YOUR_USERNAME"
    print_info "   (Log out and log back in for this to take effect)"
    print_info "2. Configure your domain DNS to point to this server"
    print_info "3. Update the domain names in the docker-compose.yml file if needed"
    print_info "4. Use the sample service configuration as a template for your own services"
}

# Run main function
main
