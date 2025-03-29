#!/bin/bash

# Server Setup Services Script
# This script contains functions for setting up the services

# Function to prompt for services to enable
prompt_services() {
    print_header "Services"
    
    # Initialize service flags
    ENABLE_MARIADB=false
    ENABLE_POSTGRES=false
    ENABLE_REDIS=false
    ENABLE_VAULTWARDEN=false
    ENABLE_GRAFANA=false
    ENABLE_PROMETHEUS=false
    ENABLE_DOCMOST=false
    ENABLE_CODE_SERVER=false
    ENABLE_HOMEASSISTANT=false
    ENABLE_OWNCLOUD=false
    ENABLE_PORTAINER=false
    ENABLE_ITTOOLS=false
    ENABLE_LOKI=false
    ENABLE_BORGMATIC=false
    ENABLE_WIREGUARD=false
    
    # Prompt for each service
    if prompt_yes_no "Enable MariaDB (MySQL database)?"; then
        ENABLE_MARIADB=true
        print_info "MariaDB enabled"
    fi
    
    if prompt_yes_no "Enable PostgreSQL database?"; then
        ENABLE_POSTGRES=true
        print_info "PostgreSQL enabled"
    fi
    
    if prompt_yes_no "Enable Redis (cache)?"; then
        ENABLE_REDIS=true
        print_info "Redis enabled"
    fi
    
    if prompt_yes_no "Enable Vaultwarden (password manager)?"; then
        ENABLE_VAULTWARDEN=true
        print_info "Vaultwarden enabled"
    fi
    
    if prompt_yes_no "Enable Grafana (monitoring dashboard)?"; then
        ENABLE_GRAFANA=true
        print_info "Grafana enabled"
    fi
    
    if prompt_yes_no "Enable Prometheus (monitoring system)?"; then
        ENABLE_PROMETHEUS=true
        print_info "Prometheus enabled"
    fi
    
    if prompt_yes_no "Enable DocMost (documentation)?"; then
        ENABLE_DOCMOST=true
        print_info "DocMost enabled"
        
        # DocMost requires PostgreSQL and Redis
        if ! $ENABLE_POSTGRES; then
            print_warning "DocMost requires PostgreSQL. Enabling PostgreSQL."
            ENABLE_POSTGRES=true
        fi
        
        if ! $ENABLE_REDIS; then
            print_warning "DocMost requires Redis. Enabling Redis."
            ENABLE_REDIS=true
        fi
    fi
    
    if prompt_yes_no "Enable Code Server (VS Code in browser)?"; then
        ENABLE_CODE_SERVER=true
        print_info "Code Server enabled"
    fi
    
    if prompt_yes_no "Enable Home Assistant (home automation)?"; then
        ENABLE_HOMEASSISTANT=true
        print_info "Home Assistant enabled"
    fi
    
    if prompt_yes_no "Enable OwnCloud (file storage)?"; then
        ENABLE_OWNCLOUD=true
        print_info "OwnCloud enabled"
        
        # OwnCloud requires MariaDB
        if ! $ENABLE_MARIADB; then
            print_warning "OwnCloud requires MariaDB. Enabling MariaDB."
            ENABLE_MARIADB=true
        fi
    fi
    
    if prompt_yes_no "Enable Portainer (Docker management)?"; then
        ENABLE_PORTAINER=true
        print_info "Portainer enabled"
    fi
    
    if prompt_yes_no "Enable IT Tools (collection of IT tools)?"; then
        ENABLE_ITTOOLS=true
        print_info "IT Tools enabled"
    fi
    
    if prompt_yes_no "Enable Loki (log aggregation)?"; then
        ENABLE_LOKI=true
        print_info "Loki enabled"
    fi
    
    if prompt_yes_no "Enable Borgmatic (backups)?"; then
        ENABLE_BORGMATIC=true
        print_info "Borgmatic enabled"
    fi
    
    if prompt_yes_no "Enable WireGuard (VPN)?"; then
        ENABLE_WIREGUARD=true
        print_info "WireGuard enabled"
    fi
}

# Function to prompt for resource limits
prompt_resource_limits() {
    print_header "Resource Limits"
    
    # Initialize resource limits arrays
    declare -A MEMORY_LIMITS
    declare -A CPU_LIMITS
    
    # Prompt for resource limits for each service
    if prompt_yes_no "Do you want to set resource limits for services?"; then
        prompt_service_limits "caddy"
        prompt_service_limits "authelia"
        
        if $ENABLE_MARIADB; then
            prompt_service_limits "mariadb"
        fi
        
        if $ENABLE_POSTGRES; then
            prompt_service_limits "postgres"
        fi
        
        if $ENABLE_REDIS; then
            prompt_service_limits "redis"
        fi
        
        if $ENABLE_VAULTWARDEN; then
            prompt_service_limits "vaultwarden"
        fi
        
        if $ENABLE_GRAFANA; then
            prompt_service_limits "grafana"
        fi
        
        if $ENABLE_PROMETHEUS; then
            prompt_service_limits "prometheus"
        fi
        
        if $ENABLE_DOCMOST; then
            prompt_service_limits "docmost"
        fi
        
        if $ENABLE_CODE_SERVER; then
            prompt_service_limits "code-server"
        fi
        
        if $ENABLE_HOMEASSISTANT; then
            prompt_service_limits "homeassistant"
        fi
        
        if $ENABLE_OWNCLOUD; then
            prompt_service_limits "owncloud"
        fi
        
        if $ENABLE_PORTAINER; then
            prompt_service_limits "portainer"
        fi
        
        if $ENABLE_ITTOOLS; then
            prompt_service_limits "ittools"
        fi
        
        if $ENABLE_LOKI; then
            prompt_service_limits "loki"
        fi
        
        if $ENABLE_BORGMATIC; then
            prompt_service_limits "borgmatic"
        fi
        
        if $ENABLE_WIREGUARD; then
            prompt_service_limits "wireguard"
        fi
    fi
}

# Function to prompt for resource limits for a specific service
prompt_service_limits() {
    local service=$1
    local memory_limit
    local cpu_limit
    
    if prompt_yes_no "Do you want to set resource limits for $service?"; then
        read -p "Enter memory limit for $service (e.g., 512m, 1g): " memory_limit
        read -p "Enter CPU limit for $service (e.g., 0.5, 1): " cpu_limit
        
        MEMORY_LIMITS[$service]=$memory_limit
        CPU_LIMITS[$service]=$cpu_limit
        
        print_info "Resource limits set for $service: Memory: $memory_limit, CPU: $cpu_limit"
    fi
}

# Function to generate Docker Compose file
generate_docker_compose() {
    local output_file=$1
    local domain=$2
    
    # Create docker-compose.yml
    cat > "$output_file" << EOF
version: '3.8'

services:
  # Caddy reverse proxy
  caddy:
    image: caddy:2
    container_name: caddy
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - $DATA_DIR/caddy/config/Caddyfile:/etc/caddy/Caddyfile:ro
      - $DATA_DIR/caddy/data:/data
      - $DATA_DIR/caddy/site:/srv
    environment:
      - TZ=$TIMEZONE
    networks:
      - proxy
EOF
    
    # Add resource limits if set
    if [ -n "${MEMORY_LIMITS[caddy]}" ] || [ -n "${CPU_LIMITS[caddy]}" ]; then
        cat >> "$output_file" << EOF
    deploy:
      resources:
        limits:
EOF
        
        if [ -n "${MEMORY_LIMITS[caddy]}" ]; then
            cat >> "$output_file" << EOF
          memory: ${MEMORY_LIMITS[caddy]}
EOF
        fi
        
        if [ -n "${CPU_LIMITS[caddy]}" ]; then
            cat >> "$output_file" << EOF
          cpus: ${CPU_LIMITS[caddy]}
EOF
        fi
    fi
    
    # Add Authelia
    cat >> "$output_file" << EOF
  
  # Authelia authentication server
  authelia:
    image: authelia/authelia:latest
    container_name: authelia
    restart: unless-stopped
    volumes:
      - $DATA_DIR/authelia/config:/config
    environment:
      - TZ=$TIMEZONE
    networks:
      - proxy
EOF
    
    # Add resource limits if set
    if [ -n "${MEMORY_LIMITS[authelia]}" ] || [ -n "${CPU_LIMITS[authelia]}" ]; then
        cat >> "$output_file" << EOF
    deploy:
      resources:
        limits:
EOF
        
        if [ -n "${MEMORY_LIMITS[authelia]}" ]; then
            cat >> "$output_file" << EOF
          memory: ${MEMORY_LIMITS[authelia]}
EOF
        fi
        
        if [ -n "${CPU_LIMITS[authelia]}" ]; then
            cat >> "$output_file" << EOF
          cpus: ${CPU_LIMITS[authelia]}
EOF
        fi
    fi
    
    # Add MariaDB if enabled
    if $ENABLE_MARIADB; then
        cat >> "$output_file" << EOF
  
  # MariaDB database
  mariadb:
    image: mariadb:10.6
    container_name: mariadb
    restart: unless-stopped
    volumes:
      - $DATA_DIR/mariadb/data:/var/lib/mysql
      - $DATA_DIR/mariadb/config:/etc/mysql/conf.d
    environment:
      - MYSQL_ROOT_PASSWORD=\${MARIADB_ROOT_PASSWORD}
      - MYSQL_USER=\${MARIADB_USER}
      - MYSQL_PASSWORD=\${MARIADB_PASSWORD}
      - MYSQL_DATABASE=\${MARIADB_DATABASE}
      - TZ=$TIMEZONE
    networks:
      - backend
EOF
        
        # Add resource limits if set
        if [ -n "${MEMORY_LIMITS[mariadb]}" ] || [ -n "${CPU_LIMITS[mariadb]}" ]; then
            cat >> "$output_file" << EOF
    deploy:
      resources:
        limits:
EOF
            
            if [ -n "${MEMORY_LIMITS[mariadb]}" ]; then
                cat >> "$output_file" << EOF
          memory: ${MEMORY_LIMITS[mariadb]}
EOF
            fi
            
            if [ -n "${CPU_LIMITS[mariadb]}" ]; then
                cat >> "$output_file" << EOF
          cpus: ${CPU_LIMITS[mariadb]}
EOF
            fi
        fi
    fi
    
    # Add PostgreSQL if enabled
    if $ENABLE_POSTGRES; then
        cat >> "$output_file" << EOF
  
  # PostgreSQL database
  postgres:
    image: postgres:14
    container_name: postgres
    restart: unless-stopped
    volumes:
      - $DATA_DIR/postgres/data:/var/lib/postgresql/data
    environment:
      - POSTGRES_USER=\${POSTGRES_USER}
      - POSTGRES_PASSWORD=\${POSTGRES_PASSWORD}
      - POSTGRES_DB=\${POSTGRES_DB}
      - TZ=$TIMEZONE
    networks:
      - backend
EOF
        
        # Add resource limits if set
        if [ -n "${MEMORY_LIMITS[postgres]}" ] || [ -n "${CPU_LIMITS[postgres]}" ]; then
            cat >> "$output_file" << EOF
    deploy:
      resources:
        limits:
EOF
            
            if [ -n "${MEMORY_LIMITS[postgres]}" ]; then
                cat >> "$output_file" << EOF
          memory: ${MEMORY_LIMITS[postgres]}
EOF
            fi
            
            if [ -n "${CPU_LIMITS[postgres]}" ]; then
                cat >> "$output_file" << EOF
          cpus: ${CPU_LIMITS[postgres]}
EOF
            fi
        fi
    fi
    
    # Add Redis if enabled
    if $ENABLE_REDIS; then
        cat >> "$output_file" << EOF
  
  # Redis cache
  redis:
    image: redis:6
    container_name: redis
    restart: unless-stopped
    volumes:
      - $DATA_DIR/redis/data:/data
      - $DATA_DIR/redis/redis.conf:/usr/local/etc/redis/redis.conf
    command: ["redis-server", "/usr/local/etc/redis/redis.conf"]
    environment:
      - TZ=$TIMEZONE
    networks:
      - backend
EOF
        
        # Add resource limits if set
        if [ -n "${MEMORY_LIMITS[redis]}" ] || [ -n "${CPU_LIMITS[redis]}" ]; then
            cat >> "$output_file" << EOF
    deploy:
      resources:
        limits:
EOF
            
            if [ -n "${MEMORY_LIMITS[redis]}" ]; then
                cat >> "$output_file" << EOF
          memory: ${MEMORY_LIMITS[redis]}
EOF
            fi
            
            if [ -n "${CPU_LIMITS[redis]}" ]; then
                cat >> "$output_file" << EOF
          cpus: ${CPU_LIMITS[redis]}
EOF
            fi
        fi
    fi
    
    # Add Vaultwarden if enabled
    if $ENABLE_VAULTWARDEN; then
        cat >> "$output_file" << EOF
  
  # Vaultwarden password manager
  vaultwarden:
    image: vaultwarden/server:latest
    container_name: vaultwarden
    restart: unless-stopped
    volumes:
      - $DATA_DIR/vaultwarden/data:/data
    environment:
      - ADMIN_TOKEN=\${VAULTWARDEN_HASHED_TOKEN}
      - DOMAIN=https://vault.$domain
      - SIGNUPS_ALLOWED=false
      - TZ=$TIMEZONE
    networks:
      - proxy
EOF
        
        # Add resource limits if set
        if [ -n "${MEMORY_LIMITS[vaultwarden]}" ] || [ -n "${CPU_LIMITS[vaultwarden]}" ]; then
            cat >> "$output_file" << EOF
    deploy:
      resources:
        limits:
EOF
            
            if [ -n "${MEMORY_LIMITS[vaultwarden]}" ]; then
                cat >> "$output_file" << EOF
          memory: ${MEMORY_LIMITS[vaultwarden]}
EOF
            fi
            
            if [ -n "${CPU_LIMITS[vaultwarden]}" ]; then
                cat >> "$output_file" << EOF
          cpus: ${CPU_LIMITS[vaultwarden]}
EOF
            fi
        fi
    fi
    
    # Add Grafana if enabled
    if $ENABLE_GRAFANA; then
        cat >> "$output_file" << EOF
  
  # Grafana monitoring dashboard
  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    restart: unless-stopped
    volumes:
      - $DATA_DIR/grafana/data:/var/lib/grafana
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=\${GF_SECURITY_ADMIN_PASSWORD}
      - GF_USERS_ALLOW_SIGN_UP=false
      - GF_SERVER_ROOT_URL=https://grafana.$domain
      - TZ=$TIMEZONE
    networks:
      - proxy
      - monitoring
EOF
        
        # Add resource limits if set
        if [ -n "${MEMORY_LIMITS[grafana]}" ] || [ -n "${CPU_LIMITS[grafana]}" ]; then
            cat >> "$output_file" << EOF
    deploy:
      resources:
        limits:
EOF
            
            if [ -n "${MEMORY_LIMITS[grafana]}" ]; then
                cat >> "$output_file" << EOF
          memory: ${MEMORY_LIMITS[grafana]}
EOF
            fi
            
            if [ -n "${CPU_LIMITS[grafana]}" ]; then
                cat >> "$output_file" << EOF
          cpus: ${CPU_LIMITS[grafana]}
EOF
            fi
        fi
    fi
    
    # Add Prometheus if enabled
    if $ENABLE_PROMETHEUS; then
        cat >> "$output_file" << EOF
  
  # Prometheus monitoring system
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    restart: unless-stopped
    volumes:
      - $DATA_DIR/prometheus/config:/etc/prometheus
      - $DATA_DIR/prometheus/data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/usr/share/prometheus/console_libraries'
      - '--web.console.templates=/usr/share/prometheus/consoles'
    environment:
      - TZ=$TIMEZONE
    networks:
      - proxy
      - monitoring
EOF
        
        # Add resource limits if set
        if [ -n "${MEMORY_LIMITS[prometheus]}" ] || [ -n "${CPU_LIMITS[prometheus]}" ]; then
            cat >> "$output_file" << EOF
    deploy:
      resources:
        limits:
EOF
            
            if [ -n "${MEMORY_LIMITS[prometheus]}" ]; then
                cat >> "$output_file" << EOF
          memory: ${MEMORY_LIMITS[prometheus]}
EOF
            fi
            
            if [ -n "${CPU_LIMITS[prometheus]}" ]; then
                cat >> "$output_file" << EOF
          cpus: ${CPU_LIMITS[prometheus]}
EOF
            fi
        fi
        
        # Add Node Exporter
        cat >> "$output_file" << EOF
  
  # Node Exporter for system metrics
  node-exporter:
    image: prom/node-exporter:latest
    container_name: node-exporter
    restart: unless-stopped
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - '--path.procfs=/host/proc'
      - '--path.sysfs=/host/sys'
      - '--path.rootfs=/rootfs'
      - '--collector.filesystem.ignored-mount-points=^/(sys|proc|dev|host|etc)($$|/)'
    environment:
      - TZ=$TIMEZONE
    networks:
      - monitoring
EOF
    fi
    
    # Add DocMost if enabled
    if $ENABLE_DOCMOST; then
        cat >> "$output_file" << EOF
  
  # DocMost documentation
  docmost:
    image: docmost/docmost:latest
    container_name: docmost
    restart: unless-stopped
    volumes:
      - $DATA_DIR/docmost/data:/app/data
    environment:
      - APP_SECRET=\${APP_SECRET}
      - DATABASE_URL=\${POSTGRES_URL}
      - REDIS_URL=\${REDIS_URL}
      - TZ=$TIMEZONE
    depends_on:
      - postgres
      - redis
    networks:
      - proxy
      - backend
EOF
        
        # Add resource limits if set
        if [ -n "${MEMORY_LIMITS[docmost]}" ] || [ -n "${CPU_LIMITS[docmost]}" ]; then
            cat >> "$output_file" << EOF
    deploy:
      resources:
        limits:
EOF
            
            if [ -n "${MEMORY_LIMITS[docmost]}" ]; then
                cat >> "$output_file" << EOF
          memory: ${MEMORY_LIMITS[docmost]}
EOF
            fi
            
            if [ -n "${CPU_LIMITS[docmost]}" ]; then
                cat >> "$output_file" << EOF
          cpus: ${CPU_LIMITS[docmost]}
EOF
            fi
        fi
    fi
    
    # Add Code Server if enabled
    if $ENABLE_CODE_SERVER; then
        cat >> "$output_file" << EOF
  
  # Code Server (VS Code in browser)
  code-server:
    image: codercom/code-server:latest
    container_name: code-server
    restart: unless-stopped
    volumes:
      - $DATA_DIR/code-server/config:/home/coder/.config
      - $DATA_DIR/code-server/data:/home/coder/project
    environment:
      - PASSWORD=\${ADMIN_PASSWORD}
      - TZ=$TIMEZONE
    networks:
      - proxy
EOF
        
        # Add resource limits if set
        if [ -n "${MEMORY_LIMITS[code-server]}" ] || [ -n "${CPU_LIMITS[code-server]}" ]; then
            cat >> "$output_file" << EOF
    deploy:
      resources:
        limits:
EOF
            
            if [ -n "${MEMORY_LIMITS[code-server]}" ]; then
                cat >> "$output_file" << EOF
          memory: ${MEMORY_LIMITS[code-server]}
EOF
            fi
            
            if [ -n "${CPU_LIMITS[code-server]}" ]; then
                cat >> "$output_file" << EOF
          cpus: ${CPU_LIMITS[code-server]}
EOF
            fi
        fi
    fi
    
    # Add Home Assistant if enabled
    if $ENABLE_HOMEASSISTANT; then
        cat >> "$output_file" << EOF
  
  # Home Assistant home automation
  homeassistant:
    image: homeassistant/home-assistant:stable
    container_name: homeassistant
    restart: unless-stopped
    volumes:
      - $DATA_DIR/homeassistant/config:/config
      - /etc/localtime:/etc/localtime:ro
    environment:
      - TZ=$TIMEZONE
    networks:
      - proxy
EOF
        
        # Add resource limits if set
        if [ -n "${MEMORY_LIMITS[homeassistant]}" ] || [ -n "${CPU_LIMITS[homeassistant]}" ]; then
            cat >> "$output_file" << EOF
    deploy:
      resources:
        limits:
EOF
            
            if [ -n "${MEMORY_LIMITS[homeassistant]}" ]; then
                cat >> "$output_file" << EOF
          memory: ${MEMORY_LIMITS[homeassistant]}
EOF
            fi
            
            if [ -n "${CPU_LIMITS[homeassistant]}" ]; then
                cat >> "$output_file" << EOF
          cpus: ${CPU_LIMITS[homeassistant]}
EOF
            fi
        fi
    fi
    
    # Add OwnCloud if enabled
    if $ENABLE_OWNCLOUD; then
        cat >> "$output_file" << EOF
  
  # OwnCloud file storage
  owncloud:
    image: owncloud/server:latest
    container_name: owncloud
    restart: unless-stopped
    volumes:
      - $DATA_DIR/owncloud/data:/mnt/data
    environment:
      - OWNCLOUD_DOMAIN=cloud.$domain
      - OWNCLOUD_DB_TYPE=mysql
      - OWNCLOUD_DB_NAME=\${MARIADB_DATABASE}
      - OWNCLOUD_DB_USERNAME=\${MARIADB_USER}
      - OWNCLOUD_DB_PASSWORD=\${MARIADB_PASSWORD}
      - OWNCLOUD_DB_HOST=mariadb
      - OWNCLOUD_ADMIN_USERNAME=admin
      - OWNCLOUD_ADMIN_PASSWORD=\${ADMIN_PASSWORD}
      - TZ=$TIMEZONE
    depends_on:
      - mariadb
    networks:
      - proxy
      - backend
EOF
        
        # Add resource limits if set
        if [ -n "${MEMORY_LIMITS[owncloud]}" ] || [ -n "${CPU_LIMITS[owncloud]}" ]; then
            cat >> "$output_file" << EOF
    deploy:
      resources:
        limits:
EOF
            
            if [ -n "${MEMORY_LIMITS[owncloud]}" ]; then
                cat >> "$output_file" << EOF
          memory: ${MEMORY_LIMITS[owncloud]}
EOF
            fi
            
            if [ -n "${CPU_LIMITS[owncloud]}" ]; then
                cat >> "$output_file" << EOF
          cpus: ${CPU_LIMITS[owncloud]}
EOF
            fi
        fi
    fi
    
    # Add Portainer if enabled
    if $ENABLE_PORTAINER; then
        cat >> "$output_file" << EOF
  
  # Portainer Docker management
  portainer:
    image: portainer/portainer-ce:latest
    container_name: portainer
    restart: unless-stopped
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - $DATA_DIR/portainer/data:/data
    environment:
      - TZ=$TIMEZONE
    networks:
      - proxy
EOF
        
        # Add resource limits if set
        if [ -n "${MEMORY_LIMITS[portainer]}" ] || [ -n "${CPU_LIMITS[portainer]}" ]; then
            cat >> "$output_file" << EOF
    deploy:
      resources:
        limits:
EOF
            
            if [ -n "${MEMORY_LIMITS[portainer]}" ]; then
                cat >> "$output_file" << EOF
          memory: ${MEMORY_LIMITS[portainer]}
EOF
            fi
            
            if [ -n "${CPU_LIMITS[portainer]}" ]; then
                cat >> "$output_file" << EOF
          cpus: ${CPU_LIMITS[portainer]}
EOF
            fi
        fi
    fi
    
    # Add IT Tools if enabled
    if $ENABLE_ITTOOLS; then
        cat >> "$output_file" << EOF
  
  # IT Tools collection
  ittools:
    image: corentinth/it-tools:latest
    container_name: ittools
    restart: unless-stopped
    environment:
      - TZ=$TIMEZONE
    networks:
      - proxy
EOF
        
        # Add resource limits if set
        if [ -n "${MEMORY_LIMITS[ittools]}" ] || [ -n "${CPU_LIMITS[ittools]}" ]; then
            cat >> "$output_file" << EOF
    deploy:
      resources:
        limits:
EOF
            
            if [ -n "${MEMORY_LIMITS[ittools]}" ]; then
                cat >> "$output_file" << EOF
          memory: ${MEMORY_LIMITS[ittools]}
EOF
            fi
            
            if [ -n "${CPU_LIMITS[ittools]}" ]; then
                cat >> "$output_file" << EOF
          cpus: ${CPU_LIMITS[ittools]}
EOF
            fi
        fi
    fi
    
    # Add Loki if enabled
    if $ENABLE_LOKI; then
        cat >> "$output_file" << EOF
  
  # Loki log aggregation
  loki:
    image: grafana/loki:latest
    container_name: loki
    restart: unless-stopped
    volumes:
      - $DATA_DIR/loki/config:/etc/loki
      - $DATA_DIR/loki/data:/loki
    command: -config.file=/etc/loki/loki-config.yaml
    environment:
      - TZ=$TIMEZONE
    networks:
      - monitoring
EOF
        
        # Add resource limits if set
        if [ -n "${MEMORY_LIMITS[loki]}" ] || [ -n "${CPU_LIMITS[loki]}" ]; then
            cat >> "$output_file" << EOF
    deploy:
      resources:
        limits:
EOF
            
            if [ -n "${MEMORY_LIMITS[loki]}" ]; then
                cat >> "$output_file" << EOF
          memory: ${MEMORY_LIMITS[loki]}
EOF
            fi
            
            if [ -n "${CPU_LIMITS[loki]}" ]; then
                cat >> "$output_file" << EOF
          cpus: ${CPU_LIMITS[loki]}
EOF
            fi
        fi
        
        # Add Promtail
        cat >> "$output_file" << EOF
  
  # Promtail log collector
  promtail:
    image: grafana/promtail:latest
    container_name: promtail
    restart: unless-stopped
    volumes:
      - /var/log:/var/log
      - $DATA_DIR/loki/config:/etc/promtail
    command: -config.file=/etc/promtail/promtail-config.yaml
    environment:
      - TZ=$TIMEZONE
    networks:
      - monitoring
EOF
    fi
    
    # Add Borgmatic if enabled
    if $ENABLE_BORGMATIC; then
        cat >> "$output_file" << EOF
  
  # Borgmatic backup
  borgmatic:
    image: b3vis/borgmatic:latest
    container_name: borgmatic
    restart: unless-stopped
    volumes:
      - $DATA_DIR:/backup/data
      - $BACKUP_DIR:/backup/repository
      - $DATA_DIR/borgmatic/config:/etc/borgmatic.d
      - $DATA_DIR/borgmatic/config/scripts:/scripts
    environment:
      - TZ=$TIMEZONE
      - MARIADB_ROOT_PASSWORD=\${MARIADB_ROOT_PASSWORD}
      - POSTGRES_USER=\${POSTGRES_USER}
      - POSTGRES_PASSWORD=\${POSTGRES_PASSWORD}
    networks:
      - backend
EOF
        
        # Add resource limits if set
        if [ -n "${MEMORY_LIMITS[borgmatic]}" ] || [ -n "${CPU_LIMITS[borgmatic]}" ]; then
            cat >> "$output_file" << EOF
    deploy:
      resources:
        limits:
EOF
            
            if [ -n "${MEMORY_LIMITS[borgmatic]}" ]; then
                cat >> "$output_file" << EOF
          memory: ${MEMORY_LIMITS[borgmatic]}
EOF
            fi
            
            if [ -n "${CPU_LIMITS[borgmatic]}" ]; then
                cat >> "$output_file" << EOF
          cpus: ${CPU_LIMITS[borgmatic]}
EOF
            fi
        fi
    fi
    
    # Add WireGuard if enabled
    if $ENABLE_WIREGUARD; then
        cat >> "$output_file" << EOF
  
  # WireGuard VPN
  wireguard:
    image: linuxserver/wireguard:latest
    container_name: wireguard
    restart: unless-stopped
    cap_add:
      - NET_ADMIN
      - SYS_MODULE
    volumes:
      - $DATA_DIR/wireguard/config:/config
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=$TIMEZONE
      - SERVERURL=\${SERVERURL}
      - SERVERPORT=\${SERVERPORT}
      - PEERS=\${PEERS}
      - PEERDNS=\${PEERDNS}
      - INTERNAL_SUBNET=\${INTERNAL_SUBNET}
    ports:
      - "\${SERVERPORT}:\${SERVERPORT}/udp"
    sysctls:
      - net.ipv4.conf.all.src_valid_mark=1
EOF
        
        # Add resource limits if set
        if [ -n "${MEMORY_LIMITS[wireguard]}" ] || [ -n "${CPU_LIMITS[wireguard]}" ]; then
            cat >> "$output_file" << EOF
    deploy:
      resources:
        limits:
EOF
            
            if [ -n "${MEMORY_LIMITS[wireguard]}" ]; then
                cat >> "$output_file" << EOF
          memory: ${MEMORY_LIMITS[wireguard]}
EOF
            fi
            
            if [ -n "${CPU_LIMITS[wireguard]}" ]; then
                cat >> "$output_file" << EOF
          cpus: ${CPU_LIMITS[wireguard]}
EOF
            fi
        fi
    fi
    
    # Add networks
    cat >> "$output_file" << EOF

networks:
  proxy:
    driver: bridge
  backend:
    driver: bridge
  monitoring:
    driver: bridge
EOF
    
    print_success "Docker Compose file generated at $output_file"
}

# Function to generate .env file
generate_env_file() {
    local output_file=$1
    
    # Create .env file
    cat > "$output_file" << EOF
# Environment variables for Docker Compose
# Generated on $(date)

# Domain
DOMAIN="$DOMAIN"
EMAIL="$EMAIL"

# Timezone
TZ=$TIMEZONE

# Authelia
JWT_SECRET="$JWT_SECRET"

# MariaDB
EOF
    
    # Add MariaDB variables if enabled
    if $ENABLE_MARIADB; then
        cat >> "$output_file" << EOF
MARIADB_ROOT_PASSWORD="$MARIADB_ROOT_PASSWORD"
MARIADB_USER="$MARIADB_USER"
MARIADB_PASSWORD="$MARIADB_PASSWORD"
MARIADB_DATABASE="$MARIADB_DATABASE"
EOF
    fi
    
    # Add PostgreSQL variables if enabled
    if $ENABLE_POSTGRES; then
        cat >> "$output_file" << EOF

# PostgreSQL
POSTGRES_USER="$POSTGRES_USER"
POSTGRES_PASSWORD="$POSTGRES_PASSWORD"
POSTGRES_DB="$POSTGRES_DB"
EOF
    fi
    
    # Add Vaultwarden variables if enabled
    if $ENABLE_VAULTWARDEN; then
        cat >> "$output_file" << EOF

# Vaultwarden
VAULTWARDEN_HASHED_TOKEN=$VAULTWARDEN_HASHED_TOKEN
EOF
    fi
    
    # Add Grafana variables if enabled
    if $ENABLE_GRAFANA; then
        cat >> "$output_file" << EOF

# Grafana
GF_SECURITY_ADMIN_PASSWORD=$GF_SECURITY_ADMIN_PASSWORD
EOF
    fi
    
    # Add DocMost variables if enabled
    if $ENABLE_DOCMOST; then
        # Escape special characters in URLs by quoting them
        local escaped_postgres_url="\"$POSTGRES_URL\""
        local escaped_redis_url="\"$REDIS_URL\""
        
        cat >> "$output_file" << EOF

# DocMost
APP_SECRET=$APP_SECRET
POSTGRES_URL=$escaped_postgres_url
REDIS_URL=$escaped_redis_url
EOF
    fi
    
    # Add Code Server variables if enabled
    if $ENABLE_CODE_SERVER; then
        cat >> "$output_file" << EOF

# Code Server
ADMIN_PASSWORD=$ADMIN_PASSWORD
EOF
    fi
    
    # Add WireGuard variables if enabled
    if $ENABLE_WIREGUARD; then
        cat >> "$output_file" << EOF

# WireGuard
SERVERURL=$SERVERURL
SERVERPORT=$SERVERPORT
PEERS=$PEERS
PEERDNS=$PEERDNS
INTERNAL_SUBNET=$INTERNAL_SUBNET
EOF
    fi
    
    print_success ".env file generated at $output_file"
}

# Function to start services
start_services() {
    print_header "Starting Services"
    
    if prompt_yes_no "Do you want to start the services now?"; then
        cd "$DATA_DIR/compose"
        docker-compose pull
        docker-compose up -d
        
        print_success "Services started"
        
        # Print DNS information
        print_header "DNS Information"
        cat "$DATA_DIR/dns_info.txt"
        
        print_header "Setup Complete"
        print_info "Your server has been set up successfully"
        print_info "You can access your services at https://$DOMAIN"
        print_info "Credentials have been saved to $DATA_DIR/credentials.txt"
        print_info "DNS information has been saved to $DATA_DIR/dns_info.txt"
        print_info "Make sure to configure your DNS records as described in the DNS information"
    else
        print_info "Services not started"
        print_info "You can start them later with the following commands:"
        echo "cd $DATA_DIR/compose"
        echo "docker-compose pull"
        echo "docker-compose up -d"
        
        print_header "Setup Complete"
        print_info "Your server has been set up successfully"
        print_info "Credentials have been saved to $DATA_DIR/credentials.txt"
        print_info "DNS information has been saved to $DATA_DIR/dns_info.txt"
        print_info "Make sure to configure your DNS records as described in the DNS information"
    fi
}
