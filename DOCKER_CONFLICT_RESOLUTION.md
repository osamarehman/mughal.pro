# Docker Container Conflict Resolution

## The Issue

When trying to run the setup script again, you encountered container name conflicts. This happens because Docker containers from previous runs still exist in the system, even if they're not running. The error message you saw was:

```
Error response from daemon: Conflict. The container name "/prometheus" is already in use by container "e2b7c451ab7d3ede40f57522a21e10476f008b24f66eaeb2c03171950e09f1fa". You have to remove (or rename) that container to be able to reuse that name.
```

When you ran `docker ps -a`, you could see several containers in the "Created" state, not running but still taking up the container names.

## The Solution

I've created a cleanup script (`cleanup-docker.sh`) that will:

1. Stop all running containers
2. Remove all containers (running or not)
3. Remove all custom Docker networks
4. Optionally remove all Docker volumes (with a warning about data loss)

This will give you a clean slate to start over with the setup script.

## How to Use the Cleanup Script

1. Make the script executable:
   ```bash
   chmod +x cleanup-docker.sh
   ```

2. Run the script:
   ```bash
   sudo ./cleanup-docker.sh
   ```

3. The script will ask for confirmation before proceeding:
   ```
   === Docker Cleanup Script ===

   INFO: This script will clean up your Docker environment
   WARNING: This will stop and remove all Docker containers and networks
   Do you want to continue? [y/N]:
   ```
   Type `y` and press Enter to continue.

4. The script will stop and remove all containers and networks.

5. The script will ask if you want to remove volumes:
   ```
   CAUTION: Removing volumes will DELETE ALL DATA stored in Docker volumes
   Do you want to remove all volumes? [y/N]:
   ```
   - If you want to keep your data (recommended), type `N` or just press Enter.
   - If you want to completely start fresh and don't mind losing data, type `y`.

6. After the cleanup is complete, you'll see:
   ```
   === Cleanup Complete ===

   SUCCESS: Your Docker environment has been cleaned up
   INFO: You can now run your setup script again
   ```

## Running the Setup Again

After cleaning up your Docker environment, you can run the setup script again:

```bash
sudo ./setup.sh
```

This time, the setup should proceed without any container name conflicts.

## Preventing Future Conflicts

To prevent similar issues in the future:

1. Always use `docker-compose down` to stop and remove containers when you're done with them.

2. If you're making changes to your setup, consider using the cleanup script first to ensure a clean environment.

3. If you want to keep your data but need to recreate containers, you can use:
   ```bash
   docker-compose down && docker-compose up -d
   ```
   This will stop and remove containers but keep volumes intact.

## Troubleshooting Authelia

If you still have issues with Authelia after running the setup again, you can:

1. Check the Authelia logs:
   ```bash
   docker logs authelia
   ```

2. If you see the same password hash error, you might need to modify the setup script to generate proper Argon2 hashes for Authelia.

3. Alternatively, you can disable Authelia in the docker-compose.yml file by commenting out the Authelia service section.
