# Server Automation Scripts

A comprehensive set of scripts for automating the setup and configuration of a Docker-based server with various services, including Caddy as a reverse proxy, Authelia for authentication, and multiple application containers.

## Overview

This project provides a set of scripts to automate the deployment of a self-hosted server with multiple services. The setup is interactive, prompting the user for necessary information and generating configuration files accordingly.

### Features

- **Interactive Setup**: Guides you through the entire setup process with prompts
- **Modular Design**: Enable only the services you need
- **Secure by Default**: Implements best practices for security
- **Automatic Configuration**: Generates all necessary configuration files
- **Resource Management**: Configure memory and CPU limits for each service
- **Health Monitoring**: Built-in health checks for all services
- **Backup Solution**: Integrated backup capabilities with Borgmatic

## Services Supported

- **Caddy**: Modern web server and reverse proxy with automatic HTTPS
- **Authelia**: Single sign-on multi-factor authentication server
- **MariaDB**: Relational database server
- **PostgreSQL**: Advanced open-source relational database
- **Redis**: In-memory data structure store
- **Vaultwarden**: Bitwarden-compatible password manager
- **Grafana**: Analytics and monitoring platform
- **Prometheus**: Monitoring system and time series database
- **DocMost**: Document collaboration platform
- **Code Server**: VS Code in the browser
- **Home Assistant**: Home automation platform
- **OwnCloud**: File sharing and collaboration platform
- **Portainer**: Container management UI
- **IT Tools**: Collection of useful IT tools
- **Loki**: Log aggregation system
- **Borgmatic**: Backup solution
- **WireGuard**: Modern VPN server

## Prerequisites

- Debian 12 or Ubuntu 22.04 LTS
- Docker and Docker Compose installed
- Root or sudo access
- Domain name with DNS configured

## Quick Start

1. Clone the repository:
   ```bash
   git clone https://github.com/osamarehman/mughal.pro.git
   cd mughal.pro
   ```

2. Make the setup script executable:
   ```bash
   chmod +x setup.sh
   ```

3. Run the setup script:
   ```bash
   ./setup.sh
   ```

4. Follow the interactive prompts to configure your server.

## Configuration

The setup script will guide you through the configuration process, including:

- Domain name setup
- Email configuration for Let's Encrypt
- Service selection
- Password and token generation
- Resource allocation

## Directory Structure

After setup, the following directory structure will be created:

```
/opt/docker/
├── authelia/
│   └── config/
├── borgmatic/
│   └── config/
├── caddy/
│   ├── config/
│   ├── data/
│   └── site/
├── compose/
│   └── docker-compose.yml
├── mariadb/
│   ├── config/
│   └── data/
├── postgres/
│   └── data/
├── redis/
│   └── data/
└── ... (other service directories)
```

## Customization

### Adding New Services

To add a new service:

1. Edit `docker-compose-services.sh` to add the service definition
2. Update `config-generator.sh` to add any necessary configuration files
3. Modify `setup.sh` to include prompts for the new service

### Modifying Existing Services

See [MODIFYING_APPS.md](MODIFYING_APPS.md) for detailed instructions on how to modify existing services.

## Troubleshooting

For common issues and their solutions, see [troubleshooting_checklist.md](troubleshooting_checklist.md).

## Backup and Restore

The setup includes Borgmatic for backups. By default, it's configured to:

- Back up all database data
- Back up all configuration files
- Run on a daily schedule

To customize the backup configuration, edit the Borgmatic configuration files in `/opt/docker/borgmatic/config/`.

## Security Considerations

- All passwords and tokens are generated securely during setup
- Authelia provides multi-factor authentication
- Services are isolated in their own networks
- Regular updates are recommended

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.
