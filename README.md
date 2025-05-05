# Supabase Docker

This is a minimal Docker Compose setup for self-hosting Supabase. Follow the steps [here](https://supabase.com/docs/guides/hosting/docker) to get started.

## Password Management and System Reset

### Changing Passwords and Secrets

When changing passwords and secrets in the `.env` file (such as `POSTGRES_PASSWORD`, `JWT_SECRET`, `ANON_KEY`, `SERVICE_ROLE_KEY`, `LOGFLARE_API_KEY`, etc.), you need to perform a complete system reset to ensure all components recognize the new credentials.

Follow these steps:

1. Stop all containers and remove volumes:
   ```bash
   docker compose down -v
   ```

2. Remove the database data directory to ensure a clean state:
   ```bash
   sudo rm -rf volumes/db/data
   ```

3. Start the system with the new credentials:
   ```bash
   docker compose up -d
   ```

This procedure is necessary because some services (particularly the analytics container) may fail to start if there's a mismatch between the passwords in the `.env` file and those stored in the database.

### Critical Environment Variables

The most important variables to secure in your `.env` file are:

- `POSTGRES_PASSWORD`: Database password
- `JWT_SECRET`: Secret used for JWT token generation
- `ANON_KEY` and `SERVICE_ROLE_KEY`: API access keys
- `DASHBOARD_USERNAME` and `DASHBOARD_PASSWORD`: Studio login credentials
- `LOGFLARE_API_KEY`: Analytics service key
- `POOLER_TENANT_ID`: Connection pooler tenant ID

Always use strong, unique values for these variables in production environments.
