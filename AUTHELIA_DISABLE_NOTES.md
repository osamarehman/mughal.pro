# Authelia Disabling and Container Troubleshooting

## Overview

This document explains the changes made to fix the container issues by disabling Authelia authentication and fixing other restarting containers.

## Issues Identified

Based on the logs and container status, the following issues were identified:

1. **Authelia**: Failed to start due to invalid password hash format
   ```
   error="error decoding the authentication database: error occurred decoding the password hash for 'admin': provided encoded hash has an invalid identifier: the identifier '' is unknown to the global decoder"
   ```

2. **Other restarting containers**:
   - prometheus
   - grafana
   - redis
   - loki
   - promtail

## Solution Approach

Rather than trying to fix Authelia, we've created a script to disable it completely and fix the other restarting containers. This approach:

1. Disables the Authelia service in the Docker Compose file
2. Removes Authelia authentication from the Caddy configuration
3. Fixes configuration issues in Redis, Prometheus, Grafana, Loki, and Promtail

## Using the Fix Script

1. Copy the `fix-containers.sh` script to your server:
   ```bash
   scp fix-containers.sh user@your-server:/tmp/
   ```

2. SSH into your server:
   ```bash
   ssh user@your-server
   ```

3. Make the script executable:
   ```bash
   chmod +x /tmp/fix-containers.sh
   ```

4. Run the script:
   ```bash
   sudo /tmp/fix-containers.sh
   ```

5. Check the status of your containers:
   ```bash
   cd /opt/docker
   docker-compose ps
   ```

## What the Script Does

The script performs the following actions:

1. **Disables Authelia**:
   - Comments out the Authelia service in the Docker Compose file
   - Removes Authelia-related configuration from the Caddy configuration

2. **Fixes Redis**:
   - Creates a simplified Redis configuration that should work reliably

3. **Fixes Prometheus, Grafana, Loki, and Promtail**:
   - Ensures data directories have correct permissions
   - Updates configuration files as needed

4. **Restarts all containers**:
   - Runs `docker-compose down` and `docker-compose up -d` to apply changes

## Security Considerations

**Important**: By disabling Authelia, your services will no longer have authentication protection. This means:

- Anyone with access to your server's IP/domain can access your services
- There is no single sign-on or access control
- You should consider this a temporary solution until proper authentication can be implemented

## Future Steps

1. **Implement alternative authentication**:
   - Consider using basic authentication in Caddy for simple protection
   - Look into other authentication solutions like Traefik Forward Auth or OAuth2 Proxy

2. **Fix Authelia properly**:
   - If you want to re-enable Authelia in the future, you'll need to:
     - Generate proper Argon2 password hashes
     - Update the Authelia configuration
     - Restore the Docker Compose and Caddy configurations

3. **Monitor container health**:
   - Regularly check container status with `docker-compose ps`
   - Review logs with `docker-compose logs [service]`
   - Set up monitoring alerts for container failures

## Backups

The script creates backups of all modified files:

- `/opt/docker/docker-compose.yml.bak`
- `/opt/docker/data/caddy/config/Caddyfile.bak`
- `/opt/docker/data/redis/redis.conf.bak`

If you need to revert changes, you can restore these backup files.
