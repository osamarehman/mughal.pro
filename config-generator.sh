#!/bin/bash

# Configuration Generator Script
# This script generates configuration files for each service
# It is meant to be sourced by the main setup.sh script

# Function to generate Caddy configuration
generate_caddy_config() {
    local config_dir=$1
    local domain=$2
    local email=$3
    
    # Create Caddyfile
    cat > "$config_dir/Caddyfile" << EOF
# Global options
{
    email $email
    # Global server options
    servers {
        protocol {
            experimental_http3
        }
    }
}

# Main domain
$domain {
    root * /srv
    file_server
    # Add rate limiting to prevent abuse
    rate_limit {
        max_requests 10
        window 1s
    }
    # Add security headers
    header {
        Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
        X-Content-Type-Options "nosniff"
        X-Frame-Options "DENY"
        Referrer-Policy "strict-origin-when-cross-origin"
        X-XSS-Protection "1; mode=block"
    }
    # Enable logging
    log {
        output file /data/logs/access.log {
            roll_size 10MB
            roll_keep 10
        }
    }
}

# Authelia service
auth.$domain {
    reverse_proxy authelia:9091
    # Add rate limiting for authentication
    rate_limit {
        max_requests 5
        window 10s
    }
}
EOF
    
    # Add service-specific configurations
    if $ENABLE_VAULTWARDEN; then
        cat >> "$config_dir/Caddyfile" << EOF

# Vaultwarden
vaultwarden.$domain {
    # Forward authentication to Authelia
    forward_auth auth.$domain {
        uri /api/verify?rd=https://auth.$domain
        copy_headers Remote-User Remote-Groups Remote-Name Remote-Email
    }
    reverse_proxy vaultwarden:80
}
EOF
    fi
    
    if $ENABLE_GRAFANA; then
        cat >> "$config_dir/Caddyfile" << EOF

# Grafana
grafana.$domain {
    # Forward authentication to Authelia
    forward_auth auth.$domain {
        uri /api/verify?rd=https://auth.$domain
        copy_headers Remote-User Remote-Groups Remote-Name Remote-Email
    }
    reverse_proxy grafana:3000
}
EOF
    fi
    
    if $ENABLE_PROMETHEUS; then
        cat >> "$config_dir/Caddyfile" << EOF

# Prometheus
prometheus.$domain {
    # Forward authentication to Authelia
    forward_auth auth.$domain {
        uri /api/verify?rd=https://auth.$domain
        copy_headers Remote-User Remote-Groups Remote-Name Remote-Email
    }
    reverse_proxy prometheus:9090
}
EOF
    fi
    
    if $ENABLE_DOCMOST; then
        cat >> "$config_dir/Caddyfile" << EOF

# DocMost
docs.$domain {
    # Forward authentication to Authelia
    forward_auth auth.$domain {
        uri /api/verify?rd=https://auth.$domain
        copy_headers Remote-User Remote-Groups Remote-Name Remote-Email
    }
    reverse_proxy docmost:3000
}
EOF
    fi
    
    if $ENABLE_CODE_SERVER; then
        cat >> "$config_dir/Caddyfile" << EOF

# Code Server
code.$domain {
    # Forward authentication to Authelia
    forward_auth auth.$domain {
        uri /api/verify?rd=https://auth.$domain
        copy_headers Remote-User Remote-Groups Remote-Name Remote-Email
    }
    reverse_proxy code-server:8080
}
EOF
    fi
    
    if $ENABLE_HOMEASSISTANT; then
        cat >> "$config_dir/Caddyfile" << EOF

# Home Assistant
home.$domain {
    # Forward authentication to Authelia
    forward_auth auth.$domain {
        uri /api/verify?rd=https://auth.$domain
        copy_headers Remote-User Remote-Groups Remote-Name Remote-Email
    }
    reverse_proxy homeassistant:8123
}
EOF
    fi
    
    if $ENABLE_OWNCLOUD; then
        cat >> "$config_dir/Caddyfile" << EOF

# OwnCloud
cloud.$domain {
    # Forward authentication to Authelia
    forward_auth auth.$domain {
        uri /api/verify?rd=https://auth.$domain
        copy_headers Remote-User Remote-Groups Remote-Name Remote-Email
    }
    reverse_proxy owncloud:8080
}
EOF
    fi
    
    if $ENABLE_PORTAINER; then
        cat >> "$config_dir/Caddyfile" << EOF

# Portainer
portainer.$domain {
    # Forward authentication to Authelia
    forward_auth auth.$domain {
        uri /api/verify?rd=https://auth.$domain
        copy_headers Remote-User Remote-Groups Remote-Name Remote-Email
    }
    reverse_proxy portainer:9000
}
EOF
    fi
    
    if $ENABLE_ITTOOLS; then
        cat >> "$config_dir/Caddyfile" << EOF

# IT Tools
tools.$domain {
    # Forward authentication to Authelia
    forward_auth auth.$domain {
        uri /api/verify?rd=https://auth.$domain
        copy_headers Remote-User Remote-Groups Remote-Name Remote-Email
    }
    reverse_proxy ittools:80
}
EOF
    fi
    
    if $ENABLE_WIREGUARD; then
        cat >> "$config_dir/Caddyfile" << EOF

# WireGuard
vpn.$domain {
    # Forward authentication to Authelia
    forward_auth auth.$domain {
        uri /api/verify?rd=https://auth.$domain
        copy_headers Remote-User Remote-Groups Remote-Name Remote-Email
    }
    reverse_proxy wireguard:51821
}
EOF
    fi
    
    print_success "Caddy configuration created at $config_dir/Caddyfile"
}

# Function to generate Authelia configuration
generate_authelia_config() {
    local config_dir=$1
    local domain=$2
    local jwt_secret=$3
    local admin_user=$4
    local admin_hash=$5
    local user_user=$6
    local user_hash=$7
    local email=$8
    
    # Create configuration.yml
    cat > "$config_dir/configuration.yml" << EOF
---
server:
  host: 0.0.0.0
  port: 9091

log:
  level: info

# JWT secret for session tokens
jwt_secret: ${jwt_secret}

# Default redirection URL
default_redirection_url: https://${domain}

# TOTP configuration
totp:
  issuer: ${domain}
  period: 30
  skew: 1

# Database configuration
storage:
  local:
    path: /config/db.sqlite3

# Authentication backend
authentication_backend:
  file:
    path: /config/users_database.yml
    password:
      algorithm: argon2id
      iterations: 1
      key_length: 32
      salt_length: 16
      memory: 1024
      parallelism: 8

# Access control rules
access_control:
  default_policy: deny
  rules:
    # Public access to main domain
    - domain: ${domain}
      policy: bypass
    
    # Require authentication for all subdomains
    - domain: "*.${domain}"
      policy: one_factor
      
    # Add specific rules for services that need higher security
    - domain: vaultwarden.${domain}
      policy: two_factor

# Session configuration
session:
  name: authelia_session
  domain: ${domain}
  same_site: lax
  expiration: 12h
  inactivity: 45m
  remember_me_duration: 1M
  local:
    path: /config/session.db

# Regulation configuration (brute force protection)
regulation:
  max_retries: 3
  find_time: 2m
  ban_time: 5m

# Notification configuration
notifier:
  filesystem:
    filename: /config/notification.txt
EOF
    
    # Create users_database.yml
    cat > "$config_dir/users_database.yml" << EOF
---
users:
  ${admin_user}:
    displayname: "Admin User"
    password: "${admin_hash}"
    email: ${email}
    groups:
      - admins
      - users
  
  ${user_user}:
    displayname: "Regular User"
    password: "${user_hash}"
    email: ${email}
    groups:
      - users
EOF
    
    print_success "Authelia configuration created at $config_dir/configuration.yml"
    print_success "Authelia users database created at $config_dir/users_database.yml"
}

# Function to generate MariaDB configuration
generate_mariadb_config() {
    local config_dir=$1
    
    # Create custom.cnf
    cat > "$config_dir/custom.cnf" << EOF
[mysqld]
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci
transaction_isolation = READ-COMMITTED
binlog_format = ROW
innodb_large_prefix = 1
innodb_file_format = Barracuda
innodb_file_per_table = 1
innodb_buffer_pool_size = 128M
max_allowed_packet = 128M
max_connections = 100
EOF
    
    print_success "MariaDB configuration created at $config_dir/custom.cnf"
}

# Function to generate Redis configuration
generate_redis_config() {
    local config_dir=$1
    
    # Create redis.conf
    cat > "$config_dir/redis.conf" << EOF
# Redis configuration file

# General
daemonize no
pidfile /var/run/redis/redis-server.pid
port 6379
tcp-backlog 511
timeout 0
tcp-keepalive 300

# Snapshotting
save 900 1
save 300 10
save 60 10000
stop-writes-on-bgsave-error yes
rdbcompression yes
rdbchecksum yes
dbfilename dump.rdb
dir /data

# Security
protected-mode yes

# Limits
maxclients 10000
maxmemory 256mb
maxmemory-policy allkeys-lru

# Append only mode
appendonly no
appendfilename "appendonly.aof"
appendfsync everysec
no-appendfsync-on-rewrite no
auto-aof-rewrite-percentage 100
auto-aof-rewrite-min-size 64mb
aof-load-truncated yes
aof-use-rdb-preamble yes

# Lua scripting
lua-time-limit 5000

# Slow log
slowlog-log-slower-than 10000
slowlog-max-len 128

# Latency monitor
latency-monitor-threshold 0

# Event notification
notify-keyspace-events ""

# Advanced config
hash-max-ziplist-entries 512
hash-max-ziplist-value 64
list-max-ziplist-size -2
list-compress-depth 0
set-max-intset-entries 512
zset-max-ziplist-entries 128
zset-max-ziplist-value 64
hll-sparse-max-bytes 3000
stream-node-max-bytes 4096
stream-node-max-entries 100
activerehashing yes
client-output-buffer-limit normal 0 0 0
client-output-buffer-limit replica 256mb 64mb 60
client-output-buffer-limit pubsub 32mb 8mb 60
hz 10
dynamic-hz yes
aof-rewrite-incremental-fsync yes
rdb-save-incremental-fsync yes
EOF
    
    print_success "Redis configuration created at $config_dir/redis.conf"
}

# Function to generate Prometheus configuration
generate_prometheus_config() {
    local config_dir=$1
    local domain=$2
    
    # Create prometheus.yml
    cat > "$config_dir/prometheus.yml" << EOF
# Global config
global:
  scrape_interval: 15s
  evaluation_interval: 15s

# Alertmanager configuration
alerting:
  alertmanagers:
    - static_configs:
        - targets:
          # - alertmanager:9093

# Load rules once and periodically evaluate them
rule_files:
  # - "first_rules.yml"
  # - "second_rules.yml"

# Scrape configurations
scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'caddy'
    static_configs:
      - targets: ['caddy:2019']

  - job_name: 'docker'
    static_configs:
      - targets: ['172.17.0.1:9323']
EOF
    
    # Add service-specific scrape configurations
    if $ENABLE_GRAFANA; then
        cat >> "$config_dir/prometheus.yml" << EOF

  - job_name: 'grafana'
    static_configs:
      - targets: ['grafana:3000']
EOF
    fi
    
    if $ENABLE_LOKI; then
        cat >> "$config_dir/prometheus.yml" << EOF

  - job_name: 'loki'
    static_configs:
      - targets: ['loki:3100']
EOF
    fi
    
    print_success "Prometheus configuration created at $config_dir/prometheus.yml"
}

# Function to generate Loki configuration
generate_loki_config() {
    local config_dir=$1
    
    # Create loki-config.yaml
    cat > "$config_dir/loki-config.yaml" << EOF
auth_enabled: false

server:
  http_listen_port: 3100
  grpc_listen_port: 9096

common:
  path_prefix: /loki
  storage:
    filesystem:
      chunks_directory: /loki/chunks
      rules_directory: /loki/rules
  replication_factor: 1
  ring:
    instance_addr: 127.0.0.1
    kvstore:
      store: inmemory

schema_config:
  configs:
    - from: 2020-10-24
      store: boltdb-shipper
      object_store: filesystem
      schema: v11
      index:
        prefix: index_
        period: 24h

ruler:
  alertmanager_url: http://localhost:9093

limits_config:
  enforce_metric_name: false
  reject_old_samples: true
  reject_old_samples_max_age: 168h
EOF
    
    print_success "Loki configuration created at $config_dir/loki-config.yaml"
}

# Function to generate Borgmatic configuration
generate_borgmatic_config() {
    local config_dir=$1
    
    # Create config.yaml
    cat > "$config_dir/config.yaml" << EOF
# Where to look for files to backup, and where to store those backups
location:
    # List of source directories to backup
    source_directories:
        - /data

    # Paths to local or remote repositories
    repositories:
        - /backup/repository

    # Any paths matching these patterns are excluded from backups
    exclude_patterns:
        - '*.pyc'
        - '*.tmp'
        - '*.log'
        - '*/node_modules'
        - '*/cache'
        - '*/tmp'

# Retention policy for how many backups to keep
retention:
    keep_daily: 7
    keep_weekly: 4
    keep_monthly: 6

# Consistency checks to run
consistency:
    checks:
        - repository
        - archives
    check_last: 3

# Options for customizing backups
storage:
    compression: auto
    encryption_passphrase: "change_this_to_a_strong_passphrase"
    archive_name_format: '{hostname}-{now:%Y-%m-%d-%H%M%S}'

# Database backup options
hooks:
    before_backup:
        - /scripts/db-dump.sh
EOF
    
    # Create db-dump.sh script
    cat > "$config_dir/scripts/db-dump.sh" << EOF
#!/bin/bash

# Database backup script for Borgmatic
# This script dumps databases before backup

# Create backup directory
mkdir -p /data/db_dumps

# MariaDB backup
if [ -n "\$MARIADB_ROOT_PASSWORD" ]; then
    echo "Backing up MariaDB databases..."
    mysqldump -h mariadb -u root -p"\$MARIADB_ROOT_PASSWORD" --all-databases > /data/db_dumps/mariadb_all.sql
fi

# PostgreSQL backup
if [ -n "\$POSTGRES_USER" ] && [ -n "\$POSTGRES_PASSWORD" ]; then
    echo "Backing up PostgreSQL databases..."
    PGPASSWORD="\$POSTGRES_PASSWORD" pg_dump -h postgres -U "\$POSTGRES_USER" -d "\$POSTGRES_DB" > /data/db_dumps/postgres_dump.sql
fi

echo "Database dumps completed"
EOF
    
    # Make the script executable
    chmod +x "$config_dir/scripts/db-dump.sh"
    
    print_success "Borgmatic configuration created at $config_dir/config.yaml"
    print_success "Database dump script created at $config_dir/scripts/db-dump.sh"
}

# Function to generate welcome page
generate_welcome_page() {
    local site_dir=$1
    local domain=$2
    
    # Create index.html
    cat > "$site_dir/index.html" << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Welcome to ${domain}</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            line-height: 1.6;
            color: #333;
            max-width: 800px;
            margin: 0 auto;
            padding: 20px;
        }
        h1 {
            color: #2c3e50;
            border-bottom: 2px solid #3498db;
            padding-bottom: 10px;
        }
        h2 {
            color: #2980b9;
        }
        .service {
            background-color: #f9f9f9;
            border-left: 4px solid #3498db;
            padding: 10px 15px;
            margin-bottom: 15px;
            border-radius: 0 4px 4px 0;
        }
        .service h3 {
            margin-top: 0;
            color: #2c3e50;
        }
        a {
            color: #3498db;
            text-decoration: none;
        }
        a:hover {
            text-decoration: underline;
        }
        .footer {
            margin-top: 30px;
            border-top: 1px solid #eee;
            padding-top: 10px;
            font-size: 0.9em;
            color: #7f8c8d;
        }
    </style>
</head>
<body>
    <h1>Welcome to ${domain}</h1>
    
    <p>Your server has been successfully set up with the following services:</p>
    
    <h2>Available Services</h2>
    
    <div class="service">
        <h3>Authentication</h3>
        <p>Centralized authentication for all services.</p>
        <p><a href="https://auth.${domain}" target="_blank">https://auth.${domain}</a></p>
    </div>
EOF
    
    # Add service-specific sections
    if $ENABLE_VAULTWARDEN; then
        cat >> "$site_dir/index.html" << EOF
    
    <div class="service">
        <h3>Vaultwarden</h3>
        <p>Password manager compatible with Bitwarden clients.</p>
        <p><a href="https://vaultwarden.${domain}" target="_blank">https://vaultwarden.${domain}</a></p>
    </div>
EOF
    fi
    
    if $ENABLE_GRAFANA; then
        cat >> "$site_dir/index.html" << EOF
    
    <div class="service">
        <h3>Grafana</h3>
        <p>Analytics and monitoring dashboard.</p>
        <p><a href="https://grafana.${domain}" target="_blank">https://grafana.${domain}</a></p>
    </div>
EOF
    fi
    
    if $ENABLE_PROMETHEUS; then
        cat >> "$site_dir/index.html" << EOF
    
    <div class="service">
        <h3>Prometheus</h3>
        <p>Monitoring system and time series database.</p>
        <p><a href="https://prometheus.${domain}" target="_blank">https://prometheus.${domain}</a></p>
    </div>
EOF
    fi
    
    if $ENABLE_DOCMOST; then
        cat >> "$site_dir/index.html" << EOF
    
    <div class="service">
        <h3>DocMost</h3>
        <p>Documentation and knowledge base.</p>
        <p><a href="https://docs.${domain}" target="_blank">https://docs.${domain}</a></p>
    </div>
EOF
    fi
    
    if $ENABLE_CODE_SERVER; then
        cat >> "$site_dir/index.html" << EOF
    
    <div class="service">
        <h3>Code Server</h3>
        <p>VS Code in the browser.</p>
        <p><a href="https://code.${domain}" target="_blank">https://code.${domain}</a></p>
    </div>
EOF
    fi
    
    if $ENABLE_HOMEASSISTANT; then
        cat >> "$site_dir/index.html" << EOF
    
    <div class="service">
        <h3>Home Assistant</h3>
        <p>Home automation platform.</p>
        <p><a href="https://home.${domain}" target="_blank">https://home.${domain}</a></p>
    </div>
EOF
    fi
    
    if $ENABLE_OWNCLOUD; then
        cat >> "$site_dir/index.html" << EOF
    
    <div class="service">
        <h3>OwnCloud</h3>
        <p>File storage and synchronization.</p>
        <p><a href="https://cloud.${domain}" target="_blank">https://cloud.${domain}</a></p>
    </div>
EOF
    fi
    
    if $ENABLE_PORTAINER; then
        cat >> "$site_dir/index.html" << EOF
    
    <div class="service">
        <h3>Portainer</h3>
        <p>Docker management interface.</p>
        <p><a href="https://portainer.${domain}" target="_blank">https://portainer.${domain}</a></p>
    </div>
EOF
    fi
    
    if $ENABLE_ITTOOLS; then
        cat >> "$site_dir/index.html" << EOF
    
    <div class="service">
        <h3>IT Tools</h3>
        <p>Collection of useful IT tools.</p>
        <p><a href="https://tools.${domain}" target="_blank">https://tools.${domain}</a></p>
    </div>
EOF
    fi
    
    # Add footer
    cat >> "$site_dir/index.html" << EOF
    
    <div class="footer">
        <p>Server setup completed on $(date)</p>
        <p>For support and documentation, refer to the setup guide.</p>
    </div>
</body>
</html>
EOF
    
    print_success "Welcome page created at $site_dir/index.html"
}

# Function to generate backup information
generate_backup_info() {
    local output_file=$1
    local data_dir=$2
    local backup_dir=$3
    
    cat > "$output_file" << EOF
# Backup Instructions and Configuration
# Generated on $(date)

## Backup Locations
- Docker volumes: ${data_dir}
- Configuration files: docker-compose.yml, .env
- Backup destination: ${backup_dir}

## Automated Backup Schedule
- Daily backups: Retained for 7 days
- Weekly backups: Retained for 4 weeks
- Monthly backups: Retained for 6 months

## Manual Backup Commands
# Backup all Docker volumes
docker run --rm -v ${backup_dir}:/backup -v ${data_dir}:/data alpine tar -czf /backup/volumes-\$(date +%Y%m%d).tar.gz /data

# Backup configuration files
tar -czf ${backup_dir}/configs-\$(date +%Y%m%d).tar.gz /opt/docker/compose/docker-compose.yml /opt/docker/compose/.env

## Restore Instructions
1. Stop all containers: 
   docker-compose -f /opt/docker/compose/docker-compose.yml down

2. Restore volumes:
   tar -xzf ${backup_dir}/volumes-YYYYMMDD.tar.gz -C /

3. Restore configs (if needed):
   tar -xzf ${backup_dir}/configs-YYYYMMDD.tar.gz -C /

4. Restart services:
   docker-compose -f /opt/docker/compose/docker-compose.yml up -d

## Testing Backups
It is recommended to test backups by restoring to a staging environment regularly.
EOF
    
    print_success "Backup information created at $output_file"
}

# Function to generate DNS information
generate_dns_info() {
    local domain=$1
    local output_file=$2
    
    # Create DNS info file
    cat > "$output_file" << EOF
# DNS Configuration for ${domain}
# Generated on $(date)

To access your services, you need to configure the following DNS records:

## Main Domain
${domain}.                   A       YOUR_SERVER_IP

## Subdomains (Using A records for better reliability)
auth.${domain}.              A       YOUR_SERVER_IP
EOF
    
    # Add service-specific DNS records
    if $ENABLE_VAULTWARDEN; then
        cat >> "$output_file" << EOF
vaultwarden.${domain}.       A       YOUR_SERVER_IP
EOF
    fi
    
    if $ENABLE_GRAFANA; then
        cat >> "$output_file" << EOF
grafana.${domain}.           A       YOUR_SERVER_IP
EOF
    fi
    
    if $ENABLE_PROMETHEUS; then
        cat >> "$output_file" << EOF
prometheus.${domain}.        A       YOUR_SERVER_IP
EOF
    fi
    
    if $ENABLE_DOCMOST; then
        cat >> "$output_file" << EOF
docs.${domain}.              A       YOUR_SERVER_IP
EOF
    fi
    
    if $ENABLE_CODE_SERVER; then
        cat >> "$output_file" << EOF
code.${domain}.              A       YOUR_SERVER_IP
EOF
    fi
    
    if $ENABLE_HOMEASSISTANT; then
        cat >> "$output_file" << EOF
home.${domain}.              A       YOUR_SERVER_IP
EOF
    fi
    
    if $ENABLE_OWNCLOUD; then
        cat >> "$output_file" << EOF
cloud.${domain}.             A       YOUR_SERVER_IP
EOF
    fi
    
    if $ENABLE_PORTAINER; then
        cat >> "$output_file" << EOF
portainer.${domain}.         A       YOUR_SERVER_IP
EOF
    fi
    
    if $ENABLE_ITTOOLS; then
        cat >> "$output_file" << EOF
tools.${domain}.             A       YOUR_SERVER_IP
EOF
    fi
    
    if $ENABLE_WIREGUARD; then
        cat >> "$output_file" << EOF
vpn.${domain}.               A       YOUR_SERVER_IP
EOF
    fi
    
    # Add instructions
    cat >> "$output_file" << EOF

## Instructions
1. Replace YOUR_SERVER_IP with the public IP address of your server
2. Add these records to your domain's DNS configuration
3. Wait for DNS propagation (may take up to 24-48 hours)
4. Access your services using the URLs listed on the welcome page

## Testing DNS Configuration
You can test DNS propagation with the following command:
  dig +short ${domain}
  
The command should return your server's IP address when DNS has propagated.
EOF
    
    print_success "DNS information created at $output_file"
}
