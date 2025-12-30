# Database Configuration

Configure SQLite database settings for your Sellia server including path, enable/disable, and connection options.

## Configuration Options

### Environment Variables

The primary way to configure the database is via environment variables:

```bash
# Enable/disable database (default: auto-detect based on path)
export SELLIA_DB_PATH="/var/lib/sellia/sellia.db"

# Explicitly disable database
export SELLIA_NO_DB="true"
```

### Config File

Alternatively, use a YAML config file:

```yaml
# sellia-server.yml
database:
  enabled: true
  path: /var/lib/sellia/sellia.db
```

### Command Line

When starting the server:

```bash
sellia-server start --db-path /var/lib/sellia/sellia.db
```

## Enable/Disable Database

### Enable Database

**Method 1: Set path (enables automatically):**

```bash
export SELLIA_DB_PATH="/var/lib/sellia/sellia.db"
sellia-server
```

**Method 2: Config file:**

```yaml
database:
  enabled: true
  path: /var/lib/sellia/sellia.db
```

**Method 3: Command line:**

```bash
sellia-server --db-path /var/lib/sellia/sellia.db
```

### Disable Database

**Method 1: Environment variable:**

```bash
export SELLIA_NO_DB="true"
sellia-server
```

**Method 2: Config file:**

```yaml
database:
  enabled: false
```

**Method 3: Command line flag:**

```bash
sellia-server --no-db
```

### Priority Order

When multiple sources are set, priority is:

1. `SELLIA_NO_DB="true"` (explicit disable)
2. `SELLIA_DB_PATH` (explicit enable)
3. Config file `database.enabled`
4. Config file `database.path`

## Path Configuration

### Absolute Path

Recommended for production:

```bash
export SELLIA_DB_PATH="/var/lib/sellia/sellia.db"
```

### Relative Path

Resolved relative to server's working directory:

```bash
export SELLIA_DB_PATH="./data/sellia.db"
```

**Note:** Relative paths can be confusing. Use absolute paths in production.

### In-Memory Database

For testing only:

```bash
export SELLIA_DB_PATH=":memory:"
```

**Warning:** Data is lost when server stops. Only for development/testing.

### Shared-Cache In-Memory

For tests that need multiple connections:

```bash
export SELLIA_DB_PATH=":memory:?mode=memory&cache=shared"
```

## Connection Options

### SQLite Configuration String

The server uses this connection string:

```
sqlite3://<path>?journal_mode=WAL&synchronous=NORMAL&cache_size=-64000&foreign_keys=true&max_pool_size=1
```

These options are hardcoded and optimal for Sellia's workload.

### WAL Mode (Write-Ahead Logging)

**What it does:**
- Allows concurrent reads and writes
- Better performance for authentication queries
- Multiple readers don't block writers

**Cannot be changed** - hardcoded to WAL mode.

### Synchronous Mode

**What it does:**
- Controls how often data is flushed to disk
- `NORMAL` = Safe but faster
- Full durability risk: Low (acceptable for this use case)

**Cannot be changed** - hardcoded to NORMAL.

### Cache Size

**What it does:**
- `-64000` = 64MB cache
- Reduces disk I/O for frequent queries

**Cannot be changed** - hardcoded to 64MB.

### Connection Pool

**What it does:**
- `max_pool_size=1` = Single connection for all queries
- Required for SQLite (multiple connections can cause locks)

**Cannot be changed** - hardcoded to 1.

## Directory Permissions

### Creating Directory

```bash
# Create directory
sudo mkdir -p /var/lib/sellia

# Set ownership
sudo chown sellia:sellia /var/lib/sellia

# Set permissions
sudo chmod 755 /var/lib/sellia
```

### Database File Permissions

The server creates the database with `0640` permissions:

- Owner (sellia): read/write
- Group (sellia): read
- Others: no access

**Manual permission fix:**

```bash
sudo chmod 640 /var/lib/sellia/sellia.db
sudo chown sellia:sellia /var/lib/sellia/sellia.db
```

### SELinux Configuration

If using SELinux, may need to label the database:

```bash
# Check current context
ls -Z /var/lib/sellia/sellia.db

# Set context (adjust as needed)
sudo semanage fcontext -a -t httpd_sys_rw_content_t "/var/lib/sellia(/.*)?"
sudo restorecon -Rv /var/lib/sellia
```

## Configuration Examples

### Development

```bash
# Use local file for development
export SELLIA_DB_PATH="$HOME/dev/sellia/sellia.db"
sellia-server
```

### Production

```bash
# Use system directory with proper permissions
export SELLIA_DB_PATH="/var/lib/sellia/sellia.db"
sudo mkdir -p /var/lib/sellia
sudo chown sellia:sellia /var/lib/sellia
sudo chmod 755 /var/lib/sellia
sellia-server
```

### Docker

```yaml
# docker-compose.yml
version: '3'
services:
  sellia-server:
    image: sellia/server:latest
    environment:
      - SELLIA_DB_PATH=/data/sellia.db
    volumes:
      - sellia-data:/data
    ports:
      - "3000:3000"

volumes:
  sellia-data:
```

### Kubernetes

```yaml
# deployment.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: sellia-config
data:
  SELLIA_DB_PATH: "/data/sellia.db"
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: sellia-data
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sellia-server
spec:
  template:
    spec:
      containers:
      - name: sellia
        image: sellia/server:latest
        envFrom:
          - configMapRef:
              name: sellia-config
        volumeMounts:
          - name: data
            mountPath: /data
      volumes:
        - name: data
          persistentVolumeClaim:
            claimName: sellia-data
```

### Systemd Service

```ini
# /etc/systemd/system/sellia.service
[Unit]
Description=Sellia Tunnel Server
After=network.target

[Service]
Type=simple
User=sellia
Group=sellia
WorkingDirectory=/opt/sellia
Environment="SELLIA_DB_PATH=/var/lib/sellia/sellia.db"
Environment="SELLIA_REQUIRE_AUTH=true"
Environment="SELLIA_MASTER_KEY=your-master-key"
ExecStart=/opt/sellia/bin/sellia-server start
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

Enable and start:

```bash
sudo systemctl enable sellia
sudo systemctl start sellia
```

## Environment Variables Reference

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `SELLIA_DB_PATH` | string | (none) | Path to SQLite database file |
| `SELLIA_NO_DB` | boolean | false | Explicitly disable database |

## Config File Reference

```yaml
database:
  enabled: true          # Enable/disable database
  path: /var/lib/sellia/sellia.db  # Database file path
```

**Priority:** Environment variables override config file.

## Troubleshooting

### Database Not Created

Server starts but no database file exists.

**Cause:** Database path not set or invalid.

**Solution:**

```bash
# Check if path is set
echo $SELLIA_DB_PATH

# Set path and restart
export SELLIA_DB_PATH="/var/lib/sellia/sellia.db"
# Stop and restart the server
```

### Permission Denied

```
Error: Permission denied: /var/lib/sellia/sellia.db
```

**Cause:** Wrong permissions on directory or file.

**Solution:**

```bash
# Fix directory permissions
sudo chmod 755 /var/lib/sellia

# Fix file permissions
sudo chmod 640 /var/lib/sellia/sellia.db
sudo chown sellia:sellia /var/lib/sellia/sellia.db
```

### Database in Read-Only Mode

```
Error: attempt to write a readonly database
```

**Cause:** File or directory is read-only, or disk is full.

**Solution:**

```bash
# Check disk space
df -h /var/lib/sellia

# Check file permissions
ls -la /var/lib/sellia/sellia.db

# Remount read-write if necessary
sudo mount -o remount,rw /var
```

### Database Locked

```
Error: database is locked
```

**Cause:** Multiple server instances running.

**Solution:**

```bash
# Check for running servers
ps aux | grep sellia-server

# Kill duplicate instances
pkill sellia-server

# Start single instance
sellia-server
```

### Path Contains Spaces

If database path has spaces, quote it:

```bash
# Wrong
export SELLIA_DB_PATH=/path/with spaces/sellia.db

# Right
export SELLIA_DB_PATH="/path/with spaces/sellia.db"
```

## Best Practices

### Production

1. **Use absolute paths**
   ```bash
   export SELLIA_DB_PATH="/var/lib/sellia/sellia.db"
   ```

2. **Dedicated directory**
   ```bash
   /var/lib/sellia/
   ```

3. **Proper permissions**
   ```bash
   sudo chown sellia:sellia /var/lib/sellia/sellia.db
   sudo chmod 640 /var/lib/sellia/sellia.db
   ```

4. **Persistent storage**
   - Use Docker volumes
   - Use Kubernetes PVCs
   - Don't store in ephemeral locations

### Development

1. **Use relative path in project directory**
   ```bash
   export SELLIA_DB_PATH="./dev/sellia.db"
   ```

2. **Add to .gitignore**
   ```
   echo "dev/*.db" >> .gitignore
   echo "dev/*.db-wal" >> .gitignore
   ```

3. **Clean slate testing**
   ```bash
   rm ./dev/sellia.db
   sellia-server  # Creates fresh database
   ```

### Testing

1. **Use in-memory database**
   ```bash
   export SELLIA_DB_PATH=":memory:"
   ```

2. **Each test gets fresh database**
   - No cleanup required
   - Fast initialization
   - Isolated tests

## See Also

- [SQLite Persistence](./sqlite.md) - Database overview and operations
- [Migrations](./migrations.md) - Schema versions
- [Server Auth](../authentication/server-auth.md) - Authentication setup
