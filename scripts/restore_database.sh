#!/bin/bash

# Supabase PostgreSQL Restore Script
# This script restores a database from a backup

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
DB_CONTAINER="${DB_CONTAINER:-supabase-db}"
DB_USER="${DB_USER:-postgres}"

# Make backup directory absolute if it's relative
if [[ ! "$BACKUP_DIR" = /* ]]; then
  BACKUP_DIR="$PROJECT_DIR/$BACKUP_DIR"
fi

# Load environment variables from .env file
if [ -f "$PROJECT_DIR/.env" ]; then
  export $(grep -v '^#' "$PROJECT_DIR/.env" | xargs)
else
  echo "Error: .env file not found in $PROJECT_DIR. Please make sure the project directory is correct."
  exit 1
fi

# Function to display available backups
list_backups() {
  echo "Available backups:"
  echo "-----------------"
  
  # List all backups with numbers
  local backups=()
  local i=1
  
  while IFS= read -r backup; do
    backups+=("$backup")
    local date_part=$(echo "$backup" | sed -E 's/supabase_backup_([0-9]{8})_([0-9]{6})\.sql(\.gz)?/\1 \2/')
    local formatted_date=""
    
    if [[ $date_part =~ ([0-9]{8})\ ([0-9]{6}) ]]; then
      local year=${BASH_REMATCH[1]:0:4}
      local month=${BASH_REMATCH[1]:4:2}
      local day=${BASH_REMATCH[1]:6:2}
      local hour=${BASH_REMATCH[2]:0:2}
      local min=${BASH_REMATCH[2]:2:2}
      local sec=${BASH_REMATCH[2]:4:2}
      formatted_date="$year-$month-$day $hour:$min:$sec"
    else
      formatted_date="Unknown date"
    fi
    
    local size=$(du -h "$BACKUP_DIR/$backup" | cut -f1)
    echo "[$i] $backup ($size) - $formatted_date"
    ((i++))
  done < <(find "$BACKUP_DIR" -type f -name "supabase_backup_*.sql*" | sort -r | xargs -n1 basename)
  
  # Store backups array for later use
  BACKUPS=("${backups[@]}")
  
  if [ ${#BACKUPS[@]} -eq 0 ]; then
    echo "No backups found in $BACKUP_DIR"
    exit 1
  fi
}

# Function to restore a backup
restore_backup() {
  local backup_file="$1"
  local full_path="$BACKUP_DIR/$backup_file"
  
  if [ ! -f "$full_path" ]; then
    echo "Error: Backup file not found: $full_path"
    exit 1
  fi
  
  echo "Preparing to restore from: $backup_file"
  echo "WARNING: This will overwrite the current database!"
  read -p "Are you sure you want to proceed? (y/N) " -n 1 -r
  echo
  
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Restore cancelled."
    exit 0
  fi
  
  # Check if the database container is running
  if ! docker ps | grep -q $DB_CONTAINER; then
    echo "Error: $DB_CONTAINER container is not running. Please start your Supabase stack first."
    exit 1
  fi
  
  echo "Restoring database from backup..."
  
  # Handle both compressed and uncompressed backups
  if [[ "$backup_file" == *.gz ]]; then
    # Compressed backup
    echo "Restoring from compressed backup..."
    cat "$full_path" | gunzip | docker exec -i $DB_CONTAINER psql -U $DB_USER -d $POSTGRES_DB
  else
    # Uncompressed backup
    echo "Restoring from uncompressed backup..."
    cat "$full_path" | docker exec -i $DB_CONTAINER psql -U $DB_USER -d $POSTGRES_DB
  fi
  
  if [ $? -eq 0 ]; then
    echo "Database restored successfully!"
  else
    echo "Error: Database restore failed."
    exit 1
  fi
}

# Main script logic
if [ $# -eq 0 ]; then
  # No arguments, show list of backups and prompt for selection
  list_backups
  
  read -p "Enter the number of the backup to restore: " selection
  
  if ! [[ "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt ${#BACKUPS[@]} ]; then
    echo "Invalid selection."
    exit 1
  fi
  
  # Adjust for 0-based array indexing
  ((selection--))
  
  restore_backup "${BACKUPS[$selection]}"
else
  # Argument provided, use it as the backup file name
  restore_backup "$1"
fi

exit 0
