# API Key Management

Create, list, and revoke API keys for tunnel access and admin operations using the `sellia admin api-keys` command.

## Overview

API keys control access to your Sellia server. There are two types:

1. **Standard keys** - For tunnel creation and basic operations
2. **Master keys** - For admin API access and key management

All management operations require authentication with a master key.

## Prerequisites

Before managing API keys, ensure:

1. Server is running with database enabled
2. You have a master key for authentication
3. Admin API is accessible

```bash
# Check server has database
export SELLIA_DB_PATH="/var/lib/sellia/sellia.db"
sellia-server start

# Set your admin key
export SELLIA_ADMIN_API_KEY="your-master-key"
```

## Commands

### `sellia admin api-keys list`

List all API keys in the database.

**Usage:**

```bash
sellia admin api-keys list
```

**Optional flags:**

```bash
--server URL    # Server URL (default: from config)
```

**Example output:**

```
API Keys: (3)

  a1b2c3d4  Development Key                    (master)
    Created: 2024-01-15 10:30
  e5f6g7h8  Production API
    Created: 2024-01-20 14:22
  i9j0k1l2  Staging Key                        (revoked)
    Created: 2024-01-10 09:15
```

**Note:** The name column is left-aligned and 20 characters wide. If a key has no name, only the prefix and flags are shown.

**Output fields:**

- `key_prefix` - First 8 characters of the key (for identification)
- `name` - Friendly name provided when created
- `(master)` - Master key with admin access
- `(revoked)` - Key is no longer valid
- `Created` - Timestamp when key was created

**When to use:**

- Auditing who has access to your server
- Finding the prefix for revoking a key
- Checking if a key is a master key
- Verifying key status

### `sellia admin api-keys create`

Create a new API key.

**Usage:**

```bash
# Standard key
sellia admin api-keys create --name "User Key"

# Master key
sellia admin api-keys create --name "Admin Key" --master

# With custom server
sellia admin api-keys create --name "Dev Key" --server https://sellia.example.com
```

**Flags:**

```
--name NAME      # Friendly name for the key (optional)
--master         # Create a master key with admin access (optional)
--server URL     # Server URL (default: from config)
```

**Example output:**

```
✓ API key created

  Key:    9a8b7c6d5e4f3g2h1i2j3k4l5m6n7o8p9q0r1s2t3u4v5w6x7y8z9a0b1c2d3
  Prefix: 9a8b7c6d
  Name:   Development Key
  Type:   Master (admin access)

Save this key now - it won't be shown again!
```

**Important:** The full key is only shown once. Save it securely immediately.

**Best practices:**

1. Always provide a descriptive name
2. Create separate keys for different users/environments
3. Create master keys only for admin users
4. Save the key in a secure password manager
5. Communicate the key via secure channel (encrypted email, password manager, etc.)

**Creating keys for different purposes:**

```bash
# Development key
sellia admin api-keys create --name "Dev Team Key"

# Production key
sellia admin api-keys create --name "Production Service Key"

# CI/CD key
sellia admin api-keys create --name "GitHub Actions"

# Personal admin key
sellia admin api-keys create --name "Alice's Admin Key" --master
```

### `sellia admin api-keys revoke`

Revoke an API key by its prefix.

**Usage:**

```bash
sellia admin api-keys revoke a1b2c3d4
```

**Flags:**

```
--server URL    # Server URL (default: from config)
```

**Example output:**

```
✓ API key 'a1b2c3d4' revoked
```

**What happens:**

1. Key is marked as inactive in database (`active = 0`)
2. Existing tunnels continue to run until disconnected
3. New tunnel creation attempts with this key fail
4. Key prefix still appears in listings with `(revoked)` flag

**When to use:**

- User leaves the organization
- Key is compromised or leaked
- Rotating to a new key
- Service is decommissioned

**Key rotation workflow:**

```bash
# Step 1: Create new key
sellia admin api-keys create --name "New Key"
# Save: key_new_key_here

# Step 2: Update all clients
# Users run: sellia auth login
# Enter new key

# Step 3: Wait for transition period (e.g., 1 week)
# Monitor logs to ensure all clients updated

# Step 4: Revoke old key
sellia admin api-keys revoke old_prefix
```

## Authentication for Admin Commands

### Environment Variable

```bash
export SELLIA_ADMIN_API_KEY="key_master_key"
sellia admin api-keys list
```

### Config File

```yaml
# ~/.config/sellia/sellia.yml
api_key: key_master_key
server: https://sellia.me
```

### Command Flag

```bash
sellia admin api-keys list --server https://sellia.me
# Prompts for API key if not set
```

### Auth Login (Recommended)

```bash
sellia auth login
# Enter master key when prompted

# Now all admin commands work
sellia admin api-keys list
```

## Key Types and Permissions

### Standard API Key

**Can:**
- Create tunnels
- Request available subdomains
- Access inspector features
- Connect to WebSocket endpoints

**Cannot:**
- Access admin API
- Create/revoke API keys
- Manage reserved subdomains
- View other users' tunnels

**Use cases:**
- Individual developers
- Production services
- CI/CD pipelines
- Testing environments

### Master API Key

**Can do everything standard keys can, plus:**
- Access admin API endpoints
- Create new API keys
- Revoke API keys
- Manage reserved subdomains
- View all tunnels and statistics
- Access server metrics

**Use cases:**
- Server administrators
- DevOps engineers
- Security auditors
- Automated admin scripts

**Security considerations:**
- Treat master keys like root passwords
- Never log master keys
- Rotate regularly (90 days recommended)
- Limit to as few users as possible
- Use separate master keys for different environments

## Workflows

### Onboarding a New User

```bash
# 1. Create a key for the new user
sellia admin api-keys create --name "Alice's Key"

# 2. Send key securely (e.g., via password manager)
# Key: key_generated_key_here

# 3. User authenticates
# User runs: sellia auth login
# User enters key

# 4. User creates tunnels
sellia http 3000 --subdomain alice-app
```

### Offboarding a User

```bash
# 1. List keys to find their prefix
sellia admin api-keys list

# 2. Revoke their key
sellia admin api-keys revoke a1b2c3d4

# 3. (Optional) Create audit log entry
echo "$(date) Revoked key for Alice (a1b2c3d4)" >> /var/log/sellia/access.log
```

### Setting Up CI/CD

```bash
# 1. Create a key for the CI system
sellia admin api-keys create --name "GitHub Actions - Production"
# Save key to CI/CD secrets (e.g., GitHub Secrets)

# 2. In CI/CD pipeline
# .github/workflows/deploy.yml
- name: Create tunnel
  run: |
    sellia http 3000 --subdomain myapp-${{ github.sha }}
  env:
    SELLIA_API_KEY: ${{ secrets.SELLIA_API_KEY }}

# 3. If compromised, rotate the key
sellia admin api-keys revoke a1b2c3d4
sellia admin api-keys create --name "GitHub Actions - Production"
# Update CI/CD secret with new key
```

### Environment Separation

```bash
# Development
sellia admin api-keys create --name "Dev Key"
# Distribute to dev team

# Staging
sellia admin api-keys create --name "Staging Key"
# Use for staging environment

# Production
sellia admin api-keys create --name "Production Key"
# Strict access control, audit logging

# Admin
sellia admin api-keys create --name "Ops Admin" --master
# For operations team only
```

## Database Schema

API keys are stored in the `api_keys` table:

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

**Fields:**

- `key_hash` - SHA-256 hash of the key (plaintext key never stored)
- `key_prefix` - First 8 characters (for identification)
- `name` - Friendly name
- `is_master` - True if master key
- `active` - False if revoked
- `created_at` - Timestamp when created
- `last_used_at` - Timestamp of last tunnel creation

**Indexes:**

```sql
CREATE INDEX idx_api_keys_prefix ON api_keys(key_prefix);
CREATE INDEX idx_api_keys_active ON api_keys(active) WHERE active = 1;
```

## Security Best Practices

### Principle of Least Privilege

- Use standard keys for tunnel operations
- Reserve master keys for admin tasks only
- Create separate keys per environment (dev/staging/prod)
- Create separate keys per service/team

### Key Storage

**Do:**
- Store in password managers (1Password, LastPass, etc.)
- Use secret management systems (Vault, AWS Secrets Manager)
- Set file permissions: `chmod 600` on config files
- Use environment variables for CI/CD

**Don't:**
- Commit keys to version control
- Share keys in email/chat
- Log keys in output
- Store in plaintext files

### Key Rotation

Rotate keys periodically:

```bash
#!/bin/bash
# rotate-key.sh - Rotate API keys

# 1. Create new key
NEW_KEY=$(sellia admin api-keys create --name "Rotated Key" | grep "Key:" | awk '{print $2}')

# 2. Update all clients
# (This varies by your setup - update config files, env vars, etc.)

# 3. Wait for confirmation
read -p "Press Enter after updating all clients..."

# 4. Revoke old key
sellia admin api-keys revoke $OLD_PREFIX

echo "Key rotation complete"
```

**Recommended schedule:**
- Master keys: Every 90 days
- Standard keys: Every 180 days
- After any suspected compromise
- When employee leaves organization

### Audit Logging

Maintain an audit trail:

```bash
# Log all key operations
audit() {
  echo "$(date) $@" >> /var/log/sellia/audit.log
}

sellia admin api-keys create --name "New Key"
audit "API key created: New Key"

sellia admin api-keys revoke a1b2c3d4
audit "API key revoked: a1b2c3d4"
```

## Troubleshooting

### "Database Not Available" Error

```
Error: Database not available on server
```

**Cause:** Server started without database.

**Solution:**

```bash
# Start server with database
export SELLIA_DB_PATH="/var/lib/sellia/sellia.db"
sellia-server start
```

### "Unauthorized: Admin API Key Required"

```
Error: Unauthorized: Admin API key required
```

**Cause:** Using a standard key instead of a master key.

**Solution:**

```bash
# Check if your key is a master key
sellia admin api-keys list

# Create a master key if needed
sellia admin api-keys create --master --name "Admin Key"
```

### Key Not Found

```
Error: API key 'a1b2c3d4' not found
```

**Cause:** Trying to revoke a key that doesn't exist.

**Solution:**

```bash
# List keys to find correct prefix
sellia admin api-keys list

# Revoke with correct prefix
sellia admin api-keys revoke correct_prefix
```

### Accidentally Revoked Active Key

If you revoke the wrong key:

```bash
# If you have the full key, you can re-add it
sellia admin api-keys create --name "Restored Key"
# But you'll need the original full key plaintext

# Better: Create a new key and update clients
sellia admin api-keys create --name "Replacement Key"
```

## HTTP API

All CLI commands are wrappers around the HTTP API. You can call it directly:

### List API Keys

```http
GET /api/admin/api-keys
Authorization: Bearer <master-key>
```

### Create API Key

```http
POST /api/admin/api-keys
Authorization: Bearer <master-key>
Content-Type: application/json

{
  "name": "My Key",
  "is_master": false
}
```

### Revoke API Key

```http
DELETE /api/admin/api-keys/:prefix
Authorization: Bearer <master-key>
```

See [Admin API](./admin-api.md) for full API reference.

## See Also

- [API Keys](../authentication/api-keys.md) - API key concepts and types
- [Auth Command](../authentication/sellia-auth-command.md) - Client-side key management
- [Server Auth](../authentication/server-auth.md) - Server-side authentication
- [Admin API](./admin-api.md) - Complete HTTP API reference
