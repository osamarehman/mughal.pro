#!/bin/bash

# Server Setup Resources Script
# This script contains functions for generating configuration files

# Function to generate configurations
generate_configurations() {
    print_header "Generating Configuration Files"
    
    # Generate Caddy configuration
    generate_caddy_config "$DATA_DIR/caddy/config" "$DOMAIN" "$EMAIL"
    
    # Generate Authelia configuration
    generate_authelia_config "$DATA_DIR/authelia/config" "$DOMAIN" "$JWT_SECRET" "admin" "$ADMIN_HASH" "user" "$USER_HASH" "$EMAIL"
    
    # Generate MariaDB configuration if enabled
    if $ENABLE_MARIADB; then
        generate_mariadb_config "$DATA_DIR/mariadb/config"
    fi
    
    # Generate Redis configuration if enabled
    if $ENABLE_REDIS; then
        generate_redis_config "$DATA_DIR/redis"
    fi
    
    # Generate Prometheus configuration if enabled
    if $ENABLE_PROMETHEUS; then
        generate_prometheus_config "$DATA_DIR/prometheus/config" "$DOMAIN"
    fi
    
    # Generate Loki configuration if enabled
    if $ENABLE_LOKI; then
        generate_loki_config "$DATA_DIR/loki/config"
    fi
    
    # Generate Borgmatic configuration if enabled
    if $ENABLE_BORGMATIC; then
        generate_borgmatic_config "$DATA_DIR/borgmatic/config"
    fi
    
    # Generate welcome page
    generate_welcome_page "$DATA_DIR/caddy/site" "$DOMAIN"
    
    # Generate DNS information
    generate_dns_info "$DOMAIN" "$DATA_DIR/dns_info.txt"
    
    # Generate backup information
    generate_backup_info "$DATA_DIR/backup_info.txt" "$DATA_DIR" "$BACKUP_DIR"
    
    print_success "Configuration files generated"
}

# Function to generate Caddy configuration
generate_caddy_config() {
    local config_dir=$1
    local domain=$2
    local email=$3
    
    # Create Caddyfile
    cat > "$config_dir/Caddyfile" << EOF
{
    # Global options
    email "$email"
    admin off
}

# Default site
$domain {
    root * /srv
    file_server
    
    # Basic authentication for the welcome page
    basicauth /* {
        admin JDJhJDEwJHhFNGxGbEtKUXJja0JWMUlOeUVzL09lWVdaNFRXNVpSY0JCeC5QVzNkQ2JaTjlCcWRnSzVX
    }
    
    # Reverse proxy for Authelia
    handle /authelia/* {
        reverse_proxy authelia:9091
    }
    
    # Health check endpoint
    handle /health {
        respond "OK" 200
    }
    
    # Logging
    log {
        output file /data/logs/access.log {
            roll_size 10MB
            roll_keep 10
        }
    }
}

# Vaultwarden subdomain
vault.$domain {
    reverse_proxy vaultwarden:80
    
    # Authentication with Authelia
    forward_auth authelia:9091 {
        uri /api/verify?rd=https://authelia.$domain
        copy_headers Remote-User Remote-Groups Remote-Name Remote-Email
    }
}

# Grafana subdomain
grafana.$domain {
    reverse_proxy grafana:3000
    
    # Authentication with Authelia
    forward_auth authelia:9091 {
        uri /api/verify?rd=https://authelia.$domain
        copy_headers Remote-User Remote-Groups Remote-Name Remote-Email
    }
}

# Authelia subdomain
authelia.$domain {
    reverse_proxy authelia:9091
}

# Prometheus subdomain (if enabled)
prometheus.$domain {
    reverse_proxy prometheus:9090
    
    # Authentication with Authelia
    forward_auth authelia:9091 {
        uri /api/verify?rd=https://authelia.$domain
        copy_headers Remote-User Remote-Groups Remote-Name Remote-Email
    }
}

# DocMost subdomain (if enabled)
docs.$domain {
    reverse_proxy docmost:3000
    
    # Authentication with Authelia
    forward_auth authelia:9091 {
        uri /api/verify?rd=https://authelia.$domain
        copy_headers Remote-User Remote-Groups Remote-Name Remote-Email
    }
}

# Code Server subdomain (if enabled)
code.$domain {
    reverse_proxy code-server:8080
    
    # Authentication with Authelia
    forward_auth authelia:9091 {
        uri /api/verify?rd=https://authelia.$domain
        copy_headers Remote-User Remote-Groups Remote-Name Remote-Email
    }
}

# Home Assistant subdomain (if enabled)
home.$domain {
    reverse_proxy homeassistant:8123
    
    # Authentication with Authelia
    forward_auth authelia:9091 {
        uri /api/verify?rd=https://authelia.$domain
        copy_headers Remote-User Remote-Groups Remote-Name Remote-Email
    }
}

# OwnCloud subdomain (if enabled)
cloud.$domain {
    reverse_proxy owncloud:8080
    
    # Authentication with Authelia
    forward_auth authelia:9091 {
        uri /api/verify?rd=https://authelia.$domain
        copy_headers Remote-User Remote-Groups Remote-Name Remote-Email
    }
}

# Portainer subdomain (if enabled)
portainer.$domain {
    reverse_proxy portainer:9000
    
    # Authentication with Authelia
    forward_auth authelia:9091 {
        uri /api/verify?rd=https://authelia.$domain
        copy_headers Remote-User Remote-Groups Remote-Name Remote-Email
    }
}

# IT Tools subdomain (if enabled)
tools.$domain {
    reverse_proxy ittools:80
    
    # Authentication with Authelia
    forward_auth authelia:9091 {
        uri /api/verify?rd=https://authelia.$domain
        copy_headers Remote-User Remote-Groups Remote-Name Remote-Email
    }
}
EOF
    
    print_success "Caddy configuration generated at $config_dir/Caddyfile"
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
    local storage_encryption_key=$STORAGE_ENCRYPTION_KEY
    
    # Create configuration.yml
    cat > "$config_dir/configuration.yml" << EOF
---
###############################################################################
#                           Authelia Configuration                            #
###############################################################################

server:
  host: 0.0.0.0
  port: 9091

log:
  level: info
  format: text

theme: light

jwt_secret: $jwt_secret

default_redirection_url: https://$domain

totp:
  issuer: Authelia
  period: 30
  skew: 1

authentication_backend:
  file:
    path: /config/users_database.yml
    password:
      algorithm: argon2id
      iterations: 3
      key_length: 32
      salt_length: 16
      memory: 65536
      parallelism: 4

access_control:
  default_policy: deny
  rules:
    - domain: authelia.$domain
      policy: bypass
    - domain: $domain
      policy: bypass
    - domain: "*.${domain}"
      policy: one_factor

session:
  name: authelia_session
  domain: $domain
  same_site: lax
  expiration: 1h
  inactivity: 5m
  remember_me_duration: 1M

regulation:
  max_retries: 3
  find_time: 2m
  ban_time: 5m

storage:
  local:
    path: /config/db.sqlite3
  encryption_key: ${STORAGE_ENCRYPTION_KEY}

notifier:
  filesystem:
    filename: /config/notification.txt
EOF
    
    # Create users_database.yml
    cat > "$config_dir/users_database.yml" << EOF
---
###############################################################################
#                         Users Database Configuration                        #
###############################################################################

users:
  $admin_user:
    displayname: "Administrator"
    password: "$admin_hash"
    email: "$email"
    groups:
      - admins
  
  $user_user:
    displayname: "Regular User"
    password: "$user_hash"
    email: "$email"
    groups:
      - users
EOF
    
    print_success "Authelia configuration generated at $config_dir/configuration.yml"
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
innodb_buffer_pool_size = 128M
max_connections = 100
max_allowed_packet = 16M
EOF
    
    print_success "MariaDB configuration generated at $config_dir/custom.cnf"
}

# Function to generate Redis configuration
generate_redis_config() {
    local redis_dir=$1
    
    # Create redis.conf
    cat > "$redis_dir/redis.conf" << EOF
# Redis configuration file

# Basic configuration
port 6379
bind 0.0.0.0
protected-mode yes
daemonize no

# Persistence
save 900 1
save 300 10
save 60 10000
stop-writes-on-bgsave-error yes
rdbcompression yes
rdbchecksum yes
dbfilename dump.rdb
dir /data

# Memory management
maxmemory 256mb
maxmemory-policy allkeys-lru

# Security
# No password by default, set in environment if needed
requirepass ""

# Logging
loglevel notice
# Log to stdout
logfile ""
EOF
    
    print_success "Redis configuration generated at $redis_dir/redis.conf"
}

# Function to generate Prometheus configuration
generate_prometheus_config() {
    local config_dir=$1
    local domain=$2
    
    # Create prometheus.yml
    cat > "$config_dir/prometheus.yml" << EOF
global:
  scrape_interval: 15s
  evaluation_interval: 15s

alerting:
  alertmanagers:
    - static_configs:
        - targets:
          # - alertmanager:9093

rule_files:
  # - "first_rules.yml"
  # - "second_rules.yml"

scrape_configs:
  - job_name: "prometheus"
    static_configs:
      - targets: ["localhost:9090"]
  
  - job_name: "caddy"
    static_configs:
      - targets: ["caddy:2019"]
  
  - job_name: "node"
    static_configs:
      - targets: ["node-exporter:9100"]
EOF
    
    print_success "Prometheus configuration generated at $config_dir/prometheus.yml"
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
    
    print_success "Loki configuration generated at $config_dir/loki-config.yaml"
}

# Function to generate Borgmatic configuration
generate_borgmatic_config() {
    local config_dir=$1
    
    # Create config.yaml
    cat > "$config_dir/config.yaml" << EOF
location:
    source_directories:
        - /backup/data
    repositories:
        - /backup/repository
    exclude_patterns:
        - '*.pyc'
        - '*.tmp'
        - '*.log'
        - '*/node_modules'
        - '*/cache'
        - '*/tmp'

storage:
    encryption_passphrase: "change_this_to_a_strong_passphrase"
    compression: lz4
    archive_name_format: '{hostname}-{now:%Y-%m-%d-%H%M%S}'

retention:
    keep_daily: 7
    keep_weekly: 4
    keep_monthly: 6
    prefix: '{hostname}-'

consistency:
    checks:
        - repository
        - archives
    check_last: 3
    prefix: '{hostname}-'

hooks:
    before_backup:
        - /scripts/before-backup.sh
    after_backup:
        - /scripts/after-backup.sh
EOF
    
    # Create before-backup.sh
    mkdir -p "$config_dir/scripts"
    cat > "$config_dir/scripts/before-backup.sh" << EOF
#!/bin/bash

# Script to run before backup
echo "Starting backup at \$(date)"

# Dump MariaDB databases if MariaDB is enabled
if [ -n "\$MARIADB_ROOT_PASSWORD" ]; then
    echo "Dumping MariaDB databases..."
    mkdir -p /backup/data/mariadb
    mysqldump -h mariadb -u root -p"\$MARIADB_ROOT_PASSWORD" --all-databases > /backup/data/mariadb/all-databases.sql
fi

# Dump PostgreSQL databases if PostgreSQL is enabled
if [ -n "\$POSTGRES_USER" ] && [ -n "\$POSTGRES_PASSWORD" ]; then
    echo "Dumping PostgreSQL databases..."
    mkdir -p /backup/data/postgres
    PGPASSWORD="\$POSTGRES_PASSWORD" pg_dumpall -h postgres -U "\$POSTGRES_USER" > /backup/data/postgres/all-databases.sql
fi

exit 0
EOF
    
    # Create after-backup.sh
    cat > "$config_dir/scripts/after-backup.sh" << EOF
#!/bin/bash

# Script to run after backup
echo "Backup completed at \$(date)"

# Clean up temporary files
rm -f /backup/data/mariadb/all-databases.sql
rm -f /backup/data/postgres/all-databases.sql

exit 0
EOF
    
    # Make scripts executable
    chmod +x "$config_dir/scripts/before-backup.sh"
    chmod +x "$config_dir/scripts/after-backup.sh"
    
    print_success "Borgmatic configuration generated at $config_dir/config.yaml"
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
    <title>Welcome to Your Server</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            line-height: 1.6;
            margin: 0;
            padding: 20px;
            color: #333;
            max-width: 1200px;
            margin: 0 auto;
        }
        header {
            background-color: #2c3e50;
            color: white;
            padding: 20px;
            text-align: center;
            border-radius: 5px;
            margin-bottom: 20px;
        }
        h1 {
            margin: 0;
        }
        .container {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
            gap: 20px;
        }
        .card {
            border: 1px solid #ddd;
            border-radius: 5px;
            padding: 20px;
            box-shadow: 0 2px 5px rgba(0,0,0,0.1);
            transition: transform 0.3s ease;
        }
        .card:hover {
            transform: translateY(-5px);
            box-shadow: 0 5px 15px rgba(0,0,0,0.1);
        }
        .card h2 {
            margin-top: 0;
            color: #2c3e50;
        }
        .card p {
            margin-bottom: 15px;
        }
        .card a {
            display: inline-block;
            background-color: #3498db;
            color: white;
            padding: 8px 15px;
            text-decoration: none;
            border-radius: 3px;
            transition: background-color 0.3s ease;
        }
        .card a:hover {
            background-color: #2980b9;
        }
        footer {
            margin-top: 40px;
            text-align: center;
            color: #777;
            font-size: 0.9em;
        }
    </style>
</head>
<body>
    <header>
        <h1>Welcome to Your Server</h1>
        <p>Your self-hosted services dashboard</p>
    </header>
    
    <div class="container">
        <div class="card">
            <h2>Authentication</h2>
            <p>Secure single sign-on for all your services</p>
            <a href="https://authelia.$domain" target="_blank">Access Authelia</a>
        </div>
        
        <div class="card">
            <h2>Password Manager</h2>
            <p>Securely store and manage your passwords</p>
            <a href="https://vault.$domain" target="_blank">Access Vaultwarden</a>
        </div>
        
        <div class="card">
            <h2>Monitoring</h2>
            <p>Visualize system metrics and performance</p>
            <a href="https://grafana.$domain" target="_blank">Access Grafana</a>
        </div>
EOF
    
    # Add conditional services
    if $ENABLE_PROMETHEUS; then
        cat >> "$site_dir/index.html" << EOF
        
        <div class="card">
            <h2>Metrics</h2>
            <p>Collect and query metrics from your services</p>
            <a href="https://prometheus.$domain" target="_blank">Access Prometheus</a>
        </div>
EOF
    fi
    
    if $ENABLE_DOCMOST; then
        cat >> "$site_dir/index.html" << EOF
        
        <div class="card">
            <h2>Documentation</h2>
            <p>Create and manage your documentation</p>
            <a href="https://docs.$domain" target="_blank">Access DocMost</a>
        </div>
EOF
    fi
    
    if $ENABLE_CODE_SERVER; then
        cat >> "$site_dir/index.html" << EOF
        
        <div class="card">
            <h2>Code Editor</h2>
            <p>Edit code directly in your browser</p>
            <a href="https://code.$domain" target="_blank">Access Code Server</a>
        </div>
EOF
    fi
    
    if $ENABLE_HOMEASSISTANT; then
        cat >> "$site_dir/index.html" << EOF
        
        <div class="card">
            <h2>Home Automation</h2>
            <p>Control and automate your smart home</p>
            <a href="https://home.$domain" target="_blank">Access Home Assistant</a>
        </div>
EOF
    fi
    
    if $ENABLE_OWNCLOUD; then
        cat >> "$site_dir/index.html" << EOF
        
        <div class="card">
            <h2>File Storage</h2>
            <p>Store and share your files securely</p>
            <a href="https://cloud.$domain" target="_blank">Access OwnCloud</a>
        </div>
EOF
    fi
    
    if $ENABLE_PORTAINER; then
        cat >> "$site_dir/index.html" << EOF
        
        <div class="card">
            <h2>Docker Management</h2>
            <p>Manage your Docker containers</p>
            <a href="https://portainer.$domain" target="_blank">Access Portainer</a>
        </div>
EOF
    fi
    
    if $ENABLE_ITTOOLS; then
        cat >> "$site_dir/index.html" << EOF
        
        <div class="card">
            <h2>IT Tools</h2>
            <p>Collection of useful IT tools</p>
            <a href="https://tools.$domain" target="_blank">Access IT Tools</a>
        </div>
EOF
    fi
    
    # Close HTML
    cat >> "$site_dir/index.html" << EOF
    </div>
    
    <footer>
        <p>Server setup powered by Docker and Caddy. Generated on $(date).</p>
    </footer>
</body>
</html>
EOF
    
    print_success "Welcome page generated at $site_dir/index.html"
}

# Function to generate DNS information
generate_dns_info() {
    local domain=$1
    local output_file=$2
    
    cat > "$output_file" << EOF
# DNS Configuration Information
# Generated on $(date)

To access your services, you need to configure your DNS records as follows:

1. Create an A record for your main domain:
   $domain -> [Your Server IP]

2. Create CNAME records for all subdomains:
   authelia.$domain -> $domain
   vault.$domain -> $domain
   grafana.$domain -> $domain
EOF
    
    if $ENABLE_PROMETHEUS; then
        cat >> "$output_file" << EOF
   prometheus.$domain -> $domain
EOF
    fi
    
    if $ENABLE_DOCMOST; then
        cat >> "$output_file" << EOF
   docs.$domain -> $domain
EOF
    fi
    
    if $ENABLE_CODE_SERVER; then
        cat >> "$output_file" << EOF
   code.$domain -> $domain
EOF
    fi
    
    if $ENABLE_HOMEASSISTANT; then
        cat >> "$output_file" << EOF
   home.$domain -> $domain
EOF
    fi
    
    if $ENABLE_OWNCLOUD; then
        cat >> "$output_file" << EOF
   cloud.$domain -> $domain
EOF
    fi
    
    if $ENABLE_PORTAINER; then
        cat >> "$output_file" << EOF
   portainer.$domain -> $domain
EOF
    fi
    
    if $ENABLE_ITTOOLS; then
        cat >> "$output_file" << EOF
   tools.$domain -> $domain
EOF
    fi
    
    cat >> "$output_file" << EOF

3. If you're using Cloudflare or another proxy service, make sure to:
   - Set SSL/TLS encryption mode to "Full" or "Full (strict)"
   - Enable "Always Use HTTPS"
   - Consider enabling "Authenticated Origin Pulls" for additional security

4. If you're using your own domain registrar, make sure to:
   - Point your domain to your DNS provider
   - Configure your DNS records as described above
   - Ensure your firewall allows traffic on ports 80 and 443

Note: DNS propagation may take up to 24-48 hours, but typically completes within a few hours.
EOF
    
    print_success "DNS information generated at $output_file"
}

# Function to generate backup information
generate_backup_info() {
    local output_file=$1
    local data_dir=$2
    local backup_dir=$3
    
    cat > "$output_file" << EOF
# Backup Information
# Generated on $(date)

Your server is configured with the following backup settings:

1. Data Directory: $data_dir
   This directory contains all your service data and configurations.

2. Backup Directory: $backup_dir
   This directory is used for storing backups.

3. Backup Schedule:
   - Daily backups are kept for 7 days
   - Weekly backups are kept for 4 weeks
   - Monthly backups are kept for 6 months

4. Backup Process:
   - Before backup: Database dumps are created for MariaDB and PostgreSQL
   - Backup: All data is compressed and encrypted using Borgmatic
   - After backup: Temporary files are cleaned up

5. Manual Backup:
   To manually trigger a backup, run:
   docker exec borgmatic borgmatic --verbosity 1

6. Restore from Backup:
   To restore from a backup, run:
   docker exec borgmatic borgmatic extract --archive latest --path /path/to/restore

7. List Available Backups:
   To list all available backups, run:
   docker exec borgmatic borgmatic list

For more information on Borgmatic, visit: https://torsion.org/borgmatic/
EOF
    
    print_success "Backup information generated at $output_file"
}
