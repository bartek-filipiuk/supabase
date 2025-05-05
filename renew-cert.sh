#\!/bin/bash

# Set up logging
LOGFILE="/var/log/letsencrypt-renew.log"
exec > >(tee -a $LOGFILE) 2>&1

echo "$(date): Starting certificate renewal..."

# Stop Kong to free port 80
echo "$(date): Stopping Kong container..."
cd /home/bart/supabase
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
  cp -L /etc/letsencrypt/live/mybases.pl/fullchain.pem /etc/letsencrypt/shared/
  cp -L /etc/letsencrypt/live/mybases.pl/privkey.pem /etc/letsencrypt/shared/
  chmod 644 /etc/letsencrypt/shared/fullchain.pem
  chmod 644 /etc/letsencrypt/shared/privkey.pem
fi

# Start Kong back up
echo "$(date): Starting Kong container..."
cd /home/bart/supabase
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
