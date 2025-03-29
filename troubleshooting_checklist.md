# Server Automation Troubleshooting Checklist

This checklist tracks progress on troubleshooting and fixing issues with the server automation scripts and Docker applications. Use this to keep track of completed tasks and what still needs to be done.

## Initial Analysis

- [x] Review log files to identify issues
- [x] Document identified problems in server_analysis_and_plan.md
- [x] Create troubleshooting plan

## Environment Setup

- [x] Set up Ubuntu test environment
  - [x] Install Docker and Docker Compose
  - [x] Create directory structure
  - [x] Copy configuration files
  - [x] Create Docker Compose file
  - [x] Configure Caddy
  - [x] Start services

## DNS Resolution Issues

- [x] Fix Docker Compose configuration
  - [x] Ensure all services referenced in Caddy are defined in Docker Compose
  - [x] Verify all services are on the same network
  - [x] Check container names match what's expected in Caddy
- [x] Test DNS resolution between containers
  - [x] Use `docker exec <container> ping <service>` to test connectivity
  - [x] Check Docker network configuration with `docker network inspect`

## Container Configuration

- [x] Add all required containers to Docker Compose
  - [x] code-server
  - [x] homeassistant
  - [x] owncloud
  - [x] portainer
  - [x] prometheus
  - [x] redis
  - [x] loki
  - [x] borgmatic
  - [x] wireguard
  - [x] ittools
- [x] Implement health checks for all services
- [x] Verify containers start successfully
  - [x] Check with `docker compose ps`
  - [x] Review logs with `docker compose logs`

## Service Configuration

### DocMost Configuration

- [x] Fix DocMost environment variables
  - [x] Set valid DATABASE_URL
  - [x] Set valid REDIS_URL
- [x] Ensure PostgreSQL container is running
- [x] Ensure Redis container is running
- [x] Test DocMost functionality

### Database Configuration

- [x] Update MariaDB configuration
  - [x] Set secure root password
  - [x] Create necessary databases and users
- [x] Update PostgreSQL configuration
  - [x] Set secure user password
  - [x] Create necessary databases
- [x] Update applications using databases with correct credentials
- [x] Test database connections

### Security Configuration

- [x] Generate secure admin tokens and passwords
  - [x] Use secure password generation for all services
  - [x] Generate Vaultwarden admin token
- [x] Update service configurations with secure credentials
- [x] Test admin interfaces

### Authelia Implementation

- [x] Set up Authelia
  - [x] Run authelia_setup_script.sh to generate configurations
  - [x] Add Authelia to Docker Compose
  - [x] Update Caddy configuration
- [x] Test Authelia authentication
  - [x] Access protected service
  - [x] Verify redirect to Authelia login
  - [x] Test login with generated credentials
  - [x] Verify redirect back to service after authentication

## Service Verification

- [x] Verify all services are running
  - [x] caddy
  - [x] authelia
  - [x] mariadb
  - [x] postgres
  - [x] redis
  - [x] vaultwarden
  - [x] grafana
  - [x] prometheus
  - [x] docmost
  - [x] code-server
  - [x] homeassistant
  - [x] owncloud
  - [x] portainer
  - [x] ittools
  - [x] loki
  - [x] borgmatic
  - [x] wireguard
- [x] Check service logs for errors
- [x] Test accessing services through Caddy

## Production Deployment

- [ ] Back up current production configuration
- [ ] Apply fixes to production environment
  - [ ] Update Docker Compose file
  - [ ] Update service configurations
  - [ ] Implement Authelia
  - [ ] Restart services
- [ ] Verify production services

## Monitoring and Maintenance

- [x] Set up monitoring
  - [x] Configure Prometheus
  - [x] Set up Grafana dashboards
  - [x] Implement Loki for log aggregation
  - [x] Configure alerting
- [x] Establish maintenance procedures
  - [x] Regular updates
  - [x] Backups with Borgmatic
  - [x] Log monitoring with Loki
  - [x] Log rotation

## Documentation

- [x] Create authelia_setup.md
- [x] Create authelia_setup_script.sh
- [x] Create ubuntu_test_environment_setup.md
- [x] Create server_analysis_and_plan.md
- [x] Create troubleshooting_checklist.md (this document)
- [x] Create README.md with project overview
- [x] Create MODIFYING_APPS.md with customization guide
- [x] Document final configuration
- [x] Create maintenance guide

## Reference Documents

- [README.md](README.md) - Project overview and quick start guide
- [MODIFYING_APPS.md](MODIFYING_APPS.md) - Guide for customizing services
- [Authelia Setup Guide](authelia_setup.md) - Detailed instructions for setting up Authelia
- [Authelia Setup Script](authelia_setup_script.sh) - Script to automate Authelia setup
- [Ubuntu Test Environment Setup](ubuntu_test_environment_setup.md) - Guide for setting up a test environment
- [Server Analysis and Plan](server_analysis_and_plan.md) - Analysis of issues and troubleshooting plan
- [Migration Script](migration_script.sh) - Script to automate migration and fixes

## Common Issues and Solutions

### Container Startup Issues

- **Issue**: Container fails to start
  - **Solution**: Check logs with `docker compose logs <service>`, verify configuration files, ensure dependencies are running

### Network Connectivity Issues

- **Issue**: Services can't communicate with each other
  - **Solution**: Verify services are on the same network, check Docker network configuration, test connectivity with ping

### Database Connection Issues

- **Issue**: Application can't connect to database
  - **Solution**: Verify database credentials, check database logs, ensure database service is healthy

### Authentication Issues

- **Issue**: Authelia authentication not working
  - **Solution**: Check Authelia logs, verify configuration, ensure Caddy is properly configured for authentication

### Resource Limitation Issues

- **Issue**: Service crashes due to resource constraints
  - **Solution**: Adjust memory and CPU limits in Docker Compose file, monitor resource usage

### Backup Issues

- **Issue**: Borgmatic backups failing
  - **Solution**: Check Borgmatic logs, verify configuration, ensure backup destination is accessible

### SSL/TLS Issues

- **Issue**: SSL certificates not being issued
  - **Solution**: Check Caddy logs, verify domain DNS settings, ensure ports 80 and 443 are accessible

## Notes

Use this section to add notes about progress, issues encountered, or additional tasks that need to be done.

- All scripts have been completed and tested in a development environment
- Health checks have been implemented for all services to improve reliability
- Monitoring and logging solutions are in place with Prometheus, Grafana, and Loki
- Backup solution is configured with Borgmatic
- Next step is to deploy to production and verify functionality

## How to Use This Checklist

1. Check off items as they are completed
2. Add notes about progress or issues
3. Refer to the reference documents for detailed instructions
4. Update the checklist as new tasks are identified

This checklist is a living document and should be updated as the troubleshooting and fixing process progresses.

## Testing Procedure

1. Clone the repository to a test environment
2. Run the setup script: `./setup.sh`
3. Follow the prompts to configure the server
4. Verify all services start correctly
5. Test accessing each service through its subdomain
6. Test authentication with Authelia
7. Test backup functionality
8. Check monitoring and logging

## Production Deployment Procedure

1. Back up the current production environment
2. Clone the repository to the production server
3. Run the setup script: `./setup.sh`
4. Follow the prompts to configure the server
5. Verify all services start correctly
6. Test accessing each service through its subdomain
7. Set up monitoring alerts
8. Configure regular backups
