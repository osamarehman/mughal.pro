# Docker Container Troubleshooting Scripts

This document provides a summary of all the troubleshooting scripts available in this repository and when to use them.

## Quick Start

1. Make all scripts executable:
   ```bash
   chmod +x make-scripts-executable.sh
   ./make-scripts-executable.sh
   ```

2. Run the comprehensive fix script:
   ```bash
   sudo ./fix-containers.sh
   ```

3. If specific containers are still having issues, use the targeted scripts below.

## Available Scripts

### General Scripts

| Script | Description | When to Use |
|--------|-------------|------------|
| `make-scripts-executable.sh` | Makes all troubleshooting scripts executable | Run this first before using any other scripts |
| `fix-containers.sh` | Comprehensive script that attempts to fix all container issues | Use this as your first troubleshooting step |
| `check-container-configs.sh` | Checks container configurations for common issues | Use to diagnose configuration problems |
| `cleanup-docker.sh` | Cleans up Docker resources (containers, volumes, networks) | Use when you want to start fresh |

### Container-Specific Scripts

| Script | Description | When to Use |
|--------|-------------|------------|
| `fix-caddy.sh` | Fixes issues with the Caddy container | When Caddy is restarting or not working properly |
| `fix-caddy-auth.sh` | Removes authentication directives from Caddy | When you're experiencing authentication issues |
| `fix-owncloud.sh` | Fixes issues with the ownCloud container | When ownCloud is restarting or not working properly |
| `fix-authelia-hash.sh` | Fixes invalid password hash issues in Authelia | When Authelia is failing due to hash errors |
| `fix-redis-config.sh` | Fixes Redis configuration issues | When Redis is restarting or not working properly |
| `fix-remaining-issues.sh` | Fixes remaining issues after running other scripts | When some containers are still not working |

### Setup Scripts

| Script | Description | When to Use |
|--------|-------------|------------|
| `setup.sh` | Main setup script that calls all other setup scripts | When you want to set up all containers from scratch |
| `setup-main.sh` | Sets up the main Docker environment | Part of the setup process |
| `setup-directories.sh` | Creates necessary directories for Docker containers | Part of the setup process |
| `setup-credentials.sh` | Sets up credentials for various services | Part of the setup process |
| `setup-services.sh` | Sets up Docker services | Part of the setup process |
| `setup-resources.sh` | Sets up resources for Docker services | Part of the setup process |
| `setup-utils.sh` | Sets up utility functions for other scripts | Part of the setup process |
| `setup-checks.sh` | Performs checks to ensure proper setup | Part of the setup process |

## Troubleshooting Workflow

1. **Initial Diagnosis**:
   ```bash
   docker ps -a
   ```
   Look for containers with status "Restarting" or "Exited".

2. **Check Container Logs**:
   ```bash
   docker logs <container_name>
   ```
   Look for error messages that indicate what's wrong.

3. **Run Comprehensive Fix**:
   ```bash
   sudo ./fix-containers.sh
   ```
   This script attempts to fix common issues with all containers.

4. **Fix Specific Containers**:
   If specific containers are still having issues, use the targeted scripts:
   ```bash
   sudo ./fix-caddy.sh        # For Caddy issues
   sudo ./fix-owncloud.sh     # For ownCloud issues
   sudo ./fix-authelia-hash.sh # For Authelia issues
   sudo ./fix-redis-config.sh # For Redis issues
   ```

5. **Fix Remaining Issues**:
   ```bash
   sudo ./fix-remaining-issues.sh
   ```
   This script attempts to fix any remaining issues.

6. **Clean Up and Start Fresh**:
   If all else fails, you can clean up and start fresh:
   ```bash
   sudo ./cleanup-docker.sh
   sudo ./setup.sh
   ```

## Common Issues and Solutions

### Authentication Issues

If you're experiencing authentication issues:

1. Run the Caddy authentication fix script:
   ```bash
   sudo ./fix-caddy-auth.sh
   ```

2. If Authelia is causing issues, check its logs:
   ```bash
   docker logs authelia
   ```

3. If you see hash errors, run:
   ```bash
   sudo ./fix-authelia-hash.sh
   ```

### Database Connection Issues

If containers can't connect to their databases:

1. Check if the database containers are running:
   ```bash
   docker ps | grep -E 'mariadb|postgres|mysql'
   ```

2. Run the ownCloud fix script to fix database connection issues:
   ```bash
   sudo ./fix-owncloud.sh
   ```

### Network Issues

If containers can't communicate with each other:

1. Check Docker networks:
   ```bash
   docker network ls
   ```

2. Run the comprehensive fix script:
   ```bash
   sudo ./fix-containers.sh
   ```

### Permission Issues

If containers have permission issues:

1. Check container logs for permission errors:
   ```bash
   docker logs <container_name> | grep "permission denied"
   ```

2. Run the container-specific fix script:
   ```bash
   sudo ./fix-caddy.sh        # For Caddy permission issues
   sudo ./fix-owncloud.sh     # For ownCloud permission issues
   ```

## Additional Resources

- `troubleshooting_checklist.md`: Step-by-step checklist for troubleshooting common Docker container issues
- `DOCKER_TROUBLESHOOTING_SOLUTION.md`: Comprehensive guide to troubleshooting Docker container issues
- `AUTHELIA_DISABLE_NOTES.md`: Information about disabling Authelia authentication
- `DOCKER_CONFLICT_RESOLUTION.md`: Guide to resolving Docker container conflicts
