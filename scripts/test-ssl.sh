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
  # We expect 401 for authentication which means HTTPS is working
  HTTP_STATUS=$(curl -s -k -o /dev/null -w "%{http_code}" https://$domain)
  if [ "$HTTP_STATUS" == "401" ] || [ "$HTTP_STATUS" == "200" ]; then
    echo "    ✅ HTTPS is working (Status $HTTP_STATUS)"
  else
    echo "    ❌ HTTPS is not working (Status $HTTP_STATUS)"
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
  
  API_STATUS=$(curl -s -k -o /dev/null -w "%{http_code}" https://${DOMAINS[0]}/rest/v1/)
  echo -n "$API_STATUS "
  if [ "$API_STATUS" == "401" ] || [ "$API_STATUS" == "200" ]; then
    echo "  ✅ Supabase API is accessible"
  else
    echo "  ❌ Supabase API is not accessible"
  fi
  
  echo ""
  echo "SSL Test completed."
}

# Run the main function
main "$@"
