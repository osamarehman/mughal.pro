#!/bin/bash

# Script to fix ownCloud container issues

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
    print_header "ownCloud Container Fix Script"
    print_info "This script will fix issues with the ownCloud container"
    
    # Check if ownCloud container exists
    if ! docker ps -a | grep -q owncloud; then
        print_error "ownCloud container not found"
        exit 1
    fi
    
    # Get ownCloud logs to identify the issue
    print_info "Checking ownCloud logs for errors..."
    docker logs owncloud 2>&1 | tail -n 100 > owncloud_logs.txt
    
    # Check for common errors in ownCloud logs
    if grep -q "permission denied" owncloud_logs.txt; then
        print_warning "ownCloud has permission issues"
        print_info "Fixing ownCloud permissions..."
        
        # Fix permissions for ownCloud data directory
        if [ -d "/opt/docker/data/owncloud" ]; then
            print_info "Fixing permissions for ownCloud data directory..."
            sudo chown -R 1000:1000 /opt/docker/data/owncloud
            print_success "ownCloud data directory permissions fixed"
        fi
    fi
    
    # Check for database connection issues
    if grep -q "could not connect to server: Connection refused" owncloud_logs.txt || grep -q "SQLSTATE" owncloud_logs.txt; then
        print_warning "ownCloud has database connection issues"
        print_info "Checking if MariaDB/MySQL container is running..."
        
        # Check if MariaDB is running
        if docker ps | grep -q mariadb; then
            print_info "MariaDB container is running"
            print_info "Checking if ownCloud is on the same network as MariaDB..."
            
            # Get the networks for ownCloud and MariaDB
            owncloud_networks=$(docker inspect --format '{{range $key, $value := .NetworkSettings.Networks}}{{$key}} {{end}}' owncloud)
            mariadb_networks=$(docker inspect --format '{{range $key, $value := .NetworkSettings.Networks}}{{$key}} {{end}}' mariadb)
            
            print_info "ownCloud networks: $owncloud_networks"
            print_info "MariaDB networks: $mariadb_networks"
            
            # Check if they share a network
            shared_network=false
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
                mariadb_network=$(echo $mariadb_networks | awk '{print $1}')
                
                # Connect ownCloud to MariaDB's network
                docker network connect $mariadb_network owncloud
                
                if [ $? -eq 0 ]; then
                    print_success "ownCloud connected to MariaDB's network: $mariadb_network"
                else
                    print_error "Failed to connect ownCloud to MariaDB's network"
                fi
            fi
        elif docker ps | grep -q mysql; then
            print_info "MySQL container is running"
            print_info "Checking if ownCloud is on the same network as MySQL..."
            
            # Get the networks for ownCloud and MySQL
            owncloud_networks=$(docker inspect --format '{{range $key, $value := .NetworkSettings.Networks}}{{$key}} {{end}}' owncloud)
            mysql_networks=$(docker inspect --format '{{range $key, $value := .NetworkSettings.Networks}}{{$key}} {{end}}' mysql)
            
            print_info "ownCloud networks: $owncloud_networks"
            print_info "MySQL networks: $mysql_networks"
            
            # Check if they share a network
            shared_network=false
            for network in $owncloud_networks; do
                if [[ $mysql_networks == *"$network"* ]]; then
                    shared_network=true
                    print_info "ownCloud and MySQL share network: $network"
                    break
                fi
            done
            
            if [ "$shared_network" = false ]; then
                print_warning "ownCloud and MySQL do not share a network"
                print_info "Connecting ownCloud to MySQL's network..."
                
                # Get the first network of MySQL
                mysql_network=$(echo $mysql_networks | awk '{print $1}')
                
                # Connect ownCloud to MySQL's network
                docker network connect $mysql_network owncloud
                
                if [ $? -eq 0 ]; then
                    print_success "ownCloud connected to MySQL's network: $mysql_network"
                else
                    print_error "Failed to connect ownCloud to MySQL's network"
                fi
            fi
        else
            print_error "Neither MariaDB nor MySQL container is running"
            print_info "Please make sure a database container is running before starting ownCloud"
            
            # Check if PostgreSQL is running as an alternative
            if docker ps | grep -q postgres; then
                print_info "PostgreSQL container is running"
                print_info "Checking if ownCloud is on the same network as PostgreSQL..."
                
                # Get the networks for ownCloud and PostgreSQL
                owncloud_networks=$(docker inspect --format '{{range $key, $value := .NetworkSettings.Networks}}{{$key}} {{end}}' owncloud)
                postgres_networks=$(docker inspect --format '{{range $key, $value := .NetworkSettings.Networks}}{{$key}} {{end}}' postgres)
                
                print_info "ownCloud networks: $owncloud_networks"
                print_info "PostgreSQL networks: $postgres_networks"
                
                # Check if they share a network
                shared_network=false
                for network in $owncloud_networks; do
                    if [[ $postgres_networks == *"$network"* ]]; then
                        shared_network=true
                        print_info "ownCloud and PostgreSQL share network: $network"
                        break
                    fi
                done
                
                if [ "$shared_network" = false ]; then
                    print_warning "ownCloud and PostgreSQL do not share a network"
                    print_info "Connecting ownCloud to PostgreSQL's network..."
                    
                    # Get the first network of PostgreSQL
                    postgres_network=$(echo $postgres_networks | awk '{print $1}')
                    
                    # Connect ownCloud to PostgreSQL's network
                    docker network connect $postgres_network owncloud
                    
                    if [ $? -eq 0 ]; then
                        print_success "ownCloud connected to PostgreSQL's network: $postgres_network"
                    else
                        print_error "Failed to connect ownCloud to PostgreSQL's network"
                    fi
                fi
            fi
        fi
    fi
    
    # Check for environment variables
    print_header "Checking ownCloud Environment Variables"
    
    # Get ownCloud environment variables
    owncloud_env=$(docker inspect --format '{{range .Config.Env}}{{.}} {{end}}' owncloud)
    
    # Check if database environment variables are set
    if [[ $owncloud_env != *"OWNCLOUD_DB_"* ]]; then
        print_warning "ownCloud database environment variables are not set"
        print_info "Recreating ownCloud container with proper environment variables..."
        
        # Get the current network
        network=$(docker inspect --format '{{range $key, $value := .NetworkSettings.Networks}}{{$key}}{{end}}' owncloud 2>/dev/null || echo "compose_proxy")
        
        # Stop and remove the ownCloud container
        docker stop owncloud
        docker rm owncloud
        
        # Create a new ownCloud container with proper environment variables
        docker run -d \
            --name owncloud \
            --network $network \
            --restart unless-stopped \
            -e OWNCLOUD_DB_TYPE=mysql \
            -e OWNCLOUD_DB_NAME=owncloud \
            -e OWNCLOUD_DB_USERNAME=owncloud \
            -e OWNCLOUD_DB_PASSWORD=owncloud \
            -e OWNCLOUD_DB_HOST=mariadb \
            -e OWNCLOUD_ADMIN_USERNAME=admin \
            -e OWNCLOUD_ADMIN_PASSWORD=admin \
            -e OWNCLOUD_MYSQL_UTF8MB4=true \
            -e OWNCLOUD_REDIS_ENABLED=false \
            -v /opt/docker/data/owncloud:/mnt/data \
            owncloud/server:latest
        
        if [ $? -eq 0 ]; then
            print_success "ownCloud container recreated with proper environment variables"
        else
            print_error "Failed to recreate ownCloud container"
            print_info "Please check Docker logs for more information"
        fi
    fi
    
    # Check for Redis connection issues
    if grep -q "Redis connection failed" owncloud_logs.txt; then
        print_warning "ownCloud has Redis connection issues"
        print_info "Checking if Redis container is running..."
        
        # Check if Redis is running
        if docker ps | grep -q redis; then
            print_info "Redis container is running"
            print_info "Checking if ownCloud is on the same network as Redis..."
            
            # Get the networks for ownCloud and Redis
            owncloud_networks=$(docker inspect --format '{{range $key, $value := .NetworkSettings.Networks}}{{$key}} {{end}}' owncloud)
            redis_networks=$(docker inspect --format '{{range $key, $value := .NetworkSettings.Networks}}{{$key}} {{end}}' redis)
            
            print_info "ownCloud networks: $owncloud_networks"
            print_info "Redis networks: $redis_networks"
            
            # Check if they share a network
            shared_network=false
            for network in $owncloud_networks; do
                if [[ $redis_networks == *"$network"* ]]; then
                    shared_network=true
                    print_info "ownCloud and Redis share network: $network"
                    break
                fi
            done
            
            if [ "$shared_network" = false ]; then
                print_warning "ownCloud and Redis do not share a network"
                print_info "Connecting ownCloud to Redis's network..."
                
                # Get the first network of Redis
                redis_network=$(echo $redis_networks | awk '{print $1}')
                
                # Connect ownCloud to Redis's network
                docker network connect $redis_network owncloud
                
                if [ $? -eq 0 ]; then
                    print_success "ownCloud connected to Redis's network: $redis_network"
                else
                    print_error "Failed to connect ownCloud to Redis's network"
                fi
            fi
        else
            print_warning "Redis container is not running"
            print_info "Disabling Redis for ownCloud..."
            
            # Get the current network
            network=$(docker inspect --format '{{range $key, $value := .NetworkSettings.Networks}}{{$key}}{{end}}' owncloud 2>/dev/null || echo "compose_proxy")
            
            # Stop and remove the ownCloud container
            docker stop owncloud
            docker rm owncloud
            
            # Create a new ownCloud container with Redis disabled
            docker run -d \
                --name owncloud \
                --network $network \
                --restart unless-stopped \
                -e OWNCLOUD_DB_TYPE=mysql \
                -e OWNCLOUD_DB_NAME=owncloud \
                -e OWNCLOUD_DB_USERNAME=owncloud \
                -e OWNCLOUD_DB_PASSWORD=owncloud \
                -e OWNCLOUD_DB_HOST=mariadb \
                -e OWNCLOUD_ADMIN_USERNAME=admin \
                -e OWNCLOUD_ADMIN_PASSWORD=admin \
                -e OWNCLOUD_MYSQL_UTF8MB4=true \
                -e OWNCLOUD_REDIS_ENABLED=false \
                -v /opt/docker/data/owncloud:/mnt/data \
                owncloud/server:latest
            
            if [ $? -eq 0 ]; then
                print_success "ownCloud container recreated with Redis disabled"
            else
                print_error "Failed to recreate ownCloud container"
                print_info "Please check Docker logs for more information"
            fi
        fi
    fi
    
    # Restart the ownCloud container
    print_header "Restarting ownCloud Container"
    print_info "Restarting ownCloud container..."
    docker restart owncloud
    
    if [ $? -eq 0 ]; then
        print_success "ownCloud container restarted"
    else
        print_error "Failed to restart ownCloud container"
    fi
    
    # Check ownCloud container status
    print_header "Checking ownCloud Container Status"
    
    # Wait a few seconds for the container to start
    print_info "Waiting for ownCloud container to start..."
    sleep 5
    
    # Check if ownCloud is running
    if docker ps | grep -q owncloud; then
        print_success "ownCloud container is running"
    else
        print_error "ownCloud container is not running"
        print_info "Checking ownCloud container status..."
        
        # Get ownCloud container status
        status=$(docker inspect --format "{{.State.Status}}" owncloud)
        
        if [ "$status" = "restarting" ]; then
            print_warning "ownCloud container is restarting"
            print_info "This may indicate an ongoing issue"
            print_info "Check the logs for more information: docker logs owncloud"
        else
            print_info "ownCloud container status: $status"
        fi
    fi
    
    print_header "Next Steps"
    print_info "1. Check ownCloud logs for any remaining issues:"
    print_info "   docker logs owncloud"
    print_info "2. If issues persist, consider running the cleanup script:"
    print_info "   sudo ./cleanup-docker.sh"
    print_info "3. Then run the setup script again to recreate all containers:"
    print_info "   sudo ./setup.sh"
    print_info "4. For more troubleshooting options, see troubleshooting_checklist.md"
}

# Run main function
main
