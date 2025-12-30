# Auth Command

The `sellia auth` command manages your API key authentication with Sellia servers. Use it to save, view, and remove your API credentials.

## Commands

### `sellia auth login`

Save your API key for authentication.

**Usage:**

```bash
sellia auth login
```

**What it does:**

1. Prompts you to enter your API key
2. Saves the key to `~/.config/sellia/sellia.yml`
3. Creates the config directory if it doesn't exist
4. Merges with any existing configuration

**Example:**

```bash
$ sellia auth login
API Key: a1b2c3d4e5f6...
✓ API key saved to /home/user/.config/sellia/sellia.yml
```

**Config file created:**

```yaml
# ~/.config/sellia/sellia.yml
api_key: a1b2c3d4e5f6...
server: https://sellia.me
```

**When to use:**

- Setting up Sellia for the first time
- After receiving an API key from your server admin
- Rotating to a new API key

### `sellia auth logout`

Remove your saved API key.

**Usage:**

```bash
sellia auth logout
```

**What it does:**

1. Reads your config file
2. Removes the `api_key` field
3. Writes the updated config back to disk
4. If config parsing fails, deletes the entire file

**Example:**

```bash
$ sellia auth logout
✓ Logged out (API key removed)
```

**When to use:**

- Revoking your old API key
- Switching to a different account
- Decommissioning a development machine

**Note:** This doesn't revoke the key on the server. Use `sellia admin api-keys revoke` for that.

### `sellia auth status`

Show your current authentication status.

**Usage:**

```bash
sellia auth status
```

**What it shows:**

- Whether you're logged in
- The server URL you're authenticated with
- A masked version of your API key (first 4 and last 4 characters)

**Examples:**

**Logged in:**

```bash
$ sellia auth status
Status: Logged in
Server: https://sellia.me
API Key: sk_l...1234
```

**Not logged in:**

```bash
$ sellia auth status
Status: Not logged in
Server: https://sellia.me

Run 'sellia auth login' to authenticate
```

**When to use:**

- Verifying your credentials before creating tunnels
- Troubleshooting authentication issues
- Checking which server you're configured to use

## Authentication Methods

The auth command is just one way to provide your API key. Sellia checks multiple sources in order of priority:

### Priority Order

1. **Environment variable** (highest priority)
   ```bash
   export SELLIA_API_KEY="sk_live_..."
   sellia http 3000
   ```

2. **Command-line flag**
   ```bash
   sellia http 3000 --api-key sk_live_...
   ```

3. **Config file** (set by `auth login`)
   ```yaml
   # ~/.config/sellia/sellia.yml
   api_key: sk_live_...
   ```

The first value found is used. Environment variables override config files.

### Recommended Approach

**Development:** Use `auth login` for convenience
```bash
sellia auth login
sellia http 3000  # Uses saved key
```

**CI/CD:** Use environment variables
```bash
export SELLIA_API_KEY="${{ secrets.SELLIA_API_KEY }}"
sellia http 3000
```

**One-off tunnels:** Use command-line flag
```bash
sellia http 3000 --api-key sk_live_...
```

## Config File Locations

The auth command saves to `~/.config/sellia/sellia.yml`, but Sellia loads config from multiple locations:

### Load Order (low to high priority)

1. `~/.config/sellia/sellia.yml`
2. `~/.sellia.yml`
3. `./sellia.yml` (current directory)
4. Environment variables (highest priority)

Later configs override earlier ones. This allows for per-project overrides.

### Example: Per-Project Config

**Global config:**
```yaml
# ~/.config/sellia/sellia.yml
api_key: sk_live_global_key
server: https://sellia.me
```

**Project override:**
```yaml
# ./sellia.yml
api_key: sk_live_project_key
tunnels:
  app:
    port: 3000
```

Result: The project-specific key is used when running from that directory.

## Troubleshooting

### "API key required" Error

```
Error: API key required
```

**Cause:** No API key found in any source.

**Solutions:**

1. Check your auth status:
   ```bash
   sellia auth status
   ```

2. Log in if needed:
   ```bash
   sellia auth login
   ```

3. Or provide via environment variable:
   ```bash
   export SELLIA_API_KEY="your-key"
   ```

### Config File Not Found

After running `auth login`, you get "Not logged in" from `auth status`.

**Possible causes:**

1. File permissions issue
2. Config directory not writable
3. Disk full

**Debug steps:**

```bash
# Check if config directory exists
ls -la ~/.config/sellia/

# Check file permissions
cat ~/.config/sellia/sellia.yml

# Try manually creating directory
mkdir -p ~/.config/sellia
chmod 755 ~/.config/sellia
```

### Wrong Server

```bash
$ sellia auth status
Status: Logged in
Server: https://old-server.example
```

**Solution:** The server URL is also saved in config. You can override it:

```bash
# Via environment variable
export SELLIA_SERVER="https://new-server.example"

# Or edit the config file directly
nano ~/.config/sellia/sellia.yml
```

### Multiple Keys Conflict

If you have keys in multiple sources, you might be confused about which is being used.

**Check what's being used:**

```bash
# Check environment variables
echo $SELLIA_API_KEY

# Check global config
cat ~/.config/sellia/sellia.yml

# Check local config
cat ./sellia.yml
```

**Clear conflicting sources:**

```bash
# Unset environment variable
unset SELLIA_API_KEY

# Remove local config
rm ./sellia.yml

# Now only global config is used
```

## Security Considerations

### Config File Permissions

The auth command creates the config with default permissions. On Unix-like systems, you should restrict access:

```bash
chmod 600 ~/.config/sellia/sellia.yml
```

This allows only you (the file owner) to read and write the file.

### Shared Machines

On shared or multi-user systems:

1. **Don't use auth login** - it saves to disk
2. Use environment variables instead:
   ```bash
   export SELLIA_API_KEY="your-key"
   sellia http 3000
   unset SELLIA_API_KEY  # Clear when done
   ```

3. Or use command-line flag (not saved in shell history):
   ```bash
   sellia http 3000 --api-key "your-key"
   ```

### Version Control

Never commit the config file. Add to `.gitignore`:

```bash
echo ".config/sellia/" >> ~/.gitignore
echo "sellia.yml" >> .gitignore  # For project-specific configs
```

## Integration with Other Tools

### Docker

```dockerfile
# Don't use auth login in Docker
# Instead, use environment variables

ENV SELLIA_API_KEY=${SELLIA_API_KEY}
```

```bash
docker run -e SELLIA_API_KEY="your-key" sellia http 3000
```

### Systemd

```ini
# /etc/systemd/system/sellia.service
[Service]
Environment="SELLIA_API_KEY=your-key"
ExecStart=/usr/local/bin/sellia start
```

### CI/CD

**GitHub Actions:**
```yaml
- name: Create tunnel
  run: sellia http 3000
  env:
    SELLIA_API_KEY: ${{ secrets.SELLIA_API_KEY }}
```

**GitLab CI:**
```yaml
create_tunnel:
  script:
    - sellia http 3000
  variables:
    SELLIA_API_KEY: $SELLIA_API_KEY
```

## See Also

- [API Keys](./api-keys.md) - Understanding API key types and usage
- [Server Auth](./server-auth.md) - Server-side authentication
- [Configuration](../configuration/) - Full config file reference
