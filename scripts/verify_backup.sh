#!/bin/bash

# Supabase PostgreSQL Backup Verification Script
# This script checks if a SQL backup file contains valid PostgreSQL dump data

# Determine script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Function to display usage
usage() {
  echo "Usage: $0 <backup_file.sql>"
  echo "Example: $0 backups/supabase_backup_20250505_154436.sql"
  exit 1
}

# Check if a file was provided
if [ $# -eq 0 ]; then
  echo "Error: No backup file specified."
  usage
fi

BACKUP_FILE="$1"

# Check if the file exists
if [ ! -f "$BACKUP_FILE" ]; then
  echo "Error: Backup file not found: $BACKUP_FILE"
  usage
fi

echo "Verifying backup file: $BACKUP_FILE"
echo "=================================="

# Check if it's a PostgreSQL dump file
if ! grep -q "PostgreSQL database dump" "$BACKUP_FILE"; then
  echo "❌ ERROR: This does not appear to be a valid PostgreSQL dump file."
  exit 1
else
  echo "✅ Valid PostgreSQL dump file detected"
fi

# Extract PostgreSQL version information
PG_VERSION=$(grep "Dumped from database version" "$BACKUP_FILE" | sed 's/-- Dumped from database version //')
DUMP_VERSION=$(grep "Dumped by pg_dump version" "$BACKUP_FILE" | sed 's/-- Dumped by pg_dump version //')

echo "📊 Database version: $PG_VERSION"
echo "🔧 Dump created with pg_dump version: $DUMP_VERSION"

# Count schemas, tables, and functions
SCHEMAS=$(grep -c "CREATE SCHEMA" "$BACKUP_FILE")
TABLES=$(grep -c "CREATE TABLE" "$BACKUP_FILE")
FUNCTIONS=$(grep -c "CREATE FUNCTION" "$BACKUP_FILE")
SEQUENCES=$(grep -c "CREATE SEQUENCE" "$BACKUP_FILE")
INDEXES=$(grep -c "CREATE INDEX" "$BACKUP_FILE")
VIEWS=$(grep -c "CREATE VIEW\|CREATE MATERIALIZED VIEW" "$BACKUP_FILE")

echo "📋 Backup Content Summary:"
echo "  - Schemas: $SCHEMAS"
echo "  - Tables: $TABLES"
echo "  - Functions: $FUNCTIONS"
echo "  - Sequences: $SEQUENCES"
echo "  - Indexes: $INDEXES"
echo "  - Views: $VIEWS"

# Check for data (INSERT statements)
INSERTS=$(grep -c "INSERT INTO" "$BACKUP_FILE")
echo "  - INSERT statements: $INSERTS"

# Check file size
SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
echo "📦 Backup file size: $SIZE"

# List schemas in the backup
echo -e "\n📚 Schemas in backup:"
grep "CREATE SCHEMA" "$BACKUP_FILE" | sed 's/CREATE SCHEMA //' | sed 's/;//' | sort | while read -r schema; do
  echo "  - $schema"
done

# List tables in the backup (sample)
echo -e "\n🗃️ Tables in backup (sample):"
grep "CREATE TABLE" "$BACKUP_FILE" | head -n 10 | sed 's/CREATE TABLE //' | sed 's/ (.*//' | while read -r table; do
  echo "  - $table"
done

if [ $(grep "CREATE TABLE" "$BACKUP_FILE" | wc -l) -gt 10 ]; then
  echo "  ... and $(( $(grep "CREATE TABLE" "$BACKUP_FILE" | wc -l) - 10 )) more tables"
fi

echo -e "\n✅ Backup verification completed"
echo "The backup appears to be a valid PostgreSQL dump with $TABLES tables and $SCHEMAS schemas."
echo "You can restore this backup using: ./restore_database.sh $(basename "$BACKUP_FILE")"
