# Docker Container Troubleshooting Solution

This document provides a comprehensive guide to troubleshooting Docker container issues, with a focus on the specific problems identified in your environment.

## Table of Contents

1. [Understanding Container States](#understanding-container-states)
2. [Common Issues and Solutions](#common-issues-and-solutions)
3. [Authentication Issues](#authentication-issues)
4. [Database Connection Issues](#database-connection-issues)
5. [Network Issues](#network-issues)
6. [Permission Issues](#permission-issues)
7. [Volume Issues](#volume-issues)
8. [Resource Constraints](#resource-constraints)
9. [Troubleshooting Specific Containers](#troubleshooting-specific-containers)
10. [Advanced Troubleshooting](#advanced-troubleshooting)
11. [Preventive Measures](#preventive-measures)

## Understanding Container States

Docker containers can be in various states:

- **Created**: Container has been created but not started
- **Running**: Container is running normally
- **Paused**: Container has been paused
- **Restarting**: Container is restarting (often due to an error)
- **Exited**: Container has stopped running
- **Dead**: Container is in an unrecoverable state

When troubleshooting, focus on containers in the "Restarting" or "Exited" states, as these indicate problems.

## Common Issues and Solutions

### 1. Container Keeps Restarting

**Symptoms**:
- Container status shows "Restarting"
- Container starts and then immediately stops

**Causes**:
- Application inside the container is crashing
- Missing dependencies or configuration
- Permission issues
- Resource constraints

**Solutions**:
- Check container logs: `docker logs <container_name>`
- Verify configuration files
- Check for permission issues
- Ensure the container has enough resources

### 2. Container Exits Immediately

**Symptoms**:
- Container status shows "Exited"
- Container runs briefly and then stops

**Causes**:
- Command or entrypoint fails
- Missing environment variables
- Volume mount issues

**Solutions**:
- Check container logs: `docker logs <container_name>`
- Verify command and entrypoint
- Check environment variables
- Verify volume mounts

### 3. Container Cannot Connect to Other Services

**Symptoms**:
- Connection refused errors in logs
- Services cannot communicate with each other

**Causes**:
- Network configuration issues
- Services on different networks
- Incorrect hostnames or ports

**Solutions**:
- Ensure containers are on the same network
- Use service names for DNS resolution
- Check port configurations
- Verify network settings

## Authentication Issues

### Authelia Issues

**Symptoms**:
- Authelia container is restarting
- Error messages about invalid password hash
- Authentication prompts when accessing services

**Causes**:
- Invalid password hash format
- Configuration issues
- Redis connection problems

**Solutions**:
- Fix invalid password hash: `sudo ./fix-authelia-hash.sh`
- Remove authentication directives from Caddy: `sudo ./fix-caddy-auth.sh`
- Ensure Redis is running and accessible to Authelia

### Caddy Authentication Issues

**Symptoms**:
- Authentication prompts when accessing services
- Caddy container is restarting
- Error messages about authentication in Caddy logs

**Causes**:
- Authelia configuration issues
- Caddy configuration issues
- Network issues between Caddy and Authelia

**Solutions**:
- Remove authentication directives from Caddy: `sudo ./fix-caddy-auth.sh`
- Simplify Caddy configuration: `sudo ./fix-caddy.sh`
- Disable Authelia if not needed

## Database Connection Issues

### MariaDB/MySQL Connection Issues

**Symptoms**:
- Services cannot connect to the database
- Error messages about connection refused
- Services restarting due to database connection failures

**Causes**:
- Database container not running
- Services on different networks
- Incorrect database credentials
- Database initialization issues

**Solutions**:
- Ensure database container is running
- Connect services to the same network as the database
- Verify database credentials
- Check database logs for initialization issues

### PostgreSQL Connection Issues

**Symptoms**:
- Services cannot connect to PostgreSQL
- Error messages about connection refused
- Services restarting due to database connection failures

**Causes**:
- PostgreSQL container not running
- Services on different networks
- Incorrect database credentials
- PostgreSQL initialization issues

**Solutions**:
- Ensure PostgreSQL container is running
- Connect services to the same network as PostgreSQL
- Verify database credentials
- Check PostgreSQL logs for initialization issues

## Network Issues

### Container Network Isolation

**Symptoms**:
- Containers cannot communicate with each other
- Connection refused errors
- DNS resolution failures

**Causes**:
- Containers on different networks
- Network configuration issues
- Docker network driver issues

**Solutions**:
- Connect containers to the same network
- Use Docker Compose to manage networks
- Restart Docker daemon if network driver issues occur

### External Network Access

**Symptoms**:
- Containers cannot access external resources
- DNS resolution failures for external domains
- Connection timeouts

**Causes**:
- DNS configuration issues
- Firewall blocking outbound connections
- Network routing issues

**Solutions**:
- Configure DNS settings for Docker
- Check firewall rules
- Verify network routing

## Permission Issues

### Volume Mount Permission Issues

**Symptoms**:
- Permission denied errors in container logs
- Container cannot write to mounted volumes
- Container restarts due to permission issues

**Causes**:
- Incorrect ownership of mounted volumes
- Restrictive permissions on host directories
- User ID mismatch between container and host

**Solutions**:
- Fix permissions on host directories
- Use the same user ID in container and host
- Mount volumes with appropriate permissions

### File Permission Issues

**Symptoms**:
- Permission denied errors when accessing files
- Container cannot read or write files
- Container restarts due to permission issues

**Causes**:
- Incorrect file permissions
- Ownership issues
- SELinux or AppArmor restrictions

**Solutions**:
- Fix file permissions and ownership
- Configure SELinux or AppArmor correctly
- Use appropriate user in container

## Volume Issues

### Missing Volumes

**Symptoms**:
- Container cannot find expected files
- Error messages about missing files or directories
- Container restarts due to missing data

**Causes**:
- Volume not mounted correctly
- Volume path incorrect
- Volume not created

**Solutions**:
- Verify volume mounts in Docker Compose or run command
- Create missing volumes
- Check volume paths

### Volume Data Corruption

**Symptoms**:
- Unexpected behavior in container
- Error messages about corrupt data
- Container restarts due to data issues

**Causes**:
- Improper container shutdown
- Disk issues
- Concurrent access issues

**Solutions**:
- Backup and recreate volumes
- Check disk health
- Implement proper locking mechanisms

## Resource Constraints

### CPU Constraints

**Symptoms**:
- Container performance is slow
- Container becomes unresponsive
- High CPU usage on host

**Causes**:
- Insufficient CPU allocation
- CPU-intensive processes
- Too many containers on host

**Solutions**:
- Allocate more CPU resources
- Optimize container processes
- Distribute containers across hosts

### Memory Constraints

**Symptoms**:
- Container crashes with out-of-memory errors
- Container restarts due to memory issues
- High memory usage on host

**Causes**:
- Insufficient memory allocation
- Memory leaks
- Too many containers on host

**Solutions**:
- Allocate more memory
- Fix memory leaks
- Distribute containers across hosts

## Troubleshooting Specific Containers

### Caddy

**Common Issues**:
- Configuration syntax errors
- Certificate issues
- Permission problems with mounted volumes

**Solutions**:
- Simplify Caddy configuration: `sudo ./fix-caddy.sh`
- Fix permissions on Caddy directories
- Check Caddy logs for specific errors

### ownCloud

**Common Issues**:
- Database connection problems
- Redis connection issues
- Permission problems with data directory

**Solutions**:
- Fix database connection issues: `sudo ./fix-owncloud.sh`
- Disable Redis if not needed
- Fix permissions on ownCloud data directory

### Authelia

**Common Issues**:
- Invalid password hash
- Redis connection problems
- Configuration syntax errors

**Solutions**:
- Fix invalid password hash: `sudo ./fix-authelia-hash.sh`
- Ensure Redis is running and accessible
- Verify Authelia configuration

### Redis

**Common Issues**:
- Permission problems with data directory
- Configuration issues
- Memory constraints

**Solutions**:
- Fix Redis configuration: `sudo ./fix-redis-config.sh`
- Fix permissions on Redis data directory
- Allocate more memory to Redis if needed

### Prometheus, Grafana, Loki, Promtail

**Common Issues**:
- Configuration syntax errors
- Permission problems with data directories
- Network issues

**Solutions**:
- Verify configuration files
- Fix permissions on data directories
- Ensure containers are on the same network

## Advanced Troubleshooting

### Docker Logs

Docker logs are your first line of defense when troubleshooting container issues:

```bash
# View container logs
docker logs <container_name>

# View last N lines of logs
docker logs --tail N <container_name>

# Follow logs in real-time
docker logs -f <container_name>

# Show logs since a specific time
docker logs --since 2023-03-30T00:00:00 <container_name>
```

### Container Inspection

Inspect container configuration and state:

```bash
# Inspect container
docker inspect <container_name>

# Get specific information
docker inspect --format '{{.State.Status}}' <container_name>
docker inspect --format '{{.NetworkSettings.Networks}}' <container_name>
docker inspect --format '{{.Mounts}}' <container_name>
```

### Interactive Debugging

Sometimes you need to get inside a container to debug:

```bash
# Start an interactive shell in a running container
docker exec -it <container_name> /bin/bash

# If bash is not available, try sh
docker exec -it <container_name> /bin/sh
```

### Network Debugging

Debug network connectivity issues:

```bash
# List networks
docker network ls

# Inspect network
docker network inspect <network_name>

# Connect container to network
docker network connect <network_name> <container_name>

# Disconnect container from network
docker network disconnect <network_name> <container_name>
```

## Preventive Measures

### Regular Maintenance

- Keep Docker and container images updated
- Monitor container health and logs
- Implement automated backups
- Document configuration changes

### Best Practices

- Use Docker Compose for complex deployments
- Implement health checks
- Use environment variables for configuration
- Follow the principle of least privilege
- Implement proper logging
- Use Docker volumes for persistent data
- Document your setup

### Monitoring

- Implement container monitoring
- Set up alerts for container issues
- Monitor resource usage
- Implement log aggregation

## Conclusion

Docker container troubleshooting can be complex, but with the right approach and tools, most issues can be resolved quickly. The scripts provided in this repository are designed to automate common troubleshooting tasks and fix specific issues with your containers.

If you encounter persistent issues, consider rebuilding your Docker environment from scratch using the cleanup and setup scripts:

```bash
sudo ./cleanup-docker.sh
sudo ./setup.sh
```

For more targeted troubleshooting, refer to the specific scripts for each container and the troubleshooting workflow outlined in the [TROUBLESHOOTING_SCRIPTS_SUMMARY.md](TROUBLESHOOTING_SCRIPTS_SUMMARY.md) document.
