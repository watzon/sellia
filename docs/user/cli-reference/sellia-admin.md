# `sellia admin` - Admin Commands

Administrative commands for managing reserved subdomains and API keys. Requires an admin API key.

## Synopsis

```bash
sellia admin <command> [options]
```

## Description

Admin commands allow server administrators to manage:
- Reserved subdomains (prevent users from claiming specific subdomains)
- API keys (create, list, and revoke user and master keys)

These commands require an admin API key with master privileges.

## Authentication

Admin commands require authentication. Provide your admin API key via:

1. **Environment variable** (recommended):
   ```bash
   export SELLIA_ADMIN_API_KEY=sk_master_xyz
   sellia admin reserved list
   ```

2. **Login first**:
   ```bash
   sellia auth login
   # Enter admin key when prompted
   sellia admin reserved list
   ```

The admin API key must have master privileges to perform these operations.

## Commands

### `reserved`

Manage reserved subdomains.

- `reserved list` - List all reserved subdomains
- `reserved add` - Add a reserved subdomain
- `reserved remove` - Remove a reserved subdomain

### `api-keys`

Manage API keys.

- `api-keys list` - List all API keys
- `api-keys create` - Create a new API key
- `api-keys revoke` - Revoke an API key

## Common Options

### `--server URL`

Specify the tunnel server URL (default: from config or `https://sellia.me`).

**Example:**
```bash
sellia admin reserved list --server https://tunnel.example.com
```

## Reserved Subdomain Commands

### `sellia admin reserved list`

List all reserved subdomains on the server.

#### Synopsis

```bash
sellia admin reserved list [--server URL]
```

#### Options

- `--server URL` - Server URL (default: from config)

#### Usage

```bash
sellia admin reserved list
```

#### Output

```
Reserved Subdomains: (3)

  admin       System reserved subdomain                  (default)
  www         Standard web subdomain                     (default)
  myapp       Reserved for customer XYZ
```

#### Exit Codes

- `0` - Success
- `1` - Authentication failed or server error
- `503` - Database not available on server

### `sellia admin reserved add`

Add a new reserved subdomain to prevent users from claiming it.

#### Synopsis

```bash
sellia admin reserved add <subdomain> [--reason REASON] [--server URL]
```

#### Arguments

- `<subdomain>` - Subdomain name to reserve (without domain)

#### Options

- `--reason REASON` - Optional reason for the reservation
- `--server URL` - Server URL (default: from config)

#### Usage

```bash
# Basic reservation
sellia admin reserved add myapp

# With reason
sellia admin reserved add myapp --reason "Reserved for customer XYZ"

# With custom server
sellia admin reserved add admin --server https://tunnel.example.com
```

#### Output

```
✓ Reserved subdomain 'myapp'
  Reason: Reserved for customer XYZ
```

#### Errors

```
Error: Subdomain 'myapp' is already reserved
```

```
Error: Invalid request
```

```
Error: Unauthorized: Admin API key required
```

```
Error: Database not available on server
```

### `sellia admin reserved remove`

Remove a reserved subdomain, making it available for users.

#### Synopsis

```bash
sellia admin reserved remove <subdomain> [--server URL]
```

#### Arguments

- `<subdomain>` - Subdomain name to unreserve

#### Options

- `--server URL` - Server URL (default: from config)

#### Usage

```bash
sellia admin reserved remove myapp
```

#### Output

```
✓ Removed reserved subdomain 'myapp'
```

#### Errors

```
Error: Cannot remove default reserved subdomain
```

```
Error: Reserved subdomain 'myapp' not found
```

```
Error: Unauthorized: Admin API key required
```

```
Error: Database not available on server
```

**Note:** Default reserved subdomains (like `admin`, `www`) cannot be removed.

## API Key Commands

### `sellia admin api-keys list`

List all API keys in the system.

#### Synopsis

```bash
sellia admin api-keys list [--server URL]
```

#### Options

- `--server URL` - Server URL (default: from config)

#### Usage

```bash
sellia admin api-keys list
```

#### Output

```
API Keys: (3)

  key_abc  Production Admin      (master)
    Created: 2025-01-15 10:30

  key_def  Development Team
    Created: 2025-01-20 14:22

  key_ghi  Test Key              (revoked)
    Created: 2025-01-10 09:15
```

- `(master)` - Key has admin privileges (displayed in red/bold)
- `(revoked)` - Key has been revoked and is inactive (displayed in gray)

#### Exit Codes

- `0` - Success
- `1` - Authentication failed or server error
- `503` - Database not available on server

### `sellia admin api-keys create`

Create a new API key.

#### Synopsis

```bash
sellia admin api-keys create [--name NAME] [--master] [--server URL]
```

#### Options

- `--name NAME` - Friendly name for the key (optional)
- `--master` - Create a master key with admin privileges
- `--server URL` - Server URL (default: from config)

#### Usage

```bash
# Create regular user key
sellia admin api-keys create

# Create named key
sellia admin api-keys create --name "Development Team"

# Create master admin key
sellia admin api-keys create --master --name "Admin Key"
```

#### Output

```
✓ API key created

  Key: key_xyz123abcdef456789...
  Prefix: key_xyz
  Name: Development Team

Save this key now - it won't be shown again!
```

For master keys, the output includes:

```
✓ API key created

  Key: key_xyz123abcdef456789...
  Prefix: key_xyz
  Name: Admin Key
  Type: Master (admin access)

Save this key now - it won't be shown again!
```

**Important:** The full API key is only shown once. Save it securely.

#### Key Types

- **Regular key** - Can create tunnels, cannot perform admin operations
- **Master key** (`--master`) - Full admin access to reserved subdomains and API key management

#### Errors

```
Error: Unauthorized: Admin API key required
```

```
Error: Database not available on server
```

### `sellia admin api-keys revoke`

Revoke an API key, making it inactive.

#### Synopsis

```bash
sellia admin api-keys revoke <key-prefix> [--server URL]
```

#### Arguments

- `<key-prefix>` - Key prefix to revoke (e.g., `key_abc`)

#### Options

- `--server URL` - Server URL (default: from config)

#### Usage

```bash
sellia admin api-keys revoke key_abc
```

#### Output

```
✓ API key 'key_abc' revoked
```

#### Errors

```
Error: API key 'key_abc' not found
```

```
Error: Unauthorized: Admin API key required
```

```
Error: Database not available on server
```

**Note:** Revoked keys are marked as inactive but remain in the database for audit purposes.

## Usage Examples

### Reserve subdomains for a customer

```bash
# Reserve main subdomain
sellia admin reserved add myapp --reason "Reserved for Acme Corp"

# Reserve related subdomains
sellia admin reserved add myapp-api --reason "API server for Acme Corp"
sellia admin reserved add myapp-admin --reason "Admin panel for Acme Corp"
```

### Create API keys for different teams

```bash
# Development team key
sellia admin api-keys create --name "Development Team"

# Staging key
sellia admin api-keys create --name "Staging Environment"

# Production master key
sellia admin api-keys create --master --name "Production Admin"
```

### Audit API keys

```bash
$ sellia admin api-keys list
API Keys: (5)

  key_abc  Production Admin      (master)
    Created: 2025-01-15 10:30

  key_def  Development Team
    Created: 2025-01-20 14:22

  key_ghi  Staging Environment
    Created: 2025-01-22 09:45

  key_jkl  Old Key               (revoked)
    Created: 2025-01-10 09:15
```

### Clean up old keys

```bash
# List keys to find old ones
sellia admin api-keys list

# Revoke compromised or expired keys
sellia admin api-keys revoke key_old
```

## Managing Multiple Servers

If you manage multiple tunnel servers, use `--server`:

```bash
# Production server
export SELLIA_ADMIN_API_KEY=prod_master_key
sellia admin reserved list --server https://sellia.me

# Staging server
sellia admin reserved list --server https://staging.sellia.me

# Development server
sellia admin reserved list --server http://localhost:8080
```

## Exit Codes

- `0` - Command completed successfully
- `1` - Error (authentication, invalid input, server error)

## Common Error Messages

### Authentication Errors

```
Error: API key required

Set it with:
  SELLIA_ADMIN_API_KEY=your-key sellia admin ...
  sellia auth login
```

**Solution:** Set the `SELLIA_ADMIN_API_KEY` environment variable or run `sellia auth login` with an admin key.

### Database Errors

```
Error: Database not available on server
```

**Solution:** The server's database is not configured or available. Contact your server administrator.

### Permission Errors

```
Error: Unauthorized: Admin API key required
```

**Solution:** Your API key doesn't have master (admin) privileges. Use a master key for admin operations.

## Related Commands

- [`sellia auth`](./sellia-auth.md) - Manage API key authentication
- [`sellia http`](./sellia-http.md) - Create tunnels (regular user operation)
- [`sellia start`](./sellia-start.md) - Start multiple tunnels from config
