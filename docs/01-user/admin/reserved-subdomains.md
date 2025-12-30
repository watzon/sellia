# Reserved Subdomains

Reserved subdomains prevent users from claiming specific subdomains for tunnels. This is useful for protecting service URLs, brand names, or system endpoints.

## Overview

When a subdomain is reserved, tunnel clients cannot request it. The server will reject the request with an error:

```
Error: Subdomain 'api' is reserved
```

## Default Reserved Subdomains

Sellia ships with a default set of reserved subdomains:

**System services:**
- `api`, `www`, `admin`, `app`, `dashboard`, `console`
- `mail`, `smtp`, `imap`, `pop`, `ftp`, `ssh`, `sftp`

**Infrastructure:**
- `cdn`, `static`, `assets`, `media`, `images`, `files`
- `auth`, `login`, `oauth`, `sso`, `account`, `accounts`

**Business:**
- `billing`, `pay`, `payment`, `payments`, `subscribe`
- `help`, `support`, `docs`, `documentation`, `status`

**Development:**
- `blog`, `news`, `forum`, `community`, `dev`, `developer`
- `test`, `staging`, `demo`, `sandbox`, `preview`

**Protocols:**
- `ws`, `wss`, `socket`, `websocket`, `stream`

**Development tools:**
- `git`, `svn`, `repo`, `registry`, `npm`, `pypi`

**System:**
- `internal`, `private`, `public`, `local`, `localhost`
- `root`, `system`, `server`, `servers`, `node`, `nodes`

**Sellia-specific:**
- `sellia`, `tunnel`, `tunnels`, `proxy`

## Managing Reserved Subdomains

### List Reserved Subdomains

View all reserved subdomains:

```bash
sellia admin reserved list
```

**Example output:**

```
Reserved Subdomains: (50)

  api                            Default reserved subdomain  (default)
  admin                          Default reserved subdomain  (default)
  cdn                            Default reserved subdomain  (default)
  ...
  mycompany                      Company name
  billing                        Payment system
```

Flags:
- `(default)` - Shipped with Sellia, cannot be removed

### Add a Reserved Subdomain

Prevent users from claiming a specific subdomain:

```bash
sellia admin reserved add mycompany
```

With a reason (for documentation):

```bash
sellia admin reserved add billing --reason "Payment processing service"
```

**Requirements:**

- Minimum 3 characters
- Maximum 63 characters
- Only lowercase letters, numbers, and hyphens (case-insensitive, converted to lowercase)
- Must start and end with alphanumeric character
- No consecutive hyphens enforced by pattern matching

**Valid names:**
- `my-app`
- `api-v2`
- `service123`

**Invalid names:**
- `-bad` (starts with hyphen)
- `bad-` (ends with hyphen)
- `ab` (too short)
- (Uppercase is converted to lowercase, but mixed case allowed in input)

**Error examples:**

```
Error: Subdomain 'ab' must be at least 3 characters
Error: Subdomain must be at most 63 characters
Error: Subdomain can only contain lowercase letters, numbers, and hyphens
Error: Subdomain 'mycompany' is already reserved
```

### Remove a Reserved Subdomain

Allow users to claim a subdomain again:

```bash
sellia admin reserved remove mycompany
```

**Output:**

```
✓ Removed reserved subdomain 'mycompany'
```

**Limitations:**

- Default reserved subdomains (shipped with Sellia) cannot be removed
- Attempts to remove default subdomains return an error:

  ```
  Error: Cannot remove default reserved subdomain
  ```

## Use Cases

### Protect Service Endpoints

Reserve subdomains for your actual services:

```bash
# Reserve service URLs
sellia admin reserved add api --reason "API gateway"
sellia admin reserved add admin --reason "Admin panel"
sellia admin reserved add dashboard --reason "Analytics dashboard"
sellia admin reserved add billing --reason "Payment system"
```

Now you can safely run these services without users conflicting:

- `api.yourdomain.com` - Your API gateway
- `admin.yourdomain.com` - Your admin panel
- `dashboard.yourdomain.com` - Your analytics
- Users cannot claim these subdomains for tunnels

### Brand Protection

Prevent typosquatting and protect your brand:

```bash
sellia admin reserved add mycompany
sellia admin reserved add myco
sellia admin reserved add my-company
sellia admin reserved add mycompanyapp
```

### Future Planning

Reserve subdomains for planned features:

```bash
sellia admin reserved add blog --reason "Coming soon"
sellia admin reserved add shop --reason "E-commerce launch Q2"
sellia admin reserved add community --reason "Forum planned"
```

### Department Isolation

Reserve subdomains for different teams:

```bash
sellia admin reserved add engineering
sellia admin reserved add marketing
sellia admin reserved add sales
sellia admin reserved add support
```

## Subdomain Validation Rules

### Format Requirements

Subdomains must follow RFC 1035 rules:

1. **Length:** 3-63 characters
2. **Characters:** a-z, 0-9, hyphen (-) (case-insensitive)
3. **No leading/trailing hyphens:** `-myapp` or `myapp-` is invalid
4. **Case insensitive:** `MyApp` → `myapp`

### Pattern Matching

Server validation uses this regex (case-insensitive):

```regex
\A[a-z0-9][a-z0-9-]*[a-z0-9]\z/i
```

This allows:
- Letters (a-z, case-insensitive)
- Numbers (0-9)
- Hyphens (-) in the middle
- Must start and end with alphanumeric character

### Examples

**Valid:**
- `myapp`
- `my-app`
- `app-v2`
- `service123`
- `MYAPP` (converted to lowercase: `myapp`)

**Invalid:**
- `-myapp` (starts with hyphen)
- `myapp-` (ends with hyphen)
- `ab` (too short)
- `a` * 64 characters (too long)

## Database Schema

Reserved subdomains are stored in the `reserved_subdomains` table:

```sql
CREATE TABLE reserved_subdomains (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    subdomain TEXT NOT NULL UNIQUE,
    reason TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    is_default BOOLEAN NOT NULL DEFAULT 0
);
```

**Fields:**

- `subdomain` - The reserved subdomain (unique)
- `reason` - Optional reason/documentation
- `is_default` - True if shipped with Sellia (cannot be removed)
- `created_at` - Timestamp when reserved

## Server Integration

### Tunnel Registration

When a client requests a subdomain:

1. Client sends `TunnelRegister` message with desired subdomain
2. Server checks `reserved_subdomains` table
3. If reserved → reject with error
4. If available → proceed with tunnel registration

### Real-time Updates

The server reloads reserved subdomains when:

1. A subdomain is added via admin API
2. A subdomain is removed via admin API
3. Server starts (loads from database)

No restart required - changes take effect immediately.

## HTTP API

### List Reserved Subdomains

```http
GET /api/admin/reserved
Authorization: Bearer <master-key>
```

**Response:**

```json
[
  {
    "subdomain": "api",
    "reason": "Default reserved subdomain",
    "is_default": true,
    "created_at": "2024-01-01T00:00:00.000000Z"
  },
  {
    "subdomain": "billing",
    "reason": "Payment system",
    "is_default": false,
    "created_at": "2024-01-15T10:30:00.000000Z"
  }
]
```

### Add Reserved Subdomain

```http
POST /api/admin/reserved
Authorization: Bearer <master-key>
Content-Type: application/json

{
  "subdomain": "mycompany",
  "reason": "Company name protection"
}
```

**Response:** 201 Created

```json
{
  "subdomain": "mycompany",
  "reason": "Company name protection",
  "is_default": false,
  "created_at": "2024-01-15T10:30:00.000000Z"
}
```

**Error responses:**

- 400 Bad Request - Invalid subdomain format
- 409 Conflict - Already reserved
- 401 Unauthorized - Not a master key
- 503 Service Unavailable - Database not available

### Remove Reserved Subdomain

```http
DELETE /api/admin/reserved/:subdomain
Authorization: Bearer <master-key>
```

**Response:** 200 OK

```json
{
  "message": "Reserved subdomain 'mycompany' removed"
}
```

**Error responses:**

- 403 Forbidden - Attempting to remove default reserved subdomain
- 404 Not Found - Subdomain not in reserved list
- 401 Unauthorized - Not a master key
- 503 Service Unavailable - Database not available

## Best Practices

### Reserve Early

Add reserved subdomains before opening your server to users:

```bash
# Initial setup script
#!/bin/bash
# Reserve company domains
sellia admin reserved add mycompany
sellia admin reserved add myco
sellia admin reserved add my-company

# Reserve service domains
sellia admin reserved add api
sellia admin reserved add admin
sellia admin reserved add dashboard
```

### Document Reasons

Always include reasons for custom reservations:

```bash
sellia admin reserved add billing --reason "Stripe integration"
sellia admin reserved add legacy --reason "Old system migration"
```

This helps future administrators understand why each subdomain is reserved.

### Regular Audits

Periodically review reserved subdomains:

```bash
# List all with reasons
sellia admin reserved list

# Ask yourself:
# - Is this still needed?
# - Is the reason clear?
# - Should we add anything new?
```

### Don't Over-Reserve

Reserving too many subdomains frustrates users:

- **Do:** Reserve actual services and brand names
- **Don't:** Reserve every possible word

A good rule of thumb: Keep reserved subdomains under 100 for a typical installation.

## Troubleshooting

### "Subdomain is Reserved" Error

User sees this error when trying to create a tunnel:

```bash
$ sellia http 3000 --subdomain api
Error: Subdomain 'api' is reserved
```

**Solutions:**

1. **Choose a different subdomain:**
   ```bash
   sellia http 3000 --subdomain myapi
   ```

2. **Check if the reservation is necessary:**
   ```bash
   sellia admin reserved list | grep api
   ```

3. **Remove reservation if not needed (non-default only):**
   ```bash
   sellia admin reserved remove custom-reserved
   ```

### Database Not Available

Admin commands fail with:

```
Error: Database not available on server
```

**Cause:** Server started without database enabled.

**Solution:**

```bash
# Start server with database
export SELLIA_DB_PATH="/var/lib/sellia/sellia.db"
sellia-server start
```

### Cannot Remove Default Subdomain

Attempting to remove a default reserved subdomain:

```bash
$ sellia admin reserved remove api
Error: Cannot remove default reserved subdomain
```

**Explanation:** Default subdomains are protected and cannot be removed. This prevents accidentally opening security holes.

**Workaround:** If you must use a default subdomain:

1. Run your service on a different subdomain
2. Or modify the server code to remove the default (not recommended)

## See Also

- [Admin API](../admin/admin-api.md) - Complete HTTP API reference
- [API Key Management](../admin/api-key-management.md) - Managing admin access
- [Server Auth](../authentication/server-auth.md) - Authentication configuration
- [Path-Based Routing](../tunnels/path-routing.md) - Advanced routing features
