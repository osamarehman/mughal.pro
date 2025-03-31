#!/bin/bash

# Cleanup script for Docker containers, networks, and volumes
# This script will remove all Docker containers, networks, and optionally volumes

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

# Function to stop all containers
stop_containers() {
    print_header "Stopping All Containers"
    
    # Get list of running containers
    RUNNING_CONTAINERS=$(docker ps -q)
    
    if [ -z "$RUNNING_CONTAINERS" ]; then
        print_info "No running containers found"
    else
        print_info "Stopping all running containers..."
        docker stop $(docker ps -q)
        print_success "All containers stopped"
    fi
}

# Function to remove all containers
remove_containers() {
    print_header "Removing All Containers"
    
    # Get list of all containers
    ALL_CONTAINERS=$(docker ps -a -q)
    
    if [ -z "$ALL_CONTAINERS" ]; then
        print_info "No containers found"
    else
        print_info "Removing all containers..."
        docker rm -f $(docker ps -a -q)
        print_success "All containers removed"
    fi
}

# Function to remove all networks
remove_networks() {
    print_header "Removing Docker Networks"
    
    # Get list of all networks (excluding default ones)
    NETWORKS=$(docker network ls --filter "type=custom" -q)
    
    if [ -z "$NETWORKS" ]; then
        print_info "No custom networks found"
    else
        print_info "Removing all custom networks..."
        for NETWORK in $NETWORKS; do
            docker network rm $NETWORK 2>/dev/null || true
        done
        print_success "All custom networks removed"
    fi
}

# Function to remove all volumes
remove_volumes() {
    print_header "Removing Docker Volumes"
    
    # Get list of all volumes
    VOLUMES=$(docker volume ls -q)
    
    if [ -z "$VOLUMES" ]; then
        print_info "No volumes found"
    else
        print_info "Removing all volumes..."
        docker volume rm $(docker volume ls -q)
        print_success "All volumes removed"
    fi
}

# Main function
main() {
    print_header "Docker Cleanup Script"
    print_info "This script will clean up your Docker environment"
    
    print_warning "This will stop and remove all Docker containers and networks"
    read -p "Do you want to continue? [y/N]: " CONTINUE
    if [[ ! "$CONTINUE" =~ ^[Yy]$ ]]; then
        print_info "Cleanup aborted"
        exit 0
    fi
    
    # Stop all containers
    stop_containers
    
    # Remove all containers
    remove_containers
    
    # Remove all networks
    remove_networks
    
    print_warning "CAUTION: Removing volumes will DELETE ALL DATA stored in Docker volumes"
    read -p "Do you want to remove all volumes? [y/N]: " REMOVE_VOLUMES
    if [[ "$REMOVE_VOLUMES" =~ ^[Yy]$ ]]; then
        remove_volumes
    else
        print_info "Skipping volume removal"
    fi
    
    print_header "Cleanup Complete"
    print_success "Your Docker environment has been cleaned up"
    print_info "You can now run your setup script again"
}

# Run main function
main
