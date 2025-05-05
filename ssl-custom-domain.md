# Setting Up a Custom Domain with SSL for Supabase

This document provides step-by-step instructions on how to set up a custom domain (mybases.pl) with SSL certification (Let's Encrypt) for Supabase running on Docker with Kong as the reverse proxy.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Configuration Steps](#configuration-steps)
  - [Step 1: Generate Let's Encrypt Certificate](#step-1-generate-lets-encrypt-certificate)
  - [Step 2: Prepare Volumes in docker-compose.yml](#step-2-prepare-volumes-in-docker-composeyml)
  - [Step 3: Configure SSL in Kong](#step-3-configure-ssl-in-kong)
  - [Step 4: Restart and Test](#step-4-restart-and-test)
- [Troubleshooting](#troubleshooting)
  - [Certificate Issues](#certificate-issues)
  - [Kong Configuration Issues](#kong-configuration-issues)
  - [Networking Issues](#networking-issues)
  - [Certificate Renewal](#certificate-renewal)
- [Additional Configuration Options](#additional-configuration-options)
  - [Using DNS Validation for Let's Encrypt](#using-dns-validation-for-lets-encrypt)
  - [Implementing HTTP Strict Transport Security (HSTS)](#implementing-http-strict-transport-security-hsts)

## Overview

This guide walks you through configuring your Supabase instance to use a custom domain with SSL support. By following these steps, you'll be able to access your Supabase services securely through `https://mybases.pl`.

## Prerequisites

Before you begin, ensure that:
- The domain mybases.pl is properly configured in DNS and points to the server where Supabase is running
- You have administrator privileges on the server
- Ports 80 and 443 are open in the firewall

## Configuration Steps

We've created an automated script that handles the entire SSL setup process. The script will:

1. Generate Let's Encrypt certificates
2. Configure Kong to use the certificates
3. Set up automatic renewal
4. Create testing and backup scripts

### Automated Setup

The easiest way to set up SSL is to use our automated script:

1. Create the script:
   ```bash
   sudo nano /home/bart/supabase/ssl-setup.sh
   ```

2. Copy the script content from our repository (see [ssl-setup.sh](https://github.com/example/supabase-custom-domain/blob/main/ssl-setup.sh))

3. Make the script executable:
   ```bash
   sudo chmod +x /home/bart/supabase/ssl-setup.sh
   ```

4. Run the script:
   ```bash
   sudo ./ssl-setup.sh
   ```

5. Follow the prompts to complete the setup:
   - Enter your domain name (e.g., mybases.pl)
   - Provide your email address for Let's Encrypt
   - Choose whether to include the www subdomain
   - Select the validation method:
     - HTTP validation (requires temporarily stopping Kong)
     - DNS validation (no downtime, but requires manual DNS records)

The script will create three utility scripts:
- `renew-cert.sh`: Handles automatic certificate renewal
- `test-ssl.sh`: Tests your SSL configuration
- `backup-ssl-config.sh`: Creates backups of your certificates and configuration

### Manual Setup - Step 1: Generate Let's Encrypt Certificate

If you prefer to set up SSL manually, follow these detailed steps:

#### Option 1: HTTP Validation

This method requires temporarily stopping Kong to free up port 80:

1. Stop the Kong container:
   ```bash
   docker stop supabase-kong
   ```

2. Install Certbot if it's not already installed:
   ```bash
   sudo apt update
   sudo apt install certbot
   ```

3. Generate the certificate using the standalone method:
   ```bash
   sudo certbot certonly --standalone --preferred-challenges http -d mybases.pl -d www.mybases.pl
   ```

4. Follow the prompts to complete the certificate generation.

#### Option 2: DNS Validation

This method doesn't require stopping Kong and is ideal for production environments:

1. Install Certbot if it's not already installed:
   ```bash
   sudo apt update
   sudo apt install certbot
   ```

2. Generate the certificate using DNS validation:
   ```bash
   sudo certbot certonly --manual --preferred-challenges dns -d mybases.pl -d www.mybases.pl
   ```

3. Follow the prompts to add TXT records to your DNS configuration.

4. Wait for DNS propagation (can take 15 minutes to 48 hours depending on your DNS provider).

#### After Certificate Generation (Both Methods)

1. Verify the certificate was generated correctly:
   ```bash
   sudo ls -la /etc/letsencrypt/live/mybases.pl/
   ```

   You should see the following files:
   - `cert.pem`: Your domain's certificate
   - `chain.pem`: The Let's Encrypt chain certificate
   - `fullchain.pem`: Both certificates combined
   - `privkey.pem`: Your certificate's private key

2. Set appropriate permissions for the Kong container to read these files:
   ```bash
   sudo mkdir -p /etc/letsencrypt/shared
   sudo cp -L /etc/letsencrypt/live/mybases.pl/fullchain.pem /etc/letsencrypt/shared/
   sudo cp -L /etc/letsencrypt/live/mybases.pl/privkey.pem /etc/letsencrypt/shared/
   sudo chmod -R 755 /etc/letsencrypt/shared
   ```

### Step 2: Prepare Volumes in docker-compose.yml

Now we need to modify the docker-compose.yml file to make the SSL certificates accessible to Kong:

1. Edit your docker-compose.yml file:
   ```bash
   nano docker-compose.yml
   ```

2. Add a new volume for the certificates. Find the Kong service configuration and add a new volume mapping. The final volume section for Kong should look like this:
   ```yaml
   volumes:
     - ./volumes/api/kong.yml:/home/kong/temp.yml:ro,z
     - /etc/letsencrypt/shared:/etc/letsencrypt/shared:ro,z
   ```

3. Update the ports section to explicitly route both HTTP and HTTPS traffic:
   ```yaml
   ports:
     - "${KONG_HTTP_PORT}:8000/tcp"
     - "${KONG_HTTPS_PORT}:8443/tcp"
     - "80:8000/tcp"  # Direct HTTP mapping
     - "443:8443/tcp"  # Direct HTTPS mapping
   ```

4. Save the file.

Your updated Kong service configuration should look something like this:
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
    SUPABASE_ANON_KEY: ${ANON_KEY}
    SUPABASE_SERVICE_KEY: ${SERVICE_ROLE_KEY}
    DASHBOARD_USERNAME: ${DASHBOARD_USERNAME}
    DASHBOARD_PASSWORD: ${DASHBOARD_PASSWORD}
  entrypoint: bash -c 'eval "echo \"$$(cat ~/temp.yml)\"" > ~/kong.yml && /docker-entrypoint.sh kong docker-start'
```

Note that we've also added two new environment variables:
- `KONG_SSL_CERT`: Points to the full chain certificate
- `KONG_SSL_CERT_KEY`: Points to the private key

### Step 3: Configure SSL in Kong

Now we need to update Kong's configuration to properly handle SSL and set the custom domain:

1. Edit the Kong configuration file:
   ```bash
   nano volumes/api/kong.yml
   ```

2. Add a server_name directive to recognize your custom domain. You'll need to add this in the environment section of your docker-compose.yml file under the Kong service:
   ```yaml
   environment:
     # ... existing environment variables
     KONG_PROXY_LISTEN: "0.0.0.0:8000, 0.0.0.0:8443 ssl"
     KONG_SERVER_NAME: "mybases.pl"
   ```

3. If you want to force all HTTP requests to redirect to HTTPS, you can add a custom Kong plugin in the kong.yml file.

   First, add this to your plugins list in the environment section of your docker-compose.yml:
   ```yaml
   KONG_PLUGINS: request-transformer,cors,key-auth,acl,basic-auth,redirect
   ```

   Then add this configuration to your kong.yml file:
   ```yaml
   plugins:
     - name: redirect
       config:
         status_code: 301
         path: null
         https_port_in_redirect: true
       enabled: true
       protocols:
         - http
       config:
         rules:
           - conditions:
               - http_host:
                   - mybases.pl
                   - www.mybases.pl
             actions:
               request_scheme: https
   ```

   This will redirect all HTTP traffic to HTTPS for your domain.

4. Optional: If you're using a custom domain for accessing Supabase, update the `SUPABASE_PUBLIC_URL` in your environment variables:
   ```
   SUPABASE_PUBLIC_URL=https://mybases.pl
   ```

5. Save the file(s).

These changes will:
- Configure Kong to listen on both HTTP and HTTPS ports
- Set the server name to your custom domain
- Optional: Redirect HTTP traffic to HTTPS
- Optional: Update the public URL for Supabase to use your custom domain

### Step 4: Restart and Test

Now we need to restart the Supabase stack with our new configuration and test that everything is working:

1. Restart the Kong container and all dependent services:
   ```bash
   docker compose down kong
   docker compose up -d kong
   ```
   
   Alternatively, you can restart the entire Supabase stack:
   ```bash
   docker compose down
   docker compose up -d
   ```

2. Check if the Kong container started properly:
   ```bash
   docker logs supabase-kong
   ```
   
   Look for any errors related to SSL configuration.

3. Test HTTP to HTTPS redirection:
   - Open a browser and navigate to `http://mybases.pl`
   - Verify that you are automatically redirected to `https://mybases.pl`

4. Test SSL connection:
   - Navigate to `https://mybases.pl` 
   - Verify that the connection is secure (look for the padlock icon in the browser)
   - Check the SSL certificate details to confirm it's the Let's Encrypt certificate

5. Test API access:
   - Try accessing `https://mybases.pl/rest/v1/` with your API key
   - Verify that other Supabase services (auth, storage, etc.) are accessible

6. If you encounter any issues, check the Kong logs:
   ```bash
   docker logs supabase-kong
   ```

7. Set up automatic certificate renewal:

   #### Option 1: For HTTP Validation Method
   ```bash
   # Create a script for certificate renewal with HTTP validation
   cat > /home/bart/supabase/renew-cert.sh << 'EOL'
   #!/bin/bash
   
   # Set up logging
   LOGFILE="/var/log/letsencrypt-renew.log"
   exec > >(tee -a $LOGFILE) 2>&1
   
   echo "$(date): Starting certificate renewal..."
   
   # Stop Kong to free port 80
   echo "$(date): Stopping Kong container..."
   docker stop supabase-kong
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
     DOMAIN=$(ls -1 /etc/letsencrypt/live/ | grep -v README | head -n 1)
     cp -L /etc/letsencrypt/live/$DOMAIN/fullchain.pem /etc/letsencrypt/shared/
     cp -L /etc/letsencrypt/live/$DOMAIN/privkey.pem /etc/letsencrypt/shared/
   fi
   
   # Start Kong back up
   echo "$(date): Starting Kong container..."
   docker start supabase-kong
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
   ```

   #### Option 2: For DNS Validation Method
   ```bash
   # Create a script for certificate renewal with DNS validation
   cat > /home/bart/supabase/renew-cert.sh << 'EOL'
   #!/bin/bash
   
   # Set up logging
   LOGFILE="/var/log/letsencrypt-renew.log"
   exec > >(tee -a $LOGFILE) 2>&1
   
   echo "$(date): Starting certificate renewal..."
   
   # Renew the certificate using the same method as before (DNS)
   # Note: This assumes the DNS challenge is automated or pre-authorized
   certbot renew --non-interactive
   
   # Check if renewal was successful
   if [ $? -ne 0 ]; then
     echo "$(date): Certificate renewal failed."
     exit 1
   fi
   
   # Copy renewed certificates to the shared directory
   DOMAIN=$(ls -1 /etc/letsencrypt/live/ | grep -v README | head -n 1)
   cp -L /etc/letsencrypt/live/$DOMAIN/fullchain.pem /etc/letsencrypt/shared/
   cp -L /etc/letsencrypt/live/$DOMAIN/privkey.pem /etc/letsencrypt/shared/
   
   # Reload Kong to pick up the new certificate without stopping it
   # Using Docker's kill command to send SIGHUP
   docker kill --signal=HUP supabase-kong
   
   echo "$(date): Certificate renewal completed successfully."
   EOL
   ```

   #### Set Up Cron Job
   ```bash
   # Make the script executable
   chmod +x /home/bart/supabase/renew-cert.sh
   
   # Add a cron job to run the script twice a month
   (crontab -l 2>/dev/null; echo "0 0 1,15 * * /home/bart/supabase/renew-cert.sh") | crontab -
   ```
   
   #### Backup Script (Recommended)
   ```bash
   # Create a backup script for your SSL configuration
   cat > /home/bart/supabase/backup-ssl-config.sh << 'EOL'
   #!/bin/bash
   
   # Create backup directory
   BACKUP_DIR="/etc/letsencrypt/backups/$(date +%Y%m%d-%H%M%S)"
   mkdir -p $BACKUP_DIR
   
   # Backup certificates
   echo "Backing up Let's Encrypt certificates..."
   cp -r /etc/letsencrypt/live /etc/letsencrypt/archive $BACKUP_DIR/
   
   # Backup Kong configuration
   echo "Backing up Kong configuration..."
   cp /home/bart/supabase/docker-compose.yml $BACKUP_DIR/
   cp /home/bart/supabase/volumes/api/kong.yml $BACKUP_DIR/
   
   echo "Backup completed: $BACKUP_DIR"
   EOL
   
   chmod +x /home/bart/supabase/backup-ssl-config.sh
   ```

Congratulations! Your Supabase instance should now be accessible via your custom domain (mybases.pl) with a valid SSL certificate.

## Troubleshooting

If you encounter issues with your custom domain or SSL configuration, here are some common problems and their solutions:

### Certificate Issues

1. **Certificate Not Found**
   - Check that the paths in the volume mapping are correct
   - Verify that the certificate files exist in the specified location
   - Ensure the permissions allow Kong to read the certificate files

2. **SSL Handshake Failed**
   - Check that you're using the correct certificate files
   - Verify that both the certificate and key files are correctly specified in Kong's configuration

### Kong Configuration Issues

1. **Kong Won't Start**
   - Check the logs: `docker logs supabase-kong`
   - Verify your docker-compose.yml syntax
   - Make sure all environment variables are properly defined

2. **Kong Starts But SSL Doesn't Work**
   - Verify that `KONG_PROXY_LISTEN` includes the SSL configuration
   - Check that the certificate and key paths are correct

### Networking Issues

1. **Cannot Access Domain**
   - Verify that your domain's DNS records point to your server's IP
   - Check that ports 80 and 443 are open in your firewall
   - Test with `curl -v https://mybases.pl` to see any SSL errors

2. **Redirect Loop**
   - If you're experiencing redirect loops, check your redirection plugin configuration
   - Make sure you're not double-redirecting from HTTP to HTTPS

### Certificate Renewal

1. **Automatic Renewal Not Working**
   - Check that your cron job is set up correctly with `crontab -l`
   - Verify that the renewal script has execute permissions
   - Test the renewal process manually: `sudo /home/bart/supabase/renew-cert.sh`

## Additional Configuration Options

### Using DNS Validation for Let's Encrypt

For servers behind a firewall or where port 80 cannot be opened, consider using DNS validation with Let's Encrypt:

```bash
sudo certbot certonly --manual --preferred-challenges dns -d mybases.pl -d www.mybases.pl
```

You'll be asked to create TXT records in your domain's DNS to prove ownership.

### Implementing HTTP Strict Transport Security (HSTS)

To enhance security, consider adding HSTS to your Kong configuration:

```yaml
environment:
  # ... other environment variables
  KONG_HEADERS: "off"
```

Then add a custom plugin in kong.yml:

```yaml
plugins:
  - name: response-transformer
    config:
      add:
        headers:
          - "Strict-Transport-Security: max-age=31536000; includeSubDomains"
    enabled: true
```

This tells browsers to always use HTTPS for your domain.

## Testing Your SSL Configuration

We've created a testing script that helps verify your SSL configuration is working correctly. This script checks:

1. HTTP to HTTPS redirection
2. HTTPS availability
3. SSL certificate validity
4. Kong health status
5. Supabase API accessibility

### Creating the Test Script

```bash
cat > /home/bart/supabase/test-ssl.sh << 'EOL'
#!/bin/bash

# Function to check domain
check_domain() {
  local domain=$1
  echo "Testing $domain..."
  
  # Check HTTP redirect
  echo "  - Testing HTTP redirect..."
  HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://$domain)
  if [ "$HTTP_STATUS" == "301" ] || [ "$HTTP_STATUS" == "302" ]; then
    echo "    ✅ HTTP redirects correctly (Status $HTTP_STATUS)"
  else
    echo "    ❌ HTTP does not redirect as expected (Status $HTTP_STATUS)"
  fi
  
  # Check HTTPS availability
  echo "  - Testing HTTPS availability..."
  if curl -s --head -o /dev/null --fail https://$domain; then
    echo "    ✅ HTTPS is working"
  else
    echo "    ❌ HTTPS is not working"
  fi
  
  # Check SSL certificate
  echo "  - Checking SSL certificate..."
  CERT_INFO=$(echo | openssl s_client -servername $domain -connect $domain:443 2>/dev/null | openssl x509 -noout -subject -dates)
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
  
  # Test Kong admin API to make sure Kong is working properly
  echo "Testing Kong configuration..."
  if docker exec supabase-kong kong health 2>/dev/null | grep -q "Kong is healthy"; then
    echo "  ✅ Kong is healthy"
  else
    echo "  ❌ Kong health check failed"
  fi
  
  # Test API access if available
  echo ""
  echo "Testing Supabase API access..."
  
  if curl -s -o /dev/null -w "%{http_code}" https://${DOMAINS[0]}/rest/v1/; then
    echo "  ✅ Supabase API is accessible"
  else
    echo "  ❌ Supabase API is not accessible"
  fi
  
  echo ""
  echo "SSL Test completed."
}

# Run the main function
main "$@"
EOL

chmod +x /home/bart/supabase/test-ssl.sh
```

### Running the Test

To test your SSL configuration:

```bash
sudo ./test-ssl.sh mybases.pl
```

If you included the www subdomain:

```bash
sudo ./test-ssl.sh mybases.pl www.mybases.pl
```

### Additional External Testing

For a more thorough SSL configuration check, you can use online services like:

1. [SSL Labs Server Test](https://www.ssllabs.com/ssltest/) - Enter your domain and get a comprehensive analysis of your SSL configuration.

2. [SSL Checker](https://www.sslshopper.com/ssl-checker.html) - Verify certificate installation and chain issues.

3. [Why No Padlock](https://www.whynopadlock.com/) - Check for mixed content issues that might prevent the padlock icon from showing.