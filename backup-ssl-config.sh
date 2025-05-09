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
