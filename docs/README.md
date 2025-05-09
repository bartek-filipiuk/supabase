# Supabase Docker

This is a minimal Docker Compose setup for self-hosting Supabase. Follow the steps [here](https://supabase.com/docs/guides/hosting/docker) to get started. This instance is configured with a custom domain (https://mybases.pl:8443/) and SSL.

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

## Custom Domain and SSL Configuration

This Supabase instance is configured to use the custom domain `mybases.pl` with SSL encryption provided by Let's Encrypt. The setup allows secure access to the Supabase API and dashboard through HTTPS.

### Access Details

- API Endpoint: `https://mybases.pl:8443/rest/v1/`
- Dashboard: `https://mybases.pl:8443/`

### Certificate Management

- SSL certificates are provided by Let's Encrypt
- Certificates are stored in `/etc/letsencrypt/live/mybases.pl/`
- Certificates are valid for 90 days with automatic renewal configured

### Maintenance Scripts

Several utility scripts have been created to help maintain and manage the setup:

1. **`ssl-setup.sh`**: Initial SSL configuration script
   - Sets up Let's Encrypt certificates for your custom domain
   - Configures Kong to use SSL certificates
   - Creates HTTP to HTTPS redirects
   - Usage: `sudo ./ssl-setup.sh -d mydomain.com -e myemail@example.com`

2. **`renew-cert.sh`**: Certificate renewal script
   - Automatically renews the Let's Encrypt certificates when they're nearing expiration
   - Temporarily stops Kong to free port 80, then restarts it after renewal
   - Copies renewed certificates to the shared directory for Kong
   - Runs via crontab on the 1st and 15th of each month
   - Usage for manual renewal: `sudo ./renew-cert.sh`

3. **`test-ssl.sh`**: SSL validation script
   - Tests the SSL configuration and certificate
   - Verifies HTTP to HTTPS redirects
   - Checks certificate validity and expiration
   - Tests Kong health and API accessibility
   - Usage: `./test-ssl.sh mybases.pl`

4. **`backup-ssl-config.sh`**: Backup script
   - Creates backups of SSL certificates and Kong configuration
   - Useful before making changes to the SSL setup
   - Usage: `sudo ./backup-ssl-config.sh`

5. **`reset.sh`**: Reset script
   - Resets the Supabase instance to a clean state
   - Removes all data while preserving configuration
   - Usage: `./reset.sh`

### Certificate Renewal Configuration

Automatic certificate renewal is configured via crontab to run on the 1st and 15th of each month. This ensures certificates are renewed before they expire. The crontab entry is:

```
0 0 1,15 * * /home/bart/supabase/renew-cert.sh
```

For detailed information about the custom domain and SSL setup, refer to the [CUSTOM_DOMAIN.md](CUSTOM_DOMAIN.md) file.
