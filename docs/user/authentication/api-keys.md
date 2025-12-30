# API Keys

API keys are used to authenticate tunnel clients with the Sellia server. They provide secure access control and enable features like reserved subdomains and admin operations.

## Overview

API keys in Sellia serve several purposes:

1. **Authentication**: Verify tunnel clients are authorized
2. **Access Control**: Restrict server usage to authorized users
3. **Account Association**: Link tunnels to accounts for management
4. **Admin Operations**: Enable admin API access (master keys)

## Key Types

### Standard API Keys

Standard keys allow tunnel creation and basic operations:

```yaml
# Create via admin CLI or API
sellia admin api-keys create --name "My Development Key"
```

**Capabilities:**
- Create tunnels
- Request subdomains
- Basic tunnel operations

**Limitations:**
- Cannot access admin API
- Cannot manage reserved subdomains
- Cannot create/revoke other keys

### Master API Keys

Master keys have full administrative access:

```yaml
# Create master key
sellia admin api-keys create --name "Admin Key" --master
```

**Capabilities:**
- All standard key permissions
- Access admin API endpoints
- Create and revoke API keys
- Manage reserved subdomains
- View all tunnels and metrics

**Security Note:** Treat master keys like passwords. Never share them or commit them to version control.

## Key Format

API keys are 64-character hexadecimal strings:

```
a1b2c3d4e5f67890abcdef1234567890abcdef1234567890abcdef1234567890
```

For identification, only the first 8 characters (prefix) are displayed in listings:

```
a1b2c3d4  (master)
```

## Key Storage

### Client-Side

API keys are stored in `~/.config/sellia/sellia.yml`:

```yaml
api_key: a1b2c3d4e5f67890abcdef1234567890abcdef1234567890abcdef1234567890
server: https://sellia.me
```

**Security:**
- File permissions should be `0600` (user read/write only)
- Never commit to version control
- Use environment variables for CI/CD

### Server-Side

Only the SHA-256 hash of the key is stored:

```
key_hash: 2cf24dba5fb0a30e... (SHA-256 hash)
key_prefix: a1b2c3d4 (first 8 chars for identification)
```

The raw API key is **never stored** and only shown once during creation.

## Obtaining an API Key

### From a Server Admin

Contact your Sellia server administrator to request an API key. They can create one for you using the admin CLI.

### Self-Hosted Servers

If you're running your own server, generate a master key:

```bash
# Set master key in server config or environment
export SELLIA_MASTER_KEY="your-generated-key-here"
```

Then use that key to create additional keys via the admin API.

## Using API Keys

### Environment Variable

```bash
export SELLIA_API_KEY="a1b2c3d4e5f6..."
sellia http 3000
```

### Config File

```yaml
# ~/.config/sellia/sellia.yml
api_key: a1b2c3d4e5f6...
server: https://sellia.me
```

### Command Line Flag

```bash
sellia http 3000 --api-key a1b2c3d4e5f6...
```

### Auth Login (Recommended)

```bash
sellia auth login
# Enter 64-character hex API key when prompted
```

This saves the key securely to your config file.

## Key Management

### Viewing Your Keys

List all API keys (requires admin access):

```bash
sellia admin api-keys list
```

Output:
```
API Keys: (3)

  a1b2c3d4  Development Key                    (master)
  e5f6g7h8  Production API
  i9j0k1l2  Staging Key        (revoked)
```

### Creating Keys

Create a standard key:

```bash
sellia admin api-keys create --name "Production API"
```

Create a master key:

```bash
sellia admin api-keys create --name "Admin Key" --master
```

**Important:** Save the key immediately. It won't be shown again.

### Revoking Keys

Revoke a key by its prefix:

```bash
sellia admin api-keys revoke a1b2c3d4
```

Revoked keys cannot be used to create new tunnels (existing tunnels continue until they disconnect).

## Security Best Practices

### Key Rotation

Regularly rotate API keys:

1. Create a new key
2. Update all clients to use the new key
3. Revoke the old key

```bash
# Step 1: Create new key
sellia admin api-keys create --name "New Key"
# Save the key: key_newkey...

# Step 2: Update clients
sellia auth login
# Enter new key

# Step 3: Revoke old key
sellia admin api-keys revoke a1b2c3d4
```

### Principle of Least Privilege

- Use standard keys for normal tunnel operations
- Reserve master keys for admin tasks only
- Create separate keys for different environments (dev, staging, prod)

### Key Storage

**Do:**
- Store keys in environment variables for CI/CD
- Use secret management tools (Vault, AWS Secrets Manager, etc.)
- Set proper file permissions on config files (`chmod 600`)

**Don't:**
- Commit keys to version control
- Share keys in email or chat
- Log keys in output or error messages
- Use keys in URLs (they may be logged)

### Detecting Compromised Keys

Signs a key may be compromised:

- Unexpected tunnels appearing
- Spike in traffic from unknown locations
- Failed authentication attempts in server logs

If you suspect compromise:

1. Immediately revoke the key
2. Create a new key
3. Update all legitimate clients
4. Investigate the source of the leak

## Authentication Flow

### Tunnel Connection

1. Client connects to server via WebSocket
2. Client sends authentication message with API key
3. Server validates key against database or master key
4. Server returns account ID and tunnel registration
5. Tunnel is established

### Admin API

1. Client makes HTTP request with `Authorization: Bearer <key>` or `X-API-Key: <key>`
2. Server validates key is a master key
3. Server checks key is active (not revoked)
4. Request is processed

## Troubleshooting

### Invalid API Key

```
Error: Authentication failed: Invalid API key
```

**Solutions:**
- Verify key is correct (check for typos)
- Ensure key hasn't been revoked
- Check you're using the right server URL

### Unauthorized for Admin Operations

```
Error: Unauthorized: Admin API key required
```

**Solutions:**
- Verify the key is a master key (check with `sellia admin api-keys list`)
- Create a new master key if needed

### Key Not Found After Login

```bash
sellia auth status
# Status: Not logged in
```

**Solutions:**
- Check `~/.config/sellia/sellia.yml` exists
- Verify the file contains `api_key:`
- Try logging in again

## See Also

- [Auth Command](./sellia-auth-command.md) - Saving and managing API keys
- [Server Auth](./server-auth.md) - Server-side authentication configuration
- [Admin API](../admin/admin-api.md) - Admin API reference
- [API Key Management](../admin/api-key-management.md) - Creating and revoking keys
