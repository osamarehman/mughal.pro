# Authelia Authentication Notes

This document provides information about Authelia authentication issues and how to disable Authelia if needed.

## Understanding Authelia

Authelia is an open-source authentication and authorization server that provides single sign-on (SSO) capabilities for web applications. It acts as a portal in front of your applications, adding an authentication layer that protects your services.

## Common Authelia Issues

### Invalid Password Hash

The most common issue with Authelia is an invalid password hash format. This can happen when:

- The password hash is not in the correct format
- The password hash is corrupted
- The password hash is missing

Error message example:
```
error decoding the authentication database: error occurred decoding the password hash for 'admin': provided encoded hash has an invalid identifier: the identifier '' is unknown to the global decoder
```

### Redis Connection Issues

Authelia uses Redis for session storage. If Redis is not running or not accessible, Authelia will fail to start.

Error message example:
```
error connecting to redis: dial tcp: lookup redis on X.X.X.X:53: no such host
```

### Configuration Issues

Authelia has a complex configuration file that can be prone to syntax errors or invalid settings.

Error message example:
```
configuration key 'jwt_secret' is deprecated in 4.38.0 and has been replaced by 'identity_validation.reset_password.jwt_secret'
```

## Disabling Authelia

If you're experiencing issues with Authelia and want to disable it temporarily, follow these steps:

### 1. Remove Authelia from Docker Compose

Edit your Docker Compose file and comment out or remove the Authelia service:

```yaml
# authelia:
#   image: authelia/authelia:latest
#   container_name: authelia
#   restart: unless-stopped
#   ...
```

### 2. Remove Authelia Authentication from Caddy

Edit your Caddyfile and remove any Authelia authentication directives:

```
# Remove lines like these:
# forward_auth authelia:9091 {
#   uri /api/verify?rd=https://auth.example.com
# }
```

You can use the `fix-caddy-auth.sh` script to automatically remove Authelia authentication directives from your Caddy configuration:

```bash
sudo ./fix-caddy-auth.sh
```

### 3. Restart Caddy

After removing Authelia authentication directives, restart the Caddy container:

```bash
docker restart caddy
```

### 4. Verify Authentication is Disabled

Access your services directly to verify that authentication is no longer required.

## Re-enabling Authelia

If you want to re-enable Authelia after fixing the issues:

### 1. Fix Authelia Configuration

If the issue was with the password hash, you can use the `fix-authelia-hash.sh` script:

```bash
sudo ./fix-authelia-hash.sh
```

This script will:
- Create a new password hash for the admin user
- Update the Authelia configuration file with the new hash
- Restart the Authelia container

### 2. Uncomment Authelia in Docker Compose

Edit your Docker Compose file and uncomment the Authelia service:

```yaml
authelia:
  image: authelia/authelia:latest
  container_name: authelia
  restart: unless-stopped
  ...
```

### 3. Add Authelia Authentication to Caddy

Edit your Caddyfile and add Authelia authentication directives where needed:

```
forward_auth authelia:9091 {
  uri /api/verify?rd=https://auth.example.com
}
```

### 4. Restart Containers

Restart the affected containers:

```bash
docker-compose up -d
```

## Alternative Authentication Methods

If you decide not to use Authelia, there are alternative authentication methods you can consider:

### 1. Basic Authentication in Caddy

You can use Caddy's built-in basic authentication:

```
basicauth {
  user $2a$14$YOUR_HASHED_PASSWORD
}
```

### 2. Traefik with Forward Auth

If you're using Traefik instead of Caddy, you can configure forward authentication.

### 3. Application-Level Authentication

Rely on the built-in authentication mechanisms of your applications.

## Troubleshooting Authelia

If you want to continue using Authelia but need to troubleshoot issues:

### 1. Check Authelia Logs

```bash
docker logs authelia
```

### 2. Verify Redis Connection

Ensure Redis is running and accessible to Authelia:

```bash
docker ps | grep redis
docker logs redis
```

### 3. Check Network Connectivity

Ensure Authelia and Redis are on the same network:

```bash
docker inspect --format '{{range $key, $value := .NetworkSettings.Networks}}{{$key}} {{end}}' authelia
docker inspect --format '{{range $key, $value := .NetworkSettings.Networks}}{{$key}} {{end}}' redis
```

### 4. Validate Configuration

Check the Authelia configuration file for syntax errors:

```bash
docker exec -it authelia authelia validate-config
```

## Conclusion

Authelia provides robust authentication for your services, but it can be complex to configure and troubleshoot. If you're experiencing issues, you can temporarily disable Authelia using the steps outlined in this document.

For more comprehensive troubleshooting, refer to the [DOCKER_TROUBLESHOOTING_SOLUTION.md](DOCKER_TROUBLESHOOTING_SOLUTION.md) document and use the provided scripts to automate the troubleshooting process.
