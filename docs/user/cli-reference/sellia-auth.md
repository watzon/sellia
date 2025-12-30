# `sellia auth` - Manage Authentication

Manage Sellia API key authentication.

## Synopsis

```bash
sellia auth <command>
```

## Description

The `auth` command manages your Sellia API key for tunnel server authentication. This allows you to authenticate once and have all subsequent commands use your saved credentials.

Authentication is required for:
- Creating tunnels with reserved subdomains
- Accessing admin features
- Using private tunnel servers

## Commands

### `login`

Save API key for authentication.

### `logout`

Remove saved API key.

### `status`

Show current authentication status.

## Command Details

### `sellia auth login`

Prompts for and saves your API key to the configuration file.

#### Usage

```bash
sellia auth login
```

The command will prompt:

```
API Key: _
```

Enter your API key and press Enter. The key is saved to `~/.config/sellia/sellia.yml`.

#### Configuration File

After login, your config file contains:

```yaml
api_key: key_abc123def456...
server: https://sellia.me
```

#### Security

- The API key is stored in plain text in `~/.config/sellia/sellia.yml`
- File permissions depend on your system's umask
- Ensure your config directory is appropriately secured

#### Output

```
✓ API key saved to /home/user/.config/sellia/sellia.yml
```

#### Error

If no API key is provided:

```
Error: No API key provided
```

### `sellia auth logout`

Removes the saved API key from your configuration.

#### Usage

```bash
sellia auth logout
```

#### Behavior

- Opens your config file and removes the `api_key` field
- If the config file becomes empty or invalid, it's deleted entirely
- Other configuration (server, tunnels, etc.) is preserved

#### Output

When logged in:

```
✓ Logged out (API key removed)
```

When not logged in:

```
Not logged in
```

### `sellia auth status`

Display your current authentication status and masked API key.

#### Usage

```bash
sellia auth status
```

#### Output When Authenticated

```
Status: Logged in
Server: https://sellia.me
API Key: sk_l...ef45
```

The API key is masked for security - if the key is longer than 8 characters, only the first 4 and last 4 characters are shown. Otherwise, it shows `****`.

#### Output When Not Authenticated

```
Status: Not logged in
Server: https://sellia.me

Run 'sellia auth login' to authenticate
```

## Configuration File Location

The auth command stores credentials in:

```
~/.config/sellia/sellia.yml
```

This file is also used for other configuration settings.

## Usage Examples

### Login for the first time

```bash
$ sellia auth login
API Key: key_abc123def456...
✓ API key saved to /home/user/.config/sellia/sellia.yml
```

### Check authentication status

```bash
$ sellia auth status
Status: Logged in
Server: https://sellia.me
API Key: sk_l...ef45
```

### Logout and clear credentials

```bash
$ sellia auth logout
✓ Logged out (API key removed)
```

### Login and use tunnel

```bash
# Authenticate once
$ sellia auth login
API Key: ********
✓ API key saved

# Now all commands use the saved key
$ sellia http 3000 --subdomain myapp
# No need to specify --api-key
```

## Alternative Authentication Methods

You don't have to use `sellia auth login`. You can also:

### 1. Use `--api-key` flag

```bash
sellia http 3000 --api-key key_abc123
```

### 2. Use environment variable

```bash
export SELLIA_API_KEY=key_abc123
sellia http 3000
```

### 3. Add to config file manually

Edit `~/.config/sellia/sellia.yml`:

```yaml
api_key: key_abc123
```

## Admin API Keys

Some admin commands require an admin API key:

```bash
SELLIA_ADMIN_API_KEY=sk_master_xyz sellia admin reserved list
```

The `sellia auth login` command saves the key to the regular `api_key` field, which works for both regular and admin operations if the key has admin privileges.

## Integration with Other Commands

Once authenticated, all commands automatically use your saved API key:

```bash
# Login once
$ sellia auth login

# Now all commands work without --api-key
$ sellia http 3000
$ sellia start
$ sellia admin reserved list
```

## Exit Codes

- `0` - Command completed successfully
- `1` - Error occurred (no API key provided, etc.)

## Related Commands

- [`sellia http`](./sellia-http.md) - Create tunnels with automatic authentication
- [`sellia start`](./sellia-start.md) - Start tunnels from config
- [`sellia admin`](./sellia-admin.md) - Admin commands requiring authentication
