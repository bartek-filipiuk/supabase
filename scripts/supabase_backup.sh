#!/bin/bash

# Supabase PostgreSQL Backup Script
# This script creates a backup of the Supabase PostgreSQL database
# Can be run manually or via cron

# Determine script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load configuration
CONFIG_FILE="$SCRIPT_DIR/backup.config"
if [ -f "$CONFIG_FILE" ]; then
  source "$CONFIG_FILE"
else
  echo "Warning: Configuration file $CONFIG_FILE not found. Using default settings."
fi

# Set default values if not defined in config
PROJECT_DIR="${PROJECT_DIR:-$SCRIPT_DIR}"
BACKUP_DIR="${BACKUP_DIR:-./backups}"
KEEP_DAYS="${KEEP_DAYS:-7}"
DB_CONTAINER="${DB_CONTAINER:-supabase-db}"
DB_USER="${DB_USER:-postgres}"
LOG_FILE="${LOG_FILE:-./backups/backup.log}"

# Make paths absolute if they're relative
if [[ ! "$BACKUP_DIR" = /* ]]; then
  BACKUP_DIR="$PROJECT_DIR/$BACKUP_DIR"
fi

if [[ ! "$LOG_FILE" = /* ]]; then
  LOG_FILE="$PROJECT_DIR/$LOG_FILE"
fi

# Create directories if they don't exist
mkdir -p "$BACKUP_DIR"
mkdir -p "$(dirname "$LOG_FILE")"

# Determine if running in interactive mode or from cron
if [ -t 1 ]; then
  # Running in terminal (interactive)
  INTERACTIVE=true
else
  # Running from cron or non-interactive
  INTERACTIVE=false
fi

# Function to log messages
log_message() {
  local message="$1"
  local timestamp="$(date "+%Y-%m-%d %H:%M:%S")"
  
  # Always write to log file
  echo "[$timestamp] $message" >> "$LOG_FILE"
  
  # If interactive, also print to console
  if [ "$INTERACTIVE" = true ]; then
    echo "$message"
  fi
}

# Start backup process
if [ "$INTERACTIVE" = false ]; then
  log_message "=== Backup started at $(date) ==="
fi

# Change to the project directory
cd "$PROJECT_DIR" || { log_message "Error: Could not change to project directory: $PROJECT_DIR"; exit 1; }

# Load environment variables from .env file
if [ -f "$PROJECT_DIR/.env" ]; then
  export $(grep -v '^#' "$PROJECT_DIR/.env" | xargs)
else
  log_message "Error: .env file not found in $PROJECT_DIR. Please make sure the project directory is correct."
  exit 1
fi

# Create timestamp for backup file
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="${BACKUP_DIR}/supabase_backup_${TIMESTAMP}.sql.gz"

log_message "Starting Supabase database backup..."
log_message "Project directory: $PROJECT_DIR"
log_message "Backup directory: $BACKUP_DIR"

# Check if the database container is running
if ! docker ps | grep -q $DB_CONTAINER; then
  log_message "Error: $DB_CONTAINER container is not running. Please start your Supabase stack first."
  exit 1
fi

# Create database dump and compress it
log_message "Creating database dump..."
docker exec $DB_CONTAINER pg_dump -U $DB_USER -d $POSTGRES_DB | gzip > "$BACKUP_FILE"

if [ $? -eq 0 ]; then
  BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
  log_message "Backup successfully created at: $BACKUP_FILE"
  log_message "Backup size: $BACKUP_SIZE"
else
  log_message "Error: Database backup failed."
  exit 1
fi

# Clean up old backups
log_message "Cleaning up backups older than $KEEP_DAYS days..."
find "$BACKUP_DIR" -name "supabase_backup_*.sql.gz" -type f -mtime +$KEEP_DAYS -delete

log_message "Backup process completed."

if [ "$INTERACTIVE" = false ]; then
  log_message "=== Backup completed at $(date) ==="
  log_message ""
fi

exit 0
