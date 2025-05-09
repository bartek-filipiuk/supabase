#!/bin/bash
# Script to set up SSL for Supabase with Let's Encrypt

# Exit on error
set -e

# Function to check if a command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Function to display steps
step() {
  echo "➡️ $1"
}

# Function to display success
success() {
  echo "✅ $1"
}

# Function to display errors
error() {
  echo "❌ $1"
  exit 1
}

# Display usage
usage() {
  cat << EOF
Usage: $0 [options]

Options:
  -d, --domain DOMAIN         Domain name (e.g., mybases.pl)
  -e, --email EMAIL           Email address for Let's Encrypt notices
  -w, --www                   Include www subdomain
  -m, --method METHOD         Validation method: http or dns (default: http)
  -n, --non-interactive       Run in non-interactive mode (requires -d and -e)
  -t, --test                  Test mode: validate configuration without generating certificates
  -h, --help                  Show this help message

Examples:
  $0 -d mybases.pl -e user@example.com -w -m http
  $0 --domain mybases.pl --email user@example.com --www --method dns

EOF
  exit 1
}

# Parse command line arguments
DOMAIN=""
EMAIL=""
INCLUDE_WWW="n"
VALIDATION_METHOD="1"
NON_INTERACTIVE=false
TEST_MODE=false

while [[ $# -gt 0 ]]; do
  case $1 in
    -d|--domain)
      DOMAIN="$2"
      shift 2
      ;;
    -e|--email)
      EMAIL="$2"
      shift 2
      ;;
    -w|--www)
      INCLUDE_WWW="y"
      shift
      ;;
    -m|--method)
      if [[ "$2" == "dns" ]]; then
        VALIDATION_METHOD="2"
      else
        VALIDATION_METHOD="1"
      fi
      shift 2
      ;;
    -n|--non-interactive)
      NON_INTERACTIVE=true
      shift
      ;;
    -t|--test)
      TEST_MODE=true
      shift
      ;;
    -h|--help)
      usage
      ;;
    *)
      echo "Unknown option: $1"
      usage
      ;;
  esac
done

# Display header
echo "======================================================"
echo "   Supabase Custom Domain SSL Setup with Let's Encrypt"
echo "======================================================"
echo ""

# Check if run as root
if [ "$(id -u)" -ne 0 ]; then
  error "This script must be run as root (use sudo)"
fi

# If non-interactive mode, check required parameters
if [ "$NON_INTERACTIVE" = true ]; then
  if [ -z "$DOMAIN" ] || [ -z "$EMAIL" ]; then
    error "In non-interactive mode, domain (-d) and email (-e) are required"
  fi
else
  # Interactive mode - ask for details if not provided
  if [ -z "$DOMAIN" ]; then
    read -p "Enter your domain name (e.g., mybases.pl): " DOMAIN
    if [ -z "$DOMAIN" ]; then
      error "Domain name cannot be empty"
    fi
  fi

  if [ -z "$EMAIL" ]; then
    read -p "Enter your email (for Let's Encrypt): " EMAIL
    if [ -z "$EMAIL" ]; then
      error "Email cannot be empty"
    fi
  fi

  if [[ "$INCLUDE_WWW" != "y" && "$INCLUDE_WWW" != "Y" ]]; then
    read -p "Include www subdomain? (y/n): " INCLUDE_WWW
  fi

  if [[ "$VALIDATION_METHOD" != "1" && "$VALIDATION_METHOD" != "2" ]]; then
    echo ""
    echo "Choose Let's Encrypt validation method:"
    echo "1) HTTP validation (requires port 80 to be free, Kong will be temporarily stopped)"
    echo "2) DNS validation (no downtime, but requires manual DNS record creation)"
    read -p "Select option (1/2): " VALIDATION_METHOD
  fi
fi

# Configure domain arguments
if [[ "$INCLUDE_WWW" == "y" || "$INCLUDE_WWW" == "Y" ]]; then
  DOMAIN_ARGS="-d $DOMAIN -d www.$DOMAIN"
  success "Will include www.$DOMAIN"
else
  DOMAIN_ARGS="-d $DOMAIN"
  success "Will only use $DOMAIN without www"
fi

# Configure validation method
if [ "$VALIDATION_METHOD" == "2" ]; then
  USE_DNS=true
  success "Using DNS validation method"
else
  USE_DNS=false
  success "Using HTTP validation method"
fi

# Check Docker is running
step "Checking if Docker is running..."
if ! docker info > /dev/null 2>&1; then
  error "Docker is not running or not accessible"
fi
success "Docker is running"

# Check if Supabase is running
step "Checking if Supabase is running..."
if ! docker compose ps | grep supabase-kong > /dev/null 2>&1; then
  error "Supabase Kong container is not running. Make sure Supabase is started."
fi
success "Supabase Kong container is running"

# Install certbot if not already installed
step "Checking if certbot is installed..."
if ! command_exists certbot; then
  step "Installing certbot..."
  apt-get update
  apt-get install -y certbot
fi
success "Certbot is installed"

# Generate certificate
step "Generating Let's Encrypt certificate for $DOMAIN..."

if [ "$TEST_MODE" == "true" ]; then
  echo "TEST MODE: Skipping actual certificate generation."
  echo "Creating mock certificate structure for testing..."
  
  # Ensure directory exists
  mkdir -p /etc/letsencrypt/live/$DOMAIN
  
  # Generate self-signed test certificate
  openssl req -x509 -newkey rsa:2048 -sha256 -days 3650 -nodes \
    -keyout /etc/letsencrypt/live/$DOMAIN/privkey.pem \
    -out /etc/letsencrypt/live/$DOMAIN/fullchain.pem \
    -subj "/CN=$DOMAIN" \
    -addext "subjectAltName=DNS:$DOMAIN,DNS:www.$DOMAIN"
    
  # Create other expected files
  cp /etc/letsencrypt/live/$DOMAIN/fullchain.pem /etc/letsencrypt/live/$DOMAIN/cert.pem
  cp /etc/letsencrypt/live/$DOMAIN/fullchain.pem /etc/letsencrypt/live/$DOMAIN/chain.pem
elif [ "$USE_DNS" == "true" ]; then
  echo "You'll need to add a TXT record to your DNS configuration."
  echo "This allows Let's Encrypt to verify you control the domain without stopping Kong."
  echo ""
  
  certbot certonly --manual --preferred-challenges dns $DOMAIN_ARGS --agree-tos --email $EMAIL || error "Failed to generate certificate"
  
  echo ""
  echo "Waiting for DNS propagation to complete..."
  echo "Press Enter when you have added all the required TXT records and they have propagated."
  read -p "Continue? " confirmation
else
  # Stop Kong to free up port 80
  step "Stopping Kong container to free up port 80..."
  docker stop supabase-kong || error "Failed to stop Kong container"
  success "Kong container stopped"
  
  certbot certonly --standalone --preferred-challenges http $DOMAIN_ARGS --agree-tos --email $EMAIL --non-interactive || error "Failed to generate certificate"
fi

success "Certificate generated successfully"

# Create shared directory for certificates
step "Setting up certificate directory..."
mkdir -p /etc/letsencrypt/shared || error "Failed to create shared directory"
success "Certificate directory created"

# Copy certificates
step "Copying certificates to shared directory..."
cp -L /etc/letsencrypt/live/$DOMAIN/fullchain.pem /etc/letsencrypt/shared/ || error "Failed to copy fullchain.pem"
cp -L /etc/letsencrypt/live/$DOMAIN/privkey.pem /etc/letsencrypt/shared/ || error "Failed to copy privkey.pem"
chmod -R 755 /etc/letsencrypt/shared || error "Failed to set permissions"
success "Certificates copied to shared directory"

# Create backup of docker-compose.yml
step "Creating backup of docker-compose.yml..."
cp docker-compose.yml docker-compose.yml.bak || error "Failed to backup docker-compose.yml"
success "Backup created: docker-compose.yml.bak"

# Update docker-compose.yml
step "Updating docker-compose.yml with SSL configuration..."
cat > kong-ssl-config.yml << EOF
  kong:
    container_name: supabase-kong
    image: kong:2.8.1
    restart: unless-stopped
    ports:
      - \${KONG_HTTP_PORT}:8000/tcp
      - \${KONG_HTTPS_PORT}:8443/tcp
      - "80:8000/tcp"
      - "443:8443/tcp"
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
      KONG_SERVER_NAME: "$DOMAIN"
      SUPABASE_ANON_KEY: \${ANON_KEY}
      SUPABASE_SERVICE_KEY: \${SERVICE_ROLE_KEY}
      DASHBOARD_USERNAME: \${DASHBOARD_USERNAME}
      DASHBOARD_PASSWORD: \${DASHBOARD_PASSWORD}
    entrypoint: >
      bash -c 'cp /home/kong/temp.yml /home/kong/kong.yml && /docker-entrypoint.sh kong docker-start'
EOF
success "Kong SSL configuration created"

# Update kong.yml to add redirect plugin
step "Updating Kong configuration for HTTP to HTTPS redirect..."
cp ./volumes/api/kong.yml ./volumes/api/kong.yml.bak || error "Failed to backup kong.yml"

# Note: We're commenting out the redirect plugin since it's not installed by default
# If you need HTTP to HTTPS redirect, you'll need to install the plugin first

# Add a comment to kong.yml about HTTP to HTTPS redirection
if ! grep -q "# HTTP to HTTPS redirection" ./volumes/api/kong.yml; then
  cat >> ./volumes/api/kong.yml << EOF

# HTTP to HTTPS redirection
# Note: To enable HTTP to HTTPS redirection, uncomment the following and install the redirect plugin:
# plugins:
#   - name: redirect
#     config:
#       status_code: 301
#       https_port_in_redirect: true
#     enabled: true
#     protocols:
#       - http
#     config:
#       rules:
#         - conditions:
#             - http_host:
#                 - $DOMAIN
EOF

  if [[ "$INCLUDE_WWW" == "y" || "$INCLUDE_WWW" == "Y" ]]; then
    echo "#                 - www.$DOMAIN" >> ./volumes/api/kong.yml
  fi

  cat >> ./volumes/api/kong.yml << EOF
#           actions:
#             request_scheme: https
EOF
fi
success "Added HTTP to HTTPS redirect information to Kong configuration (commented out)"

# Create certificate renewal script
step "Creating certificate renewal script..."

if [ "$USE_DNS" == "true" ]; then
  # DNS validation renewal script - doesn't need to stop Kong
  cat > renew-cert.sh << 'EOF'
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
EOF
else
  # HTTP validation renewal script - needs to stop Kong
  cat > renew-cert.sh << 'EOF'
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
EOF
fi

chmod +x renew-cert.sh || error "Failed to make renewal script executable"
success "Certificate renewal script created: renew-cert.sh"

# Set up cron job for certificate renewal
step "Setting up automatic certificate renewal..."
(crontab -l 2>/dev/null | grep -v "renew-cert.sh"; echo "0 0 1,15 * * $(pwd)/renew-cert.sh") | crontab - || error "Failed to set up cron job"
success "Automatic certificate renewal set up"

# Update docker-compose.yml with new Kong configuration
step "Updating docker-compose.yml file..."
# Create a temporary file for the new configuration
TEMP_FILE=$(mktemp)
# Copy docker-compose.yml content to the temporary file, replacing the kong section
awk '{
  if (found_kong && /^  [a-zA-Z]/) {
    # If a new service section is found after kong, insert the new kong configuration
    if (!inserted_kong) {
      system("cat kong-ssl-config.yml");
      inserted_kong = 1;
    }
    found_kong = 0;
  }
  
  if (/^  kong:/) {
    # Found kong section, set the flag
    found_kong = 1;
    next;
  }
  
  if (found_kong && /^    [a-zA-Z]/) {
    # Skip lines in the kong section
    next;
  }
  
  # Print lines that are not part of the kong section
  if (!found_kong) {
    print;
  }
}
END {
  # If kong was the last section, add the new configuration at the end
  if (found_kong && !inserted_kong) {
    system("cat kong-ssl-config.yml");
  }
}' docker-compose.yml > "$TEMP_FILE"

# Replace the original file with the modified one
mv "$TEMP_FILE" docker-compose.yml || error "Failed to update docker-compose.yml"
rm -f kong-ssl-config.yml || error "Failed to remove temporary file"
success "docker-compose.yml updated with SSL configuration"

# Start Kong
step "Starting Kong container with SSL configuration..."
docker compose up -d kong || error "Failed to start Kong"
success "Kong started with SSL configuration"

# Add a testing script for validating the configuration
step "Creating SSL test script..."
cat > test-ssl.sh << 'EOF'
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
EOF

chmod +x test-ssl.sh || error "Failed to make test script executable"
success "SSL test script created: test-ssl.sh"

# Create a configuration backup script
step "Creating backup script..."
cat > backup-ssl-config.sh << 'EOF'
#!/bin/bash

# Create backup directory
BACKUP_DIR="/etc/letsencrypt/backups/$(date +%Y%m%d-%H%M%S)"
mkdir -p $BACKUP_DIR

# Backup certificates
echo "Backing up Let's Encrypt certificates..."
cp -r /etc/letsencrypt/live /etc/letsencrypt/archive $BACKUP_DIR/

# Backup Kong configuration
echo "Backing up Kong configuration..."
cp $(pwd)/docker-compose.yml $BACKUP_DIR/
cp $(pwd)/volumes/api/kong.yml $BACKUP_DIR/

echo "Backup completed: $BACKUP_DIR"
EOF

chmod +x backup-ssl-config.sh || error "Failed to make backup script executable"
success "Backup script created: backup-ssl-config.sh"

# Verify SSL setup
step "Verifying SSL setup..."
sleep 5 # Wait for Kong to start

# Try using our test script
if command_exists nc && nc -z localhost 443; then
  echo "Port 443 is open and accessible locally. Running test script..."
  ./test-ssl.sh $DOMAIN
else
  echo "Local testing not available. The configuration is complete, but will need to be tested remotely."
  echo "Once DNS propagation is complete, you can use the test-ssl.sh script to validate the setup."
fi

echo ""
echo "==================================================================="
echo "🎉 SSL setup complete for $DOMAIN! 🎉"
echo "==================================================================="
echo ""
echo "Your Supabase instance should now be accessible at:"
echo "  🔒 https://$DOMAIN"
if [[ "$INCLUDE_WWW" == "y" || "$INCLUDE_WWW" == "Y" ]]; then
  echo "  🔒 https://www.$DOMAIN"
fi
echo ""
echo "Useful scripts created:"
echo "  - $(pwd)/renew-cert.sh - Certificate renewal (runs automatically)"
echo "  - $(pwd)/test-ssl.sh - Test SSL configuration"
echo "  - $(pwd)/backup-ssl-config.sh - Backup SSL configuration"
echo ""
echo "Certificate will automatically renew on the 1st and 15th of each month."
echo ""
echo "To test HTTP to HTTPS redirection:"
echo "  curl -I http://$DOMAIN"
echo ""
echo "To check your SSL configuration thoroughly:"
echo "  https://www.ssllabs.com/ssltest/analyze.html?d=$DOMAIN"
echo ""
echo "To update your environment to use the custom domain:"
echo "  Add this to your .env file: SUPABASE_PUBLIC_URL=https://$DOMAIN"
echo ""
echo "==================================================================="