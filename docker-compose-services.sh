#!/bin/bash

# Docker Compose Services Script
# This script generates the Docker Compose file based on the services selected by the user
# It is meant to be sourced by the main setup.sh script

# Function to generate Docker Compose file
generate_docker_compose() {
    local output_file=$1
    local domain=$2
    
    # Start with the version and networks
    cat > "$output_file" << EOF
version: '3.8'

services:
EOF
    
    # Add Caddy service
    cat >> "$output_file" << EOF
  caddy:
    image: caddy:latest
    container_name: caddy
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ${DATA_DIR}/caddy/config/Caddyfile:/etc/caddy/Caddyfile
      - ${DATA_DIR}/caddy/data:/data
      - ${DATA_DIR}/caddy/config:/config
      - ${DATA_DIR}/caddy/site:/srv
    environment:
      - TZ=${TIMEZONE}
    healthcheck:
      test: ["CMD", "caddy", "version"]
      interval: 10s
      timeout: 5s
      retries: 5
EOF
    
    # Add resource limits if specified
    if [[ -n "${MEMORY_LIMITS[caddy]}" ]]; then
        cat >> "$output_file" << EOF
    deploy:
      resources:
        limits:
          memory: ${MEMORY_LIMITS[caddy]}
          cpus: ${CPU_LIMITS[caddy]}
EOF
    fi
    
    # Add networks
    cat >> "$output_file" << EOF
    networks:
      - frontend
EOF
    
    # Add Authelia service
    cat >> "$output_file" << EOF

  authelia:
    image: authelia/authelia:latest
    container_name: authelia
    restart: unless-stopped
    volumes:
      - ${DATA_DIR}/authelia/config:/config
    environment:
      - TZ=${TIMEZONE}
    healthcheck:
      test: ["CMD-SHELL", "wget --no-verbose --tries=1 --spider http://localhost:9091/api/health || exit 1"]
      interval: 10s
      timeout: 5s
      retries: 5
EOF
    
    # Add resource limits if specified
    if [[ -n "${MEMORY_LIMITS[authelia]}" ]]; then
        cat >> "$output_file" << EOF
    deploy:
      resources:
        limits:
          memory: ${MEMORY_LIMITS[authelia]}
          cpus: ${CPU_LIMITS[authelia]}
EOF
    fi
    
    # Add networks
    cat >> "$output_file" << EOF
    networks:
      - frontend
      - backend
EOF
    
    # Add MariaDB service if enabled
    if $ENABLE_MARIADB; then
        cat >> "$output_file" << EOF

  mariadb:
    image: mariadb:latest
    container_name: mariadb
    restart: unless-stopped
    environment:
      - MYSQL_ROOT_PASSWORD=${MARIADB_ROOT_PASSWORD}
      - MYSQL_DATABASE=${MARIADB_DATABASE}
      - MYSQL_USER=${MARIADB_USER}
      - MYSQL_PASSWORD=${MARIADB_PASSWORD}
      - TZ=${TIMEZONE}
    volumes:
      - ${DATA_DIR}/mariadb/data:/var/lib/mysql
      - ${DATA_DIR}/mariadb/config/custom.cnf:/etc/mysql/conf.d/custom.cnf
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-u", "root", "-p${MARIADB_ROOT_PASSWORD}"]
      interval: 10s
      timeout: 5s
      retries: 5
EOF
        
        # Add resource limits if specified
        if [[ -n "${MEMORY_LIMITS[mariadb]}" ]]; then
            cat >> "$output_file" << EOF
    deploy:
      resources:
        limits:
          memory: ${MEMORY_LIMITS[mariadb]}
          cpus: ${CPU_LIMITS[mariadb]}
EOF
        fi
        
        # Add networks
        cat >> "$output_file" << EOF
    networks:
      - backend
EOF
    fi
    
    # Add PostgreSQL service if enabled
    if $ENABLE_POSTGRES; then
        cat >> "$output_file" << EOF

  postgres:
    image: postgres:latest
    container_name: postgres
    restart: unless-stopped
    environment:
      - POSTGRES_USER=${POSTGRES_USER}
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
      - POSTGRES_DB=${POSTGRES_DB}
      - TZ=${TIMEZONE}
    volumes:
      - ${DATA_DIR}/postgres/data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"]
      interval: 10s
      timeout: 5s
      retries: 5
EOF
        
        # Add resource limits if specified
        if [[ -n "${MEMORY_LIMITS[postgres]}" ]]; then
            cat >> "$output_file" << EOF
    deploy:
      resources:
        limits:
          memory: ${MEMORY_LIMITS[postgres]}
          cpus: ${CPU_LIMITS[postgres]}
EOF
        fi
        
        # Add networks
        cat >> "$output_file" << EOF
    networks:
      - backend
EOF
    fi
    
    # Add Redis service if enabled
    if $ENABLE_REDIS; then
        cat >> "$output_file" << EOF

  redis:
    image: redis:latest
    container_name: redis
    restart: unless-stopped
    volumes:
      - ${DATA_DIR}/redis/data:/data
      - ${DATA_DIR}/redis/redis.conf:/usr/local/etc/redis/redis.conf
    command: redis-server /usr/local/etc/redis/redis.conf
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5
EOF
        
        # Add resource limits if specified
        if [[ -n "${MEMORY_LIMITS[redis]}" ]]; then
            cat >> "$output_file" << EOF
    deploy:
      resources:
        limits:
          memory: ${MEMORY_LIMITS[redis]}
          cpus: ${CPU_LIMITS[redis]}
EOF
        fi
        
        # Add networks
        cat >> "$output_file" << EOF
    networks:
      - backend
EOF
    fi
    
    # Add Vaultwarden service if enabled
    if $ENABLE_VAULTWARDEN; then
        cat >> "$output_file" << EOF

  vaultwarden:
    image: vaultwarden/server:latest
    container_name: vaultwarden
    restart: unless-stopped
    environment:
      - ADMIN_TOKEN=${VAULTWARDEN_HASHED_TOKEN}
      - TZ=${TIMEZONE}
    volumes:
      - ${DATA_DIR}/vaultwarden/data:/data
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:80/alive"]
      interval: 10s
      timeout: 5s
      retries: 5
EOF
        
        # Add resource limits if specified
        if [[ -n "${MEMORY_LIMITS[vaultwarden]}" ]]; then
            cat >> "$output_file" << EOF
    deploy:
      resources:
        limits:
          memory: ${MEMORY_LIMITS[vaultwarden]}
          cpus: ${CPU_LIMITS[vaultwarden]}
EOF
        fi
        
        # Add networks
        cat >> "$output_file" << EOF
    networks:
      - frontend
      - backend
EOF
    fi
    
    # Add Grafana service if enabled
    if $ENABLE_GRAFANA; then
        cat >> "$output_file" << EOF

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    restart: unless-stopped
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=${GF_SECURITY_ADMIN_PASSWORD}
      - TZ=${TIMEZONE}
    volumes:
      - ${DATA_DIR}/grafana/data:/var/lib/grafana
    healthcheck:
      test: ["CMD-SHELL", "wget --no-verbose --tries=1 --spider http://localhost:3000/api/health || exit 1"]
      interval: 10s
      timeout: 5s
      retries: 5
EOF
        
        # Add resource limits if specified
        if [[ -n "${MEMORY_LIMITS[grafana]}" ]]; then
            cat >> "$output_file" << EOF
    deploy:
      resources:
        limits:
          memory: ${MEMORY_LIMITS[grafana]}
          cpus: ${CPU_LIMITS[grafana]}
EOF
        fi
        
        # Add networks
        cat >> "$output_file" << EOF
    networks:
      - frontend
      - backend
EOF
    fi
    
    # Add Prometheus service if enabled
    if $ENABLE_PROMETHEUS; then
        cat >> "$output_file" << EOF

  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    restart: unless-stopped
    volumes:
      - ${DATA_DIR}/prometheus/config/prometheus.yml:/etc/prometheus/prometheus.yml
      - ${DATA_DIR}/prometheus/data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'
      - '--web.enable-lifecycle'
    healthcheck:
      test: ["CMD-SHELL", "wget --no-verbose --tries=1 --spider http://localhost:9090/-/healthy || exit 1"]
      interval: 10s
      timeout: 5s
      retries: 5
EOF
        
        # Add resource limits if specified
        if [[ -n "${MEMORY_LIMITS[prometheus]}" ]]; then
            cat >> "$output_file" << EOF
    deploy:
      resources:
        limits:
          memory: ${MEMORY_LIMITS[prometheus]}
          cpus: ${CPU_LIMITS[prometheus]}
EOF
        fi
        
        # Add networks
        cat >> "$output_file" << EOF
    networks:
      - backend
EOF
    fi
    
    # Add DocMost service if enabled
    if $ENABLE_DOCMOST; then
        cat >> "$output_file" << EOF

  docmost:
    image: docmost/docmost:latest
    container_name: docmost
    restart: unless-stopped
    environment:
      - DATABASE_URL=${POSTGRES_URL}
      - REDIS_URL=${REDIS_URL}
      - APP_SECRET=${APP_SECRET}
      - TZ=${TIMEZONE}
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    healthcheck:
      test: ["CMD-SHELL", "wget --no-verbose --tries=1 --spider http://localhost:3000/api/health || exit 1"]
      interval: 15s
      timeout: 5s
      retries: 3
EOF
        
        # Add resource limits if specified
        if [[ -n "${MEMORY_LIMITS[docmost]}" ]]; then
            cat >> "$output_file" << EOF
    deploy:
      resources:
        limits:
          memory: ${MEMORY_LIMITS[docmost]}
          cpus: ${CPU_LIMITS[docmost]}
EOF
        fi
        
        # Add networks
        cat >> "$output_file" << EOF
    networks:
      - frontend
      - backend
EOF
    fi
    
    # Add Code Server service if enabled
    if $ENABLE_CODE_SERVER; then
        cat >> "$output_file" << EOF

  code-server:
    image: codercom/code-server:latest
    container_name: code-server
    restart: unless-stopped
    environment:
      - PASSWORD=${USER_PASSWORD}
      - TZ=${TIMEZONE}
    volumes:
      - ${DATA_DIR}/code-server/config:/home/coder/.config
      - ${DATA_DIR}/code-server/data:/home/coder/project
    healthcheck:
      test: ["CMD-SHELL", "wget --no-verbose --tries=1 --spider http://localhost:8080/healthz || exit 1"]
      interval: 10s
      timeout: 5s
      retries: 5
EOF
        
        # Add resource limits if specified
        if [[ -n "${MEMORY_LIMITS[code-server]}" ]]; then
            cat >> "$output_file" << EOF
    deploy:
      resources:
        limits:
          memory: ${MEMORY_LIMITS[code-server]}
          cpus: ${CPU_LIMITS[code-server]}
EOF
        fi
        
        # Add networks
        cat >> "$output_file" << EOF
    networks:
      - frontend
EOF
    fi
    
    # Add Home Assistant service if enabled
    if $ENABLE_HOMEASSISTANT; then
        cat >> "$output_file" << EOF

  homeassistant:
    image: homeassistant/home-assistant:latest
    container_name: homeassistant
    restart: unless-stopped
    environment:
      - TZ=${TIMEZONE}
    volumes:
      - ${DATA_DIR}/homeassistant/config:/config
    healthcheck:
      test: ["CMD-SHELL", "wget --no-verbose --tries=1 --spider http://localhost:8123 || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3
EOF
        
        # Add resource limits if specified
        if [[ -n "${MEMORY_LIMITS[homeassistant]}" ]]; then
            cat >> "$output_file" << EOF
    deploy:
      resources:
        limits:
          memory: ${MEMORY_LIMITS[homeassistant]}
          cpus: ${CPU_LIMITS[homeassistant]}
EOF
        fi
        
        # Add networks
        cat >> "$output_file" << EOF
    networks:
      - frontend
      - backend
EOF
    fi
    
    # Add OwnCloud service if enabled
    if $ENABLE_OWNCLOUD; then
        cat >> "$output_file" << EOF

  owncloud:
    image: owncloud/server:latest
    container_name: owncloud
    restart: unless-stopped
    environment:
      - OWNCLOUD_DOMAIN=cloud.${domain}
      - OWNCLOUD_DB_TYPE=mysql
      - OWNCLOUD_DB_NAME=${MARIADB_DATABASE}
      - OWNCLOUD_DB_USERNAME=${MARIADB_USER}
      - OWNCLOUD_DB_PASSWORD=${MARIADB_PASSWORD}
      - OWNCLOUD_DB_HOST=mariadb
      - OWNCLOUD_ADMIN_USERNAME=admin
      - OWNCLOUD_ADMIN_PASSWORD=${ADMIN_PASSWORD}
      - TZ=${TIMEZONE}
    volumes:
      - ${DATA_DIR}/owncloud/data:/mnt/data
    depends_on:
      mariadb:
        condition: service_healthy
    healthcheck:
      test: ["CMD-SHELL", "wget --no-verbose --tries=1 --spider http://localhost:8080/status.php || exit 1"]
      interval: 20s
      timeout: 10s
      retries: 3
EOF
        
        # Add resource limits if specified
        if [[ -n "${MEMORY_LIMITS[owncloud]}" ]]; then
            cat >> "$output_file" << EOF
    deploy:
      resources:
        limits:
          memory: ${MEMORY_LIMITS[owncloud]}
          cpus: ${CPU_LIMITS[owncloud]}
EOF
        fi
        
        # Add networks
        cat >> "$output_file" << EOF
    networks:
      - frontend
      - backend
EOF
    fi
    
    # Add Portainer service if enabled
    if $ENABLE_PORTAINER; then
        cat >> "$output_file" << EOF

  portainer:
    image: portainer/portainer-ce:latest
    container_name: portainer
    restart: unless-stopped
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ${DATA_DIR}/portainer/data:/data
    healthcheck:
      test: ["CMD-SHELL", "wget --no-verbose --tries=1 --spider http://localhost:9000/api/status || exit 1"]
      interval: 10s
      timeout: 5s
      retries: 5
EOF
        
        # Add resource limits if specified
        if [[ -n "${MEMORY_LIMITS[portainer]}" ]]; then
            cat >> "$output_file" << EOF
    deploy:
      resources:
        limits:
          memory: ${MEMORY_LIMITS[portainer]}
          cpus: ${CPU_LIMITS[portainer]}
EOF
        fi
        
        # Add networks
        cat >> "$output_file" << EOF
    networks:
      - frontend
EOF
    fi
    
    # Add IT Tools service if enabled
    if $ENABLE_ITTOOLS; then
        cat >> "$output_file" << EOF

  ittools:
    image: corentinth/it-tools:latest
    container_name: ittools
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "wget --no-verbose --tries=1 --spider http://localhost:80/ || exit 1"]
      interval: 10s
      timeout: 5s
      retries: 5
EOF
        
        # Add resource limits if specified
        if [[ -n "${MEMORY_LIMITS[ittools]}" ]]; then
            cat >> "$output_file" << EOF
    deploy:
      resources:
        limits:
          memory: ${MEMORY_LIMITS[ittools]}
          cpus: ${CPU_LIMITS[ittools]}
EOF
        fi
        
        # Add networks
        cat >> "$output_file" << EOF
    networks:
      - frontend
EOF
    fi
    
    # Add Loki service if enabled
    if $ENABLE_LOKI; then
        cat >> "$output_file" << EOF

  loki:
    image: grafana/loki:latest
    container_name: loki
    restart: unless-stopped
    volumes:
      - ${DATA_DIR}/loki/config/loki-config.yaml:/etc/loki/local-config.yaml
      - ${DATA_DIR}/loki/data:/loki
    command: -config.file=/etc/loki/local-config.yaml
    healthcheck:
      test: ["CMD-SHELL", "wget --no-verbose --tries=1 --spider http://localhost:3100/ready || exit 1"]
      interval: 10s
      timeout: 5s
      retries: 5
EOF
        
        # Add resource limits if specified
        if [[ -n "${MEMORY_LIMITS[loki]}" ]]; then
            cat >> "$output_file" << EOF
    deploy:
      resources:
        limits:
          memory: ${MEMORY_LIMITS[loki]}
          cpus: ${CPU_LIMITS[loki]}
EOF
        fi
        
        # Add networks
        cat >> "$output_file" << EOF
    networks:
      - backend
EOF
    fi
    
    # Add Borgmatic service if enabled
    if $ENABLE_BORGMATIC; then
        cat >> "$output_file" << EOF

  borgmatic:
    image: b3vis/borgmatic:latest
    container_name: borgmatic
    restart: unless-stopped
    environment:
      - TZ=${TIMEZONE}
      - BORG_PASSPHRASE=change_this_to_a_strong_passphrase
      - MARIADB_ROOT_PASSWORD=${MARIADB_ROOT_PASSWORD}
      - POSTGRES_USER=${POSTGRES_USER}
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
    volumes:
      - ${DATA_DIR}/borgmatic/config:/etc/borgmatic.d
      - ${DATA_DIR}/borgmatic/config/scripts:/scripts
      - ${BACKUP_DIR}:/backup
    healthcheck:
      test: ["CMD-SHELL", "borgmatic --version || exit 1"]
      interval: 60s
      timeout: 10s
      retries: 3
EOF
        
        # Add resource limits if specified
        if [[ -n "${MEMORY_LIMITS[borgmatic]}" ]]; then
            cat >> "$output_file" << EOF
    deploy:
      resources:
        limits:
          memory: ${MEMORY_LIMITS[borgmatic]}
          cpus: ${CPU_LIMITS[borgmatic]}
EOF
        fi
        
        # Add networks
        cat >> "$output_file" << EOF
    networks:
      - backend
EOF
    fi
    
    # Add WireGuard service if enabled
    if $ENABLE_WIREGUARD; then
        cat >> "$output_file" << EOF

  wireguard:
    image: linuxserver/wireguard:latest
    container_name: wireguard
    restart: unless-stopped
    cap_add:
      - NET_ADMIN
      - SYS_MODULE
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=${TIMEZONE}
      - SERVERURL=${SERVERURL}
      - SERVERPORT=${SERVERPORT}
      - PEERS=${PEERS}
      - PEERDNS=1.1.1.1,1.0.0.1  # Explicit Cloudflare DNS for reliability
      - INTERNAL_SUBNET=${INTERNAL_SUBNET}
    volumes:
      - ${DATA_DIR}/wireguard/config:/config
    ports:
      - "${SERVERPORT}:${SERVERPORT}/udp"
    sysctls:
      - net.ipv4.conf.all.src_valid_mark=1
    healthcheck:
      test: ["CMD-SHELL", "ip addr show wg0 || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3
EOF
        
        # Add resource limits if specified
        if [[ -n "${MEMORY_LIMITS[wireguard]}" ]]; then
            cat >> "$output_file" << EOF
    deploy:
      resources:
        limits:
          memory: ${MEMORY_LIMITS[wireguard]}
          cpus: ${CPU_LIMITS[wireguard]}
EOF
        fi
        
        # Add networks
        cat >> "$output_file" << EOF
    networks:
      - frontend
EOF
    fi
    
    # Add networks section
    cat >> "$output_file" << EOF

networks:
  frontend:
  backend:
EOF
    
    print_success "Docker Compose file created at $output_file"
}

# Function to generate .env file for Docker Compose
generate_env_file() {
    local output_file=$1
    
    cat > "$output_file" << EOF
# Docker Compose Environment Variables
# Generated on $(date)

# --- BASIC CONFIGURATION ---
# Domain name for all services
DOMAIN=${DOMAIN}

# Timezone setting for containers
TZ=${TIMEZONE}

# --- PATH CONFIGURATIONS ---
# Base directory for all Docker data
DATA_DIR=${DATA_DIR}

# Directory for backups
BACKUP_DIR=${BACKUP_DIR}

# --- DATABASE CONFIGURATION ---
# MariaDB settings [SECURITY CRITICAL]
MARIADB_ROOT_PASSWORD=${MARIADB_ROOT_PASSWORD:-CHANGE_THIS_IMMEDIATELY}
MARIADB_USER=${MARIADB_USER:-dbuser}
MARIADB_PASSWORD=${MARIADB_PASSWORD:-CHANGE_THIS_IMMEDIATELY}
MARIADB_DATABASE=${MARIADB_DATABASE:-appdb}

# PostgreSQL settings [SECURITY CRITICAL]
POSTGRES_USER=${POSTGRES_USER:-pguser}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-CHANGE_THIS_IMMEDIATELY}
POSTGRES_DB=${POSTGRES_DB:-appdb}

# --- AUTHENTICATION ---
# Vaultwarden admin token (hashed)
ADMIN_TOKEN=${VAULTWARDEN_HASHED_TOKEN:-CHANGE_THIS_IMMEDIATELY}

# Grafana admin password
GF_SECURITY_ADMIN_PASSWORD=${GF_SECURITY_ADMIN_PASSWORD:-CHANGE_THIS_IMMEDIATELY}

# DocMost configuration
DATABASE_URL=${POSTGRES_URL:-postgresql://pguser:CHANGE_THIS_IMMEDIATELY@postgres:5432/appdb}
REDIS_URL=${REDIS_URL:-redis://redis:6379}
APP_SECRET=${APP_SECRET:-CHANGE_THIS_IMMEDIATELY}

# --- WIREGUARD CONFIGURATION ---
SERVERURL=${SERVERURL:-auto}
SERVERPORT=${SERVERPORT:-51820}
PEERS=${PEERS:-3}
PEERDNS=${PEERDNS:-1.1.1.1,1.0.0.1}
INTERNAL_SUBNET=${INTERNAL_SUBNET:-10.13.13.0/24}

# --- SERVICE ENABLEMENT FLAGS ---
# Set to true/false to enable/disable services
ENABLE_MARIADB=${ENABLE_MARIADB:-false}
ENABLE_POSTGRES=${ENABLE_POSTGRES:-false}
ENABLE_REDIS=${ENABLE_REDIS:-false}
ENABLE_VAULTWARDEN=${ENABLE_VAULTWARDEN:-false}
ENABLE_GRAFANA=${ENABLE_GRAFANA:-false}
ENABLE_PROMETHEUS=${ENABLE_PROMETHEUS:-false}
ENABLE_DOCMOST=${ENABLE_DOCMOST:-false}
ENABLE_CODE_SERVER=${ENABLE_CODE_SERVER:-false}
ENABLE_HOMEASSISTANT=${ENABLE_HOMEASSISTANT:-false}
ENABLE_OWNCLOUD=${ENABLE_OWNCLOUD:-false}
ENABLE_PORTAINER=${ENABLE_PORTAINER:-false}
ENABLE_ITTOOLS=${ENABLE_ITTOOLS:-false}
ENABLE_LOKI=${ENABLE_LOKI:-false}
ENABLE_BORGMATIC=${ENABLE_BORGMATIC:-false}
ENABLE_WIREGUARD=${ENABLE_WIREGUARD:-false}

# --- RESOURCE LIMITS ---
# Memory and CPU limits for each service
# Memory format: 256m, 1g, etc.
# CPU format: 0.5, 1, 2, etc.
EOF

    # Add resource limits if defined
    for service in caddy authelia mariadb postgres redis vaultwarden grafana prometheus docmost code-server homeassistant owncloud portainer ittools loki borgmatic wireguard; do
        if [[ -n "${MEMORY_LIMITS[$service]}" ]]; then
            cat >> "$output_file" << EOF
MEMORY_LIMIT_${service}=${MEMORY_LIMITS[$service]}
CPU_LIMIT_${service}=${CPU_LIMITS[$service]}
EOF
        fi
    done
    
    print_success "Environment file created at $output_file"
}
