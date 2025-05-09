# Custom Domain Configuration for Supabase

This document describes the custom domain configuration for the Supabase instance at `mybases.pl`.

## Overview

The Supabase instance has been configured to use the custom domain `mybases.pl` with SSL encryption provided by Let's Encrypt. This enables secure access to the Supabase API and dashboard through the custom domain.

## Initial Setup Instructions

This section provides detailed instructions for setting up a custom domain with SSL for a Supabase instance.

### Prerequisites

Before beginning the setup process, ensure you have:

1. A registered domain name (e.g., mybases.pl)
2. DNS configured to point to your server's IP address
3. Administrative access to the server
4. Docker and Docker Compose installed on your server

### Installation Steps

#### 1. Install Certbot (Let's Encrypt client)

Certbot is the official Let's Encrypt client that automates the process of obtaining and renewing SSL certificates:

```bash
# Update your package lists
sudo apt update

# Install Certbot
sudo apt install -y certbot
```

#### 2. Stop Kong temporarily to free port 80

To issue the certificate, Certbot needs to temporarily use port 80, which Kong normally occupies:

```bash
# Navigate to your Supabase directory
cd /path/to/supabase

# Stop the Kong container
docker compose stop kong
```

#### 3. Generate the Let's Encrypt certificate

```bash
# Generate the certificate with HTTP validation
sudo certbot certonly --standalone --preferred-challenges http \
  -d yourdomain.com -d www.yourdomain.com \
  --email your-email@example.com --agree-tos --non-interactive
```

Replace `yourdomain.com` with your actual domain and `your-email@example.com` with your email address.

#### 4. Create a shared directory for certificates

```bash
# Create a shared directory
sudo mkdir -p /etc/letsencrypt/shared

# Copy certificates to the shared directory
sudo cp -L /etc/letsencrypt/live/yourdomain.com/fullchain.pem /etc/letsencrypt/shared/
sudo cp -L /etc/letsencrypt/live/yourdomain.com/privkey.pem /etc/letsencrypt/shared/

# Set appropriate permissions
sudo chmod 644 /etc/letsencrypt/shared/fullchain.pem
sudo chmod 644 /etc/letsencrypt/shared/privkey.pem
```

#### 5. Update Kong configuration in docker-compose.yml

Edit your `docker-compose.yml` file to add the SSL configuration to the Kong service:

```yaml
kong:
  container_name: supabase-kong
  image: kong:2.8.1
  restart: unless-stopped
  ports:
    - ${KONG_HTTP_PORT}:8000/tcp
    - ${KONG_HTTPS_PORT}:8443/tcp
    - "80:8000/tcp"  # Direct HTTP mapping
    - "443:8443/tcp"  # Direct HTTPS mapping
  volumes:
    - ./volumes/api/kong.yml:/home/kong/temp.yml:ro,z
    - /etc/letsencrypt/shared:/etc/letsencrypt/shared:ro,z
  depends_on:
    analytics:
      condition: service_healthy
  environment:
    KONG_DATABASE: "off"
    KONG_DECLARATIVE_CONFIG: /home/kong/kong.yml
    KONG_DNS_ORDER: LAST,A,CNAME
    KONG_PLUGINS: request-transformer,cors,key-auth,acl,basic-auth
    KONG_NGINX_PROXY_PROXY_BUFFER_SIZE: 160k
    KONG_NGINX_PROXY_PROXY_BUFFERS: 64 160k
    KONG_SSL_CERT: /etc/letsencrypt/shared/fullchain.pem
    KONG_SSL_CERT_KEY: /etc/letsencrypt/shared/privkey.pem
    KONG_PROXY_LISTEN: "0.0.0.0:8000, 0.0.0.0:8443 ssl"
    KONG_SERVER_NAME: "yourdomain.com"
    SUPABASE_ANON_KEY: ${ANON_KEY}
    SUPABASE_SERVICE_KEY: ${SERVICE_ROLE_KEY}
    DASHBOARD_USERNAME: ${DASHBOARD_USERNAME}
    DASHBOARD_PASSWORD: ${DASHBOARD_PASSWORD}
  entrypoint: bash -c 'eval "echo \"$$(cat ~/temp.yml)\"" > ~/kong.yml && /docker-entrypoint.sh kong docker-start'
```

#### 6. Set up automatic certificate renewal

Create a renewal script:

```bash
cat > /path/to/supabase/renew-cert.sh << 'EOL'
#!/bin/bash

# Set up logging
LOGFILE="/var/log/letsencrypt-renew.log"
exec > >(tee -a $LOGFILE) 2>&1

echo "$(date): Starting certificate renewal..."

# Stop Kong to free port 80
echo "$(date): Stopping Kong container..."
cd /path/to/supabase
docker compose stop kong
if [ $? -ne 0 ]; then
  echo "$(date): Failed to stop Kong container."
  exit 1
fi

# Renew the certificate
echo "$(date): Running certbot renew..."
certbot renew --non-interactive
CERTBOT_EXIT=$?

# Copy renewed certificates to the shared directory
if [ $CERTBOT_EXIT -eq 0 ]; then
  echo "$(date): Copying certificates to shared directory..."
  cp -L /etc/letsencrypt/live/yourdomain.com/fullchain.pem /etc/letsencrypt/shared/
  cp -L /etc/letsencrypt/live/yourdomain.com/privkey.pem /etc/letsencrypt/shared/
  chmod 644 /etc/letsencrypt/shared/fullchain.pem
  chmod 644 /etc/letsencrypt/shared/privkey.pem
fi

# Start Kong back up
echo "$(date): Starting Kong container..."
cd /path/to/supabase
docker compose start kong
if [ $? -ne 0 ]; then
  echo "$(date): Failed to start Kong container."
  exit 1
fi

# Report status
if [ $CERTBOT_EXIT -eq 0 ]; then
  echo "$(date): Certificate renewal completed successfully."
else
  echo "$(date): Certificate renewal failed with exit code $CERTBOT_EXIT."
  exit $CERTBOT_EXIT
fi
EOL

chmod +x /path/to/supabase/renew-cert.sh
```

Add the renewal script to crontab to run twice monthly:

```bash
(crontab -l 2>/dev/null; echo "0 3 1,15 * * /path/to/supabase/renew-cert.sh") | crontab -
```

#### 7. Start Kong with the new configuration

```bash
cd /path/to/supabase
docker compose start kong
```

## Configuration Details

### Domain

- Primary domain: `mybases.pl`
- Subdomain: `www.mybases.pl`
- SSL Certificate: Let's Encrypt (valid for 90 days, auto-renewal configured)

### Access Details

- API Endpoint: `https://mybases.pl:8443/rest/v1/`
- Dashboard: `https://mybases.pl:8443/`

### Certificate Information

- Certificate provider: Let's Encrypt
- Certificate location: `/etc/letsencrypt/live/mybases.pl/`
- Shared certificate location: `/etc/letsencrypt/shared/`

## Maintenance Scripts

Several scripts have been created to help maintain the SSL configuration:

1. **Renewal Script**: `/home/bart/supabase/renew-cert.sh`
   - Automatically renews the Let's Encrypt certificate
   - Scheduled to run on the 1st and 15th of each month at 3 AM
   - Temporarily stops Kong, renews the certificate, and restarts Kong

2. **Backup Script**: `/home/bart/supabase/backup-ssl-config.sh`
   - Creates a backup of the SSL certificates and Kong configuration
   - Run this script before making changes to the SSL configuration

3. **Test Script**: `/home/bart/supabase/test-ssl.sh`
   - Tests the SSL configuration and certificate
   - Run this script to verify that SSL is working correctly

## Manual Certificate Renewal

If you need to manually renew the certificate, you can run:

```bash
sudo /home/bart/supabase/renew-cert.sh
```

## Troubleshooting

If you encounter issues with the SSL configuration:

1. Check the Kong logs:
   ```bash
   docker logs supabase-kong
   ```

2. Test the SSL configuration:
   ```bash
   ./test-ssl.sh mybases.pl
   ```

3. Verify the certificate files:
   ```bash
   sudo ls -la /etc/letsencrypt/shared/
   ```

4. If necessary, restore from a backup:
   ```bash
   # First, create a backup of the current configuration
   sudo ./backup-ssl-config.sh
   
   # Then copy the backup files to the appropriate locations
   ```

## Security Recommendations

- Regularly check certificate validity
- Monitor the automatic renewal process
- Keep the renewal script updated with the latest domain information
- Consider implementing HTTP Strict Transport Security (HSTS) for enhanced security

## Testing SSL Configuration

After completing the setup, it's important to verify your SSL configuration. We've created a test script for this purpose:

```bash
cat > /path/to/supabase/test-ssl.sh << 'EOL'
#!/bin/bash

# Function to check domain
check_domain() {
  local domain=$1
  echo "Testing $domain..."
  
  # Check HTTPS availability
  echo "  - Testing HTTPS availability..."
  if curl -s --head -o /dev/null --fail "https://$domain:8443"; then
    echo "    ✅ HTTPS is working"
  else
    echo "    ❌ HTTPS is not working"
  fi
  
  # Check SSL certificate
  echo "  - Checking SSL certificate..."
  CERT_INFO=$(echo | openssl s_client -servername $domain -connect $domain:8443 2>/dev/null | openssl x509 -noout -subject -dates)
  if [ ! -z "$CERT_INFO" ]; then
    echo "    ✅ SSL certificate is valid"
    echo "    $CERT_INFO" | sed 's/^/      /'
  else
    echo "    ❌ Could not retrieve SSL certificate information"
  fi
}

# Main testing function
main() {
  echo "========================================"
  echo "    Supabase SSL Configuration Tester"
  echo "========================================"
  echo ""
  
  # Get domain(s) to test from arguments or ask
  if [ $# -eq 0 ]; then
    read -p "Enter your domain name (e.g., mybases.pl): " DOMAIN
    if [ -z "$DOMAIN" ]; then
      echo "Error: Domain name cannot be empty"
      exit 1
    fi
    
    read -p "Include www subdomain? (y/n): " INCLUDE_WWW
    if [[ "$INCLUDE_WWW" == "y" || "$INCLUDE_WWW" == "Y" ]]; then
      DOMAINS=("$DOMAIN" "www.$DOMAIN")
    else
      DOMAINS=("$DOMAIN")
    fi
  else
    DOMAINS=("$@")
  fi
  
  # Test each domain
  for domain in "${DOMAINS[@]}"; do
    check_domain $domain
    echo ""
  done
  
  # Test Kong health
  echo "Testing Kong configuration..."
  if docker exec supabase-kong kong health 2>/dev/null | grep -q "Kong is healthy"; then
    echo "  ✅ Kong is healthy"
  else
    echo "  ❌ Kong health check failed"
  fi
  
  echo ""
  echo "SSL Test completed."
}

# Run the main function
main "$@"
EOL

chmod +x /path/to/supabase/test-ssl.sh
```

To run the test:

```bash
./test-ssl.sh yourdomain.com
```

### Backup Configuration

It's a good practice to backup your SSL configuration before making changes. We've created a backup script:

```bash
cat > /path/to/supabase/backup-ssl-config.sh << 'EOL'
#!/bin/bash

# Create backup directory
BACKUP_DIR="/etc/letsencrypt/backups/$(date +%Y%m%d-%H%M%S)"
mkdir -p $BACKUP_DIR

# Backup certificates
echo "Backing up Let's Encrypt certificates..."
cp -r /etc/letsencrypt/live /etc/letsencrypt/archive $BACKUP_DIR/

# Backup Kong configuration
echo "Backing up Kong configuration..."
cp /path/to/supabase/docker-compose.yml $BACKUP_DIR/
cp /path/to/supabase/volumes/api/kong.yml $BACKUP_DIR/

echo "Backup completed: $BACKUP_DIR"
EOL

chmod +x /path/to/supabase/backup-ssl-config.sh
```

To create a backup:

```bash
sudo ./backup-ssl-config.sh
```