#\!/bin/bash

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
  CERT_INFO=$(echo  < /dev/null |  openssl s_client -servername $domain -connect $domain:8443 2>/dev/null | openssl x509 -noout -subject -dates)
  if [ \! -z "$CERT_INFO" ]; then
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
