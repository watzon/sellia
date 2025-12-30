# Database Migrations

Database migrations define and evolve the Sellia database schema over time. Migrations are applied automatically when the server starts.

## Overview

Sellia uses a versioned migration system:

- Each migration has a version number and name
- Migrations are applied in order when the server starts
- Applied migrations are tracked in `schema_migrations` table
- Rollback support is available (manual operation)

## Current Migrations

### Migration 1: Initial Schema

**Version:** 1
**Name:** `initial_schema`

**Creates:**

1. `schema_migrations` table - Track migration history
2. `reserved_subdomains` table - Reserved subdomain list
3. `api_keys` table - API key storage
4. Indexes for performance

**SQL:**

```sql
CREATE TABLE IF NOT EXISTS schema_migrations (
    version INTEGER PRIMARY KEY,
    applied_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS reserved_subdomains (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    subdomain TEXT NOT NULL UNIQUE,
    reason TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    is_default BOOLEAN NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS api_keys (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    key_hash TEXT NOT NULL UNIQUE,
    key_prefix TEXT NOT NULL,
    name TEXT,
    is_master BOOLEAN NOT NULL DEFAULT 0,
    active BOOLEAN NOT NULL DEFAULT 1,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    last_used_at TEXT
);

CREATE INDEX IF NOT EXISTS idx_api_keys_prefix ON api_keys(key_prefix);
CREATE INDEX IF NOT EXISTS idx_api_keys_active ON api_keys(active) WHERE active = 1;
```

**Rollback SQL:**

```sql
DROP INDEX IF EXISTS idx_api_keys_active;
DROP INDEX IF EXISTS idx_api_keys_prefix;
DROP TABLE IF EXISTS api_keys;
DROP TABLE IF EXISTS reserved_subdomains;
DROP TABLE IF EXISTS schema_migrations;
```

## Default Data Seeding

### Reserved Subdomains

Along with the initial schema, 50 default reserved subdomains are seeded:

```
api, www, admin, app, dashboard, console,
mail, smtp, imap, pop, ftp, ssh, sftp,
cdn, static, assets, media, images, files,
auth, login, oauth, sso, account, accounts,
billing, pay, payment, payments, subscribe,
help, support, docs, documentation, status,
blog, news, forum, community, dev, developer,
test, staging, demo, sandbox, preview,
ws, wss, socket, websocket, stream,
git, svn, repo, registry, npm, pypi,
internal, private, public, local, localhost,
root, system, server, servers, node, nodes,
sellia, tunnel, tunnels, proxy
```

These are marked with `is_default = true` and cannot be removed.

## Migration System

### Automatic Migration

Migrations run automatically when the server starts:

```bash
export SELLIA_DB_PATH="/var/lib/sellia/sellia.db"
sellia-server

# Output:
# [INFO] Database opened: /var/lib/sellia/sellia.db
# [INFO] Current version: 0
# [INFO] Pending migrations: [1]
# [INFO] Running 1 migration(s)
# [INFO] Applying migration 1: initial_schema
# [INFO] Seeded 50 default reserved subdomains
# [INFO] Migrations complete. Current version: 1
```

### Checking Migration Status

```bash
# Query schema_migrations table
sqlite3 /var/lib/sellia/sellia.db "SELECT * FROM schema_migrations;"

# Output:
# 1|2024-01-15 10:30:00
```

### Pending Migrations

Pending migrations are those not yet applied:

```sql
-- Get current version
SELECT COALESCE(MAX(version), 0) FROM schema_migrations;

-- Get pending migrations
-- (Any migration with version > current version)
```

## Manual Migration Operations

### Check Current Version

```bash
sqlite3 /var/lib/sellia/sellia.db "SELECT COALESCE(MAX(version), 0) FROM schema_migrations;"
```

### List Applied Migrations

```bash
sqlite3 /var/lib/sellia/sellia.db "SELECT version, applied_at FROM schema_migrations ORDER BY version;"
```

### Rollback Migrations

**Warning:** Rollback is a manual operation and **not exposed via CLI**. Only use this if you know what you're doing.

```bash
# Open database
sqlite3 /var/lib/sellia/sellia.db

# Inside SQLite CLI
BEGIN TRANSACTION;

-- Rollback migration 1
DROP INDEX IF EXISTS idx_api_keys_active;
DROP INDEX IF EXISTS idx_api_keys_prefix;
DROP TABLE IF EXISTS api_keys;
DROP TABLE IF EXISTS reserved_subdomains;
DELETE FROM schema_migrations WHERE version = 1;

COMMIT;

-- Verify
SELECT * FROM schema_migrations;
-- Should be empty
```

## Future Migrations

When adding new features, new migrations will be added to the migrations list.

### Example: Adding a Table

Hypothetical migration for tunnel tracking:

```sql
-- Migration 2: add_tunnel_tracking
CREATE TABLE IF NOT EXISTS tunnels (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    api_key_id INTEGER,
    subdomain TEXT NOT NULL,
    connected_at TEXT NOT NULL DEFAULT (datetime('now')),
    last_ping_at TEXT,
    FOREIGN KEY (api_key_id) REFERENCES api_keys(id)
);

CREATE INDEX IF NOT EXISTS idx_tunnels_subdomain ON tunnels(subdomain);
CREATE INDEX IF NOT EXISTS idx_tunnels_api_key ON tunnels(api_key_id);
```

### Migration Guidelines

When writing new migrations:

1. **Version numbers** - Increment by 1
2. **Up SQL** - DDL statements (CREATE, ALTER)
3. **Down SQL** - Reverse operations (DROP)
4. **Idempotent** - Use `IF NOT EXISTS`, `IF EXISTS`
5. **Indexes** - Create after tables
6. **Foreign keys** - Add after all tables exist
7. **Data migrations** - Separate from schema changes

## Troubleshooting

### Migration Failed During Start

Server fails to start with migration error.

**Symptoms:**

```
[ERROR] Migration failed: database disk image is malformed
```

**Solutions:**

1. **Check database integrity:**

   ```bash
   sqlite3 /var/lib/sellia/sellia.db "PRAGMA integrity_check;"
   ```

2. **Restore from backup:**

   ```bash
   cp /backup/sellia.db.latest /var/lib/sellia/sellia.db
   sellia-server
   ```

3. **Delete and reinitialize (last resort):**

   ```bash
   rm /var/lib/sellia/sellia.db
   sellia-server  # Creates fresh database
   ```

### Migration Already Applied

Attempt to apply already-applied migration.

**Symptoms:**

```
[WARN] Migration 1 already applied, skipping
```

**Cause:** Normal behavior - migrations are idempotent.

**Solution:** No action needed. Server continues normally.

### Schema Migrations Table Missing

`schema_migrations` table doesn't exist.

**Cause:** Database created manually without migrations.

**Solution:**

```bash
# Re-run migrations
sqlite3 /var/lib/sellia/sellia.db <<EOF
CREATE TABLE IF NOT EXISTS schema_migrations (
    version INTEGER PRIMARY KEY,
    applied_at TEXT NOT NULL DEFAULT (datetime('now'))
);
EOF

# Restart server
# (Stop and restart the server process)
```

### Wrong Migration Version

Database shows unexpected migration version.

**Cause:** Manual schema changes outside migration system.

**Solution:**

```bash
# Check what migrations are applied
sqlite3 /var/lib/sellia/sellia.db "SELECT * FROM schema_migrations;"

# If version is wrong, update manually
sqlite3 /var/lib/sellia/sellia.db "UPDATE schema_migrations SET version = 1 WHERE version = 2;"
```

## Database Schema Reference

### Schema Migrations Table

| Column | Type | Description |
|--------|------|-------------|
| `version` | INTEGER | Migration version number (primary key) |
| `applied_at` | TEXT | Timestamp when migration was applied |

### Reserved Subdomains Table

| Column | Type | Description |
|--------|------|-------------|
| `id` | INTEGER | Auto-increment primary key |
| `subdomain` | TEXT | Reserved subdomain (unique) |
| `reason` | TEXT | Optional reason/documentation |
| `created_at` | TEXT | Timestamp when reserved |
| `is_default` | BOOLEAN | True if seeded by default (cannot remove) |

### API Keys Table

| Column | Type | Description |
|--------|------|-------------|
| `id` | INTEGER | Auto-increment primary key |
| `key_hash` | TEXT | SHA-256 hash of API key (unique) |
| `key_prefix` | TEXT | First 8 characters (for identification) |
| `name` | TEXT | Optional friendly name |
| `is_master` | BOOLEAN | True if master key (admin access) |
| `active` | BOOLEAN | False if revoked |
| `created_at` | TEXT | Timestamp when created |
| `last_used_at` | TEXT | Timestamp of last tunnel creation |

## Exporting Schema

To export the current database schema:

```bash
# Full schema with indexes
sqlite3 /var/lib/sellia/sellia.db ".schema"

# Specific table schema
sqlite3 /var/lib/sellia/sellia.db ".schema api_keys"

# Schema with CREATE statements only
sqlite3 /var/lib/sellia/sellia.db ".schema" | grep "^CREATE"
```

## Backup Before Migrations

Always backup before manual schema changes:

```bash
# Backup before migration
cp /var/lib/sellia/sellia.db /var/lib/sellia/sellia.db.pre-migration

# Apply migration
# ... migration operations ...

# Verify
sqlite3 /var/lib/sellia/sellia.db "PRAGMA integrity_check;"

# Rollback if needed
cp /var/lib/sellia/sellia.db.pre-migration /var/lib/sellia/sellia.db
```

## See Also

- [SQLite Persistence](./sqlite.md) - Database operations
- [Database Configuration](./database-config.md) - Configuration options
- [API Key Management](../admin/api-key-management.md) - Managing API keys
