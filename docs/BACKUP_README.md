# Supabase Backup System

This document explains how to use the backup scripts for your Supabase project.

## Overview

The backup system consists of the following scripts in the `scripts` directory:

1. `scripts/supabase_backup.sh` - Universal script for both manual and automated backups
2. `scripts/restore_database.sh` - Script for restoring database from backups
3. `scripts/verify_backup.sh` - Script for verifying backup files
4. `scripts/backup.config` - Configuration file for backup settings

## Quick Start

### Manual Backup

To create a backup immediately:

```bash
./scripts/supabase_backup.sh
```

This will create a compressed SQL dump in the `backups` directory.

### Verifying a Backup

To verify the contents of a backup file:

```bash
./scripts/verify_backup.sh backups/supabase_backup_YYYYMMDD_HHMMSS.sql
```

This will show a summary of the backup contents including schemas, tables, and other database objects.

### Restoring from Backup

To restore your database from a backup:

```bash
./scripts/restore_database.sh
```

This will show you a list of available backups and prompt you to select one. Alternatively, you can specify a backup file directly:

```bash
./scripts/restore_database.sh supabase_backup_20250505_154436.sql.gz
```

### Automated Backups

To set up automated backups, add the script to your crontab.

## Configuration

All backup settings are in `scripts/backup.config`. The default configuration works out of the box, but you can customize it to your needs.

### Important Settings

- `PROJECT_DIR`: Path to your Supabase project (leave empty to use current directory)
- `BACKUP_DIR`: Where backups are stored (default: `./backups`)
- `KEEP_DAYS`: How many days to keep backups before deletion (default: 7)
- `DB_CONTAINER`: Docker container name for the database (default: `supabase-db`)
- `DB_USER`: Database user (default: `postgres`)
- `LOG_FILE`: Where to store backup logs (default: `./backups/backup.log`)

## Setting Up Cron Jobs

Cron is a time-based job scheduler in Unix-like operating systems. You can use it to schedule your backups to run automatically.

### Basic Cron Setup

1. Open your crontab for editing:

   ```bash
   crontab -e
   ```

2. Add a line to schedule the backup script. For example, to run daily at 3:00 AM:

   ```
   0 3 * * * /full/path/to/scripts/supabase_backup.sh
   ```

3. Save and exit the editor.

### Cron Schedule Examples

- **Daily backup at 3:00 AM**:
  ```
  0 3 * * * /full/path/to/scripts/supabase_backup.sh
  ```

- **Backup every Monday at 2:30 AM**:
  ```
  30 2 * * 1 /full/path/to/scripts/supabase_backup.sh
  ```

- **Backup every 6 hours**:
  ```
  0 */6 * * * /full/path/to/scripts/supabase_backup.sh
  ```

### Cron Syntax

```
┌───────────── minute (0 - 59)
│ ┌───────────── hour (0 - 23)
│ │ ┌───────────── day of the month (1 - 31)
│ │ │ ┌───────────── month (1 - 12)
│ │ │ │ ┌───────────── day of the week (0 - 6) (Sunday to Saturday)
│ │ │ │ │
│ │ │ │ │
* * * * * command to execute
```

## VS Code Extensions for Database Management

To verify and manage your PostgreSQL database, you can use these VS Code extensions:

1. **PostgreSQL** by Chris Kolkman - Basic PostgreSQL management
2. **SQLTools** by Matheus Teixeira - Universal database management tool
3. **Database Client** by Weijan Chen - Comprehensive database client with GUI

The "Database Client" extension (also known as "vscode-database-client") is particularly recommended for its user-friendly interface.

## Backup Verification

It's good practice to periodically verify your backups. You can check a backup file using:

```bash
./scripts/verify_backup.sh backups/supabase_backup_YYYYMMDD_HHMMSS.sql
```

## Troubleshooting

### Common Issues

1. **Permission denied**: Make sure the scripts are executable:
   ```bash
   chmod +x scripts/supabase_backup.sh scripts/restore_database.sh scripts/verify_backup.sh
   ```

2. **Cron not running**: Check your cron logs:
   ```bash
   grep CRON /var/log/syslog
   ```

3. **Backup failing**: Check the backup log file:
   ```bash
   cat backups/backup.log
   ```

## Advanced Usage

### Manual Backup Restoration

If you prefer to restore manually, you can use:

```bash
# For compressed backups (.sql.gz)
zcat backups/supabase_backup_YYYYMMDD_HHMMSS.sql.gz | docker exec -i supabase-db psql -U postgres -d postgres

# For uncompressed backups (.sql)
cat backups/supabase_backup_YYYYMMDD_HHMMSS.sql | docker exec -i supabase-db psql -U postgres -d postgres
```

### Future Enhancements

In the future, this backup system can be extended to:

1. Upload backups to cloud storage (AWS S3, Digital Ocean Spaces)
2. Send email notifications for backup status
3. Implement backup rotation strategies
