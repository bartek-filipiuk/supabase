# Supabase Analytics Memory Allocation Issue - Fix Documentation

## Problem

The Supabase analytics container (running Logflare 1.12.0) was experiencing repeated crashes with memory allocation errors. The specific error observed in logs:

```
ll_alloc: Cannot allocate 2147483711 bytes of memory (of type "port_tab").
```

This error indicates that the Erlang BEAM VM (which runs Logflare) was attempting to allocate approximately 2GB of memory for its port table, but this allocation was failing because:

1. The server only has 1.9GB of total memory available
2. No memory limits were set on the container, allowing it to attempt to use more memory than available
3. The Erlang VM was configured with default settings inappropriate for resource-constrained environments

## Solution

The issue was resolved by implementing two key changes in the `docker-compose.yml` file:

### 1. Added Memory Limits to the Container

```yaml
deploy:
  resources:
    limits:
      memory: 512M
    reservations:
      memory: 256M
```

This configuration ensures that the container cannot use more than 512MB of memory, preventing it from attempting to consume all available system memory.

### 2. Limited Erlang BEAM VM's Port Table Size

Added an environment variable to control the Erlang runtime's resource usage:

```yaml
environment:
  # ... other variables ...
  ERL_MAX_PORTS: 1024
```

This setting restricts the number of ports the Erlang VM can open, thereby limiting the size of the port table - directly addressing the specific allocation that was failing.

## Implementation

The changes were applied to the `analytics` service section in the `docker-compose.yml` file. After making these changes, the container was restarted using:

```bash
docker compose down analytics
docker compose up -d analytics
```

## Results

After applying these changes, the container stabilized and began running normally. Memory usage settled at approximately 440MB (about 86% of the 512MB limit), which is sustainable for normal operation.

## Additional Considerations

1. **Monitoring**: Keep an eye on the container's memory usage with `docker stats`. If it consistently approaches the 512MB limit, performance issues may occur.

2. **Scaling**: If you experience performance problems with these settings, you might need to:
   - Increase the memory limit if your server has available resources
   - Upgrade to a server with more memory
   - Consider using the BigQuery backend for analytics instead of Postgres (commented options in docker-compose.yml)

3. **Other Services**: Similar memory constraints might be beneficial for other containers in the Supabase stack if you're running on a resource-constrained environment.

4. **Persistence**: These changes will persist through container restarts but will need to be reapplied if you recreate your entire Supabase stack.