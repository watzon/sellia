# SQLite Persistence

Sellia uses SQLite for persistent storage of API keys, reserved subdomains, and schema migrations. This enables features like per-user authentication, admin operations, and subdomain reservations.

## Overview

SQLite is ideal for Sellia because:

- **Zero configuration** - No separate database server required
- **Embedded** - Database is just a file
- **Fast** - Optimized for the read-heavy workload of tunnel authentication
- **Reliable** - ACID compliant, atomic writes
- **Portable** - Single file backup/restore
- **Cross-platform** - Works everywhere Sellia runs

## When to Enable SQLite

Enable SQLite persistence when you need:

1. **Per-user authentication** - Multiple users with their own API keys
2. **Admin operations** - Create/revoke API keys, manage reserved subdomains
3. **Usage tracking** - Track when keys were last used
4. **Accountability** - Audit trail of who created tunnels
5. **Production deployment** - Anything beyond personal use

**You don't need SQLite if:**

- Single-user development server
- Testing locally without authentication
- Short-lived tunnels behind a firewall

## Database Location

### Default Path

```bash
/var/lib/sellia/sellia.db
```

### Configuring Path

**Environment variable:**

```bash
export SELLIA_DB_PATH="/var/lib/sellia/sellia.db"
```

**Config file:**

```yaml
# sellia-server.yml
database:
  enabled: true
  path: /var/lib/sellia/sellia.db
```

**Command line:**

```bash
sellia-server start --db-path /custom/path/sellia.db
```

### Directory Permissions

The database directory must be writable by the server process:

```bash
# Create directory
sudo mkdir -p /var/lib/sellia

# Set ownership
sudo chown sellia:sellia /var/lib/sellia

# Set permissions
sudo chmod 755 /var/lib/sellia
```

The database file will be created with mode `0640` (owner read/write, group read).

## Database Initialization

### Automatic Initialization

When you start the server with database enabled:

1. Database file is created if it doesn't exist
2. Migrations are run automatically
3. Default reserved subdomains are seeded
4. Server starts accepting connections

```bash
export SELLIA_DB_PATH="/var/lib/sellia/sellia.db"
sellia-server

# Output:
# [INFO] Database opened: /var/lib/sellia/sellia.db
# [INFO] Running 1 migration(s)
# [INFO] Applying migration 1: initial_schema
# [INFO] Migrations complete. Current version: 1
# [INFO] Seeded 50 default reserved subdomains
# [INFO] Server started on port 3000
```

### Manual Initialization

If you need to initialize the database separately (not recommended - server does this automatically):

```bash
# This is handled by the server
# No manual initialization needed
```

## Schema

### Tables

**schema_migrations**

Tracks which database migrations have been applied.

```sql
CREATE TABLE schema_migrations (
    version INTEGER PRIMARY KEY,
    applied_at TEXT NOT NULL DEFAULT (datetime('now'))
);
```

**reserved_subdomains**

Subdomains that cannot be claimed by tunnel clients.

```sql
CREATE TABLE reserved_subdomains (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    subdomain TEXT NOT NULL UNIQUE,
    reason TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    is_default BOOLEAN NOT NULL DEFAULT 0
);
```

**api_keys**

API keys for tunnel authentication and admin operations.

```sql
CREATE TABLE api_keys (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    key_hash TEXT NOT NULL UNIQUE,
    key_prefix TEXT NOT NULL,
    name TEXT,
    is_master BOOLEAN NOT NULL DEFAULT 0,
    active BOOLEAN NOT NULL DEFAULT 1,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    last_used_at TEXT
);
```

### Indexes

```sql
CREATE INDEX idx_api_keys_prefix ON api_keys(key_prefix);
CREATE INDEX idx_api_keys_active ON api_keys(active) WHERE active = 1;
```

These indexes optimize common queries:
- Finding a key by prefix during authentication
- Listing only active keys

## Performance

### Optimization Settings

Sellia configures SQLite with these optimizations:

```sql
-- WAL mode for better concurrency
PRAGMA journal_mode=WAL;

-- Faster writes with acceptable safety
PRAGMA synchronous=NORMAL;

-- Larger cache (64MB)
PRAGMA cache_size=-64000;

-- Foreign key constraints
PRAGMA foreign_keys=true;
```

**Why these settings:**

- **WAL mode** - Readers don't block writers, better for concurrent tunnel auth
- **synchronous=NORMAL** - Faster than FULL, safe enough for this workload
- **64MB cache** - Reduces disk I/O for frequent auth lookups
- **foreign_keys** - Ensures referential integrity (for future schema additions)

### Expected Performance

On typical hardware:

- **Authentication query**: < 1ms
- **Tunnel registration**: < 5ms
- **API key creation**: < 10ms
- **Concurrent connections**: 100+ without issues

### Monitoring Performance

```bash
# Check database file size
ls -lh /var/lib/sellia/sellia.db

# Monitor locks
lsof /var/lib/sellia/sellia.db

# Check WAL files
ls -lh /var/lib/sellia/sellia.db-wal
```

## Backup and Restore

### Backup

**Simple file copy:**

```bash
# Stop server first (to ensure consistency)
# (Stop the server process manually)

# Copy database file
cp /var/lib/sellia/sellia.db /backup/sellia.db.$(date +%Y%m%d)

# Restart server
sellia-server
```

**Online backup with SQLite (no downtime):**

```bash
sqlite3 /var/lib/sellia/sellia.db ".backup /backup/sellia.db.$(date +%Y%m%d)"
```

**Automated backup script:**

```bash
#!/bin/bash
# /etc/cron.daily/sellia-backup

BACKUP_DIR="/backup/sellia"
DATE=$(date +%Y%m%d)

mkdir -p "$BACKUP_DIR"

# Online backup
sqlite3 /var/lib/sellia/sellia.db ".backup $BACKUP_DIR/sellia.db.$DATE"

# Compress older backups
find "$BACKUP_DIR" -name "sellia.db.*" -mtime +7 -exec gzip {} \;

# Delete backups older than 30 days
find "$BACKUP_DIR" -name "sellia.db.*.gz" -mtime +30 -delete
```

### Restore

```bash
# Stop server
# (Stop the server process manually)

# Restore from backup
cp /backup/sellia.db.20240115 /var/lib/sellia/sellia.db

# Fix permissions
chown sellia:sellia /var/lib/sellia/sellia.db
chmod 640 /var/lib/sellia/sellia.db

# Restart server
sellia-server
```

## Maintenance

### Vacuum

Reclaim space and optimize database:

```bash
# Stop server
# (Stop the server process manually)

# Vacuum database
sqlite3 /var/lib/sellia/sellia.db "VACUUM;"

# Restart server
sellia-server
```

**When to vacuum:**

- After revoking many API keys
- Database file grew significantly
- Scheduled maintenance (monthly recommended)

### WAL Checkpoint

Manually checkpoint WAL to main database:

```bash
sqlite3 /var/lib/sellia/sellia.db "PRAGMA wal_checkpoint(TRUNCATE);"
```

**Note:** SQLite auto-checkpoints during normal operation. Manual checkpointing is rarely needed.

### Integrity Check

Verify database integrity:

```bash
sqlite3 /var/lib/sellia/sellia.db "PRAGMA integrity_check;"
```

Expected output: `ok`

### Analyze

Update query planner statistics:

```bash
sqlite3 /var/lib/sellia/sellia.db "ANALYZE;"
```

Run this after:
- Large data changes (bulk inserts/deletes)
- Database restore
- Every few months for maintenance

## Troubleshooting

### Database Locked

```
Error: database is locked
```

**Causes:**
- Multiple server instances running
- Another process has the database open
- Insufficient permissions

**Solutions:**

```bash
# Check for multiple servers
ps aux | grep sellia-server

# Check file locks
lsof /var/lib/sellia/sellia.db

# Check permissions
ls -la /var/lib/sellia/sellia.db
```

### Database Disk Image Malformed

```
Error: database disk image is malformed
```

**Causes:**
- Disk corruption
- Incomplete write
- Hardware failure

**Solutions:**

1. **Attempt recovery:**

   ```bash
   sqlite3 /var/lib/sellia/sellia.db ".recover" | sqlite3 /var/lib/sellia/sellia-recovered.db
   ```

2. **Restore from backup:**

   ```bash
   # Stop server manually
   cp /backup/sellia.db.latest /var/lib/sellia/sellia.db
   sellia-server
   ```

3. **If all else fails, reinitialize:**

   ```bash
   rm /var/lib/sellia/sellia.db
   sellia-server
   # Will create fresh database
   ```

### WAL File Too Large

```bash
# Check WAL size
ls -lh /var/lib/sellia/sellia.db-wal
```

If WAL is > 100MB, force checkpoint:

```bash
sqlite3 /var/lib/sellia/sellia.db "PRAGMA wal_checkpoint(TRUNCATE);"
```

### Slow Queries

Enable query logging:

```bash
export SQLITE_DEBUG=1
sellia-server start
```

Check for slow queries in logs. Common causes:
- Missing indexes (unlikely in Sellia's schema)
- Very large api_keys table (> 100,000 rows)
- Disk I/O bottleneck

## Security

### File Permissions

**Recommended permissions:**

```bash
# Directory
drwxr-xr-x  sellia  sellia  /var/lib/sellia/

# Database file
-rw-r-----  sellia  sellia  /var/lib/sellia/sellia.db
```

**Set permissions:**

```bash
sudo chown -R sellia:sellia /var/lib/sellia/
sudo chmod 755 /var/lib/sellia/
sudo chmod 640 /var/lib/sellia/sellia.db
```

### Encryption

SQLite database is not encrypted by default. For sensitive deployments:

1. **Full disk encryption** - Encrypt the entire disk/partition
2. **SQLCipher extension** - Compile with SQLCipher for database-level encryption
3. **File system encryption** - Use encrypted filesystems (eCryptfs, EncFS)

### Access Control

Only the Sellia server process should access the database:

```bash
# Check who can read the database
namei -l /var/lib/sellia/sellia.db

# Should show only owner (sellia) has read access
```

## Scaling Considerations

### When to Outgrow SQLite

Consider PostgreSQL or MySQL if:

- More than 1000 API keys
- More than 10,000 reserved subdomains
- More than 1000 concurrent tunnel authentications per second
- Need for distributed/replicated databases
- Need for complex queries/JOINS not supported by SQLite

### Migration Path

Sellia doesn't currently support other databases, but the schema is simple enough to migrate manually:

1. Dump SQLite database
2. Transform schema for target database
3. Load data
4. Modify Sellia code to use different DB driver

## See Also

- [Database Configuration](./database-config.md) - Configuration options
- [Migrations](./migrations.md) - Schema versions and changes
- [Server Auth](../authentication/server-auth.md) - Authentication with database
