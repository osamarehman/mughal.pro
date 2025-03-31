# Docker Container Troubleshooting Checklist

This document provides a step-by-step checklist for troubleshooting common Docker container issues in your setup.

## Quick Reference

| Issue | Solution | Script |
|-------|----------|--------|
| Container name conflicts | Clean up Docker environment | `cleanup-docker.sh` |
| Authelia password hash issues | Fix hash generation | `fix-authelia-hash.sh` |
| Redis configuration issues | Fix Redis config | `fix-redis-config.sh` or `radis-fix.sh` |
| Caddy authentication issues | Remove auth directives | `fix-caddy-auth.sh` |
| Network issues with containers | Fix network configuration | `fix-containers.sh` |
| General configuration issues | Check all configs | `check-container-configs.sh` |
| Restarting containers | Proper restart commands | See "Restarting Containers" section |
| Container logs | How to check logs | See "Checking Container Logs" section |

## Container Name Conflicts

**Symptoms:**
- Error message: `Error response from daemon: Conflict. The container name "/container_name" is already in use`
- Containers in "Created" state but not running

**Solution:**
1. Run the cleanup script:
   ```bash
   chmod +x cleanup-docker.sh
   sudo ./cleanup-docker.sh
   ```
2. Answer `y` to remove containers and networks
3. Answer `n` to keep your data volumes (unless you want to start completely fresh)
4. Run your setup script again:
   ```bash
   sudo ./setup.sh
   ```

## Authelia Password Hash Issues

**Symptoms:**
- Authelia container keeps restarting
- Error in logs: `error decoding the authentication database: error occurred decoding the password hash for 'admin': provided encoded hash has an invalid identifier`

**Solution:**
1. Fix the hash generation in the setup script:
   ```bash
   chmod +x fix-authelia-hash.sh
   ./fix-authelia-hash.sh
   ```
2. Clean up Docker environment:
   ```bash
   sudo ./cleanup-docker.sh
   ```
3. Run the setup script again:
   ```bash
   sudo ./setup.sh
   ```

## Redis Configuration Issues

**Symptoms:**
- Redis container keeps restarting
- Error in logs: `*** FATAL CONFIG FILE ERROR (Redis 6.2.17) *** Reading the configuration file, at line 24 >>> 'requirepass ""  # No password by default, set in environment if needed' wrong number of arguments`

**Solution:**
1. Fix the Redis configuration file:
   ```bash
   chmod +x fix-redis-config.sh
   sudo ./fix-redis-config.sh
   ```
   or if you have the alternative script:
   ```bash
   chmod +x radis-fix.sh
   sudo ./radis-fix.sh
   ```
2. Clean up Docker environment:
   ```bash
   sudo ./cleanup-docker.sh
   ```
3. Run the setup script again:
   ```bash
   sudo ./setup.sh
   ```

**Prevention:**
- Redis doesn't support comments on the same line as configuration directives
- Always place comments on separate lines in Redis configuration files

## Caddy Authentication Issues

**Symptoms:**
- Still being prompted for authentication even after disabling Authelia
- Authentication-related errors in Caddy logs
- Unable to access services due to authentication prompts

**Solution:**
1. Fix the Caddy configuration to remove authentication directives:
   ```bash
   chmod +x fix-caddy-auth.sh
   sudo ./fix-caddy-auth.sh
   ```
2. If issues persist, check Docker Compose configuration for Authelia references:
   ```bash
   grep -r "authelia" /opt/docker/compose/
   ```
3. Restart Caddy container:
   ```bash
   docker restart caddy
   ```

## Network Issues with Monitoring Containers

**Symptoms:**
- Prometheus, Grafana, Loki, or Promtail containers keep restarting
- Network-related errors in container logs
- Error about network "compose_monitoringcompose_proxy" not found

**Solution:**
1. Run the comprehensive container fix script:
   ```bash
   chmod +x fix-containers.sh
   sudo ./fix-containers.sh
   ```
2. This script will:
   - Fix network configuration for monitoring containers
   - Create the correct networks if they don't exist
   - Recreate containers with proper configuration
   - Check container status after fixes

## Checking Container Status

**Commands:**
- List all containers (running and stopped):
  ```bash
  docker ps -a
  ```
- List only running containers:
  ```bash
  docker ps
  ```
- Check container details:
  ```bash
  docker inspect <container_name>
  ```

**What to Look For:**
- **Status**: Should be "Up" for running containers
- **Health**: Should be "healthy" if health checks are configured
- **Restart Count**: High restart counts indicate recurring issues

## Checking Container Logs

**Commands:**
- View logs for a specific container:
  ```bash
  docker logs <container_name>
  ```
- View the last N lines of logs:
  ```bash
  docker logs --tail=100 <container_name>
  ```
- Follow logs in real-time:
  ```bash
  docker logs -f <container_name>
  ```

**Common Log Issues:**
- **Permission errors**: Check volume mount permissions
- **Configuration errors**: Check configuration files
- **Network errors**: Check network connectivity between containers
- **Resource constraints**: Check if container is running out of memory or CPU

## Restarting Containers

**Individual Container:**
- Restart a single container:
  ```bash
  docker restart <container_name>
  ```

**All Containers:**
- Using Docker Compose:
  ```bash
  cd /opt/docker/compose
  docker-compose down
  docker-compose up -d
  ```

**Recreate a Single Container:**
- Stop and remove the container:
  ```bash
  docker stop <container_name>
  docker rm <container_name>
  ```
- Create a new container (example for Redis):
  ```bash
  docker run -d \
      --name redis \
      --network compose_proxy \
      --restart unless-stopped \
      -e TZ=Etc/UTC \
      redis:6 redis-server --appendonly yes --protected-mode no
  ```

## Network Issues

**Symptoms:**
- Containers can't communicate with each other
- "Connection refused" errors in logs

**Checks:**
1. Verify networks exist:
   ```bash
   docker network ls
   ```
2. Check which network a container is connected to:
   ```bash
   docker inspect -f '{{range $key, $value := .NetworkSettings.Networks}}{{$key}} {{end}}' <container_name>
   ```
3. Ensure containers that need to communicate are on the same network

**Solution:**
- Connect a container to a network:
  ```bash
  docker network connect <network_name> <container_name>
  ```
- Create a missing network:
  ```bash
  docker network create <network_name>
  ```

## Volume Issues

**Symptoms:**
- Permission denied errors in logs
- Missing data
- Container can't write to mounted volumes

**Checks:**
1. List volumes:
   ```bash
   docker volume ls
   ```
2. Inspect a volume:
   ```bash
   docker volume inspect <volume_name>
   ```
3. Check permissions on the host:
   ```bash
   ls -la /opt/docker/data/<service>
   ```

**Solution:**
- Fix permissions:
  ```bash
  sudo chown -R 1000:1000 /opt/docker/data/<service>
  # or
  sudo chmod -R 777 /opt/docker/data/<service>  # Less secure but works for testing
  ```

## Configuration Issues

**Symptoms:**
- Container starts but doesn't work as expected
- Configuration errors in logs

**Checks:**
1. Verify configuration files exist:
   ```bash
   ls -la /opt/docker/data/<service>/config/
   ```
2. Check configuration file content:
   ```bash
   cat /opt/docker/data/<service>/config/<config_file>
   ```

**Solution:**
- Recreate configuration files from templates
- Restore from backups
- Run the setup script again with the correct parameters

## Preventive Measures

1. **Regular Backups**:
   - Back up your Docker volumes regularly
   - Document your container configurations

2. **Monitoring**:
   - Set up monitoring for container health
   - Configure alerts for container restarts

3. **Documentation**:
   - Keep a record of all customizations
   - Document troubleshooting steps specific to your setup

4. **Updates**:
   - Keep Docker and container images updated
   - Test updates in a staging environment first

## Advanced Troubleshooting

If the above steps don't resolve your issues:

1. **Check Docker Engine Logs**:
   ```bash
   sudo journalctl -u docker
   ```

2. **Check System Resources**:
   ```bash
   df -h  # Disk space
   free -m  # Memory
   top  # CPU and memory usage
   ```

3. **Check for Docker Updates**:
   ```bash
   sudo apt update
   sudo apt list --upgradable | grep docker
   ```

4. **Restart Docker Service**:
   ```bash
   sudo systemctl restart docker
   ```

5. **Check Docker Info**:
   ```bash
   docker info
   ```

## Comprehensive Fix Script

If you're experiencing multiple issues with your containers, you can use the comprehensive fix script to address common problems:

```bash
chmod +x fix-containers.sh
sudo ./fix-containers.sh
```

This script will:
- Fix Redis configuration issues
- Fix Authelia hash issues
- Optionally disable Authelia authentication
- Fix network issues with monitoring containers
- Recreate problematic containers with proper configuration
- Check container status after fixes

Remember: Always back up your data before making significant changes to your Docker environment.
