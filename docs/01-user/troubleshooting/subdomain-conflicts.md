# Subdomain Conflicts Troubleshooting

Guide to resolving "subdomain already in use" errors.

## Common Problems

### "Subdomain Already in Use"

**Symptoms**:
- Error: "Subdomain 'myapp' is not available"
- Tunnel creation fails
- Server sends `TunnelClose` with "not available" reason

**Diagnosis**:

1. Check if tunnel exists:
```bash
curl http://your-server.com/health

# Expected output:
# {"status":"ok","tunnels":5}
```

2. Try to access subdomain:
```bash
curl http://myapp.your-domain.com
```

3. Check server logs:
```bash
tail -f /var/log/sellia/server.log | grep "myapp"
```

**Solutions**:

1. **Use different subdomain**:
```bash
sellia http 8080 --subdomain myapp2
```

2. **Wait for existing tunnel to close**:
```bash
# Tunnels automatically close when client disconnects
# Press Ctrl+C to close the tunnel client
```

3. **Check for zombie tunnels**:
```bash
# If client crashed, tunnel may still be registered
# Restart server to clear all tunnels
systemctl restart sellia
```

---

### "Subdomain is Reserved"

**Symptoms**:
- Error: "Subdomain 'www' is reserved"
- Cannot use certain subdomains

**Diagnosis**:

1. Check reserved subdomains:
```bash
sellia admin reserved-subdomains list
```

**Default Reserved Subdomains** (from storage/migrations.cr):
- `www` - Common web server subdomain
- `api` - API endpoints
- `admin` - Admin panel
- `mail` - Email services
- `ftp` - File transfer
- `localhost` - Localhost

Note: These defaults are seeded into the database and can be managed via `sellia admin reserved` commands.

**Solutions**:

1. **Use different subdomain**:
```bash
# Instead of
sellia http --subdomain www

# Use
sellia http --subdomain myapp
```

2. **Remove reservation** (if you control server):
```bash
sellia admin reserved-subdomains delete www
```

3. **Check reserved list**:
```bash
sellia admin reserved-subdomains list

# Output:
# Reserved Subdomains:
# - www (System)
# - api (System: API endpoints)
```

---

### Subdomain Format Validation Errors

**Symptoms**:
- Error: "Subdomain must be at least 3 characters"
- Error: "Subdomain can only contain lowercase letters, numbers, and hyphens"
- Error: "Subdomain cannot start or end with a hyphen"

**Diagnosis**:

```bash
# Check your subdomain
echo "myapp" | grep -E '^[a-z0-9][a-z0-9-]*[a-z0-9]$'
```

**Validation Rules** (from tunnel_registry.cr):
1. Length: 3-63 characters
2. Characters: lowercase letters, numbers, hyphens only
3. Must start and end with alphanumeric character
4. Cannot contain consecutive hyphens
5. Cannot be a reserved subdomain
6. Must not already be in use

**Solutions**:

1. **Fix subdomain format**:
```bash
# BAD - too short
sellia http --subdomain ab

# GOOD
sellia http --subdomain myapp

# BAD - uppercase
sellia http --subdomain MyApp

# GOOD
sellia http --subdomain myapp

# BAD - starts with hyphen
sellia http --subdomain -myapp

# GOOD
sellia http --subdomain myapp

# BAD - ends with hyphen
sellia http --subdomain myapp-

# GOOD
sellia http --subdomain myapp

# BAD - consecutive hyphens
sellia http --subdomain my--app

# GOOD
sellia http --subdomain my-app
```

2. **Use generated subdomain**:
```bash
# Let server generate random subdomain
sellia http
```

---

### Race Condition - Subdomain Taken

**Symptoms**:
- Multiple clients trying to get same subdomain
- One succeeds, others fail
- Error intermittent

**Diagnosis**:

1. Check if multiple clients are using same config:
```bash
# Multiple processes with same subdomain
ps aux | grep "sellia.*myapp"
```

2. Check timing:
```bash
# If clients start at same time (e.g., system reboot)
# They may race for the same subdomain
```

**Solutions**:

1. **Use unique subdomains per client**:
```bash
# Client 1
sellia http --subdomain myapp-client1

# Client 2
sellia http --subdomain myapp-client2
```

2. **Add identifier**:
```bash
# Use hostname or identifier
HOST=$(hostname)
sellia http --subdomain "myapp-${HOST}"
```

3. **Use random subdomain**:
```bash
# No conflicts possible
sellia http
```

4. **Implement retry logic**:
```crystal
# In client code
max_attempts = 3
attempt = 0

while attempt < max_attempts
  result = try_open_tunnel(subdomain)
  if result.success?
    break
  elsif result.error.includes?("not available")
    attempt += 1
    sleep 1
    subdomain = "#{subdomain}#{attempt}"
  else
    break
  end
end
```

---

### Zombie Tunnel Holding Subdomain

**Symptoms**:
- Client disconnected but tunnel still registered
- Cannot reuse subdomain
- Server shows tunnel active

**Diagnosis**:

1. Check server health:
```bash
curl http://your-server.com/health

# Note: tunnels count includes zombies
```

2. Try to access subdomain:
```bash
# If returns 502 "Tunnel client disconnected"
# Tunnel is registered but client is gone
curl http://myapp.your-domain.com
```

**Solutions**:

1. **Wait for cleanup**:
```bash
# Server may have stale connection detection
# Waits 60 seconds before marking as stale
```

2. **Restart server**:
```bash
# Clears all tunnels
systemctl restart sellia
```

3. **Implement server-side cleanup**:
```crystal
# In WSGateway#check_connections
if client.stale?(PING_TIMEOUT)
  Log.warn { "Client #{client.id} timed out" }
  client.close("Connection timeout")
  handle_disconnect(client)
end
```

4. **Add keep-alive**:
```crystal
# Ensure ping/pong is working
# Server sends ping every 30s
# Client responds with pong
# If no pong for 60s, client is stale
```

---

## Subdomain Management

### List Active Tunnels

```bash
# Via health endpoint
curl http://your-server.com/health

# Via admin API
curl -u admin:password http://your-server.com/admin/tunnels
```

### Force Close Tunnel

```bash
# Via admin API
curl -X POST \
  -u admin:password \
  http://your-server.com/admin/tunnels/{tunnel_id}/close
```

### Clear All Tunnels

```bash
# Restart server
systemctl restart sellia

# Or via admin API (if implemented)
curl -X POST \
  -u admin:password \
  http://your-server.com/admin/tunnels/clear-all
```

### Add Reserved Subdomain

```bash
# Prevent subdomain from being used
sellia admin reserved-subdomains create myapp --reason "Reserved for production"

# Make it default (system)
sellia admin reserved-subdomains create www --reason "Web server" --default
```

### Remove Reserved Subdomain

```bash
sellia admin reserved-subdomains delete myapp
```

---

## Best Practices

### Use Descriptive Subdomains

```bash
# GOOD - descriptive
sellia http --subdomain dev-myapp
sellia http --subdomain staging-myapp
sellia http --subdomain prod-myapp

# BAD - random, hard to remember
sellia http --subdomain a1b2c3d4
```

### Use Environment Suffix

```bash
# Development
ENV=dev
sellia http --subdomain "myapp-${ENV}"

# Staging
ENV=staging
sellia http --subdomain "myapp-${ENV}"

# Production
ENV=prod
sellia http --subdomain "myapp-${ENV}"
```

### Use Consistent Naming

```bash
# Pattern: {app}-{service}-{env}
# Examples:
sellia http --subdomain myapp-api-dev
sellia http --subdomain myapp-web-prod
sellia http --subdomain myapp-admin-staging
```

### Avoid Reserved Words

**Avoid these subdomains**:
- `www`, `api`, `admin`, `mail`, `ftp`, `localhost`, `smtp`, `pop`, `imap`
- Any system service you might run

### Document Subdomain Usage

```bash
# Keep track of subdomain assignments
# Subdomain | Purpose | Owner | Date
# myapp-dev | Development | Alice | 2024-01-15
# myapp-prod | Production | Bob | 2024-01-16
```

---

## Testing

### Test Subdomain Availability

```bash
# Check if subdomain is taken
curl -I http://myapp.your-domain.com

# 404 = Available (no tunnel)
# 200/502 = Taken (tunnel exists or zombie)
```

### Test Subdomain Format

```bash
# Validation function
validate_subdomain() {
  local subdomain="$1"
  
  if [[ ${#subdomain} -lt 3 ]]; then
    echo "Error: Subdomain must be at least 3 characters"
    return 1
  fi
  
  if [[ ${#subdomain} -gt 63 ]]; then
    echo "Error: Subdomain must be at most 63 characters"
    return 1
  fi
  
  if [[ ! "$subdomain" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?$ ]]; then
    echo "Error: Invalid subdomain format"
    return 1
  fi
  
  echo "Subdomain '$subdomain' is valid"
}

# Test
validate_subdomain "myapp"  # Valid
validate_subdomain "ab"     # Too short
validate_subdomain "MyApp"  # Uppercase
```

### Test Race Conditions

```bash
# Test multiple clients trying same subdomain
for i in {1..5}; do
  sellia http --subdomain race-test &
done

# Wait and check results
sleep 5
curl http://race-test.your-domain.com
```

---

## Prevention

### Reserve System Subdomains Early

```bash
# During setup
sellia admin reserved-subdomains create www --reason "Web server" --default
sellia admin reserved-subdomains create api --reason "API server" --default
sellia admin reserved-subdomains create admin --reason "Admin panel" --default
```

### Use Unique Identifiers

```bash
# Include hostname/user in subdomain
sellia http --subdomain "myapp-${USER}"
sellia http --subdomain "myapp-$(hostname)"
```

### Implement Cleanup Logic

```crystal
# Server-side cleanup
# 1. Detect stale connections
# 2. Close stale connections
# 3. Clean up tunnels
# 4. Reset rate limits
```

### Monitor Subdomain Usage

```bash
# Regularly check for stale tunnels
while true; do
  tunnels=$(curl -s http://your-server.com/health | jq '.tunnels')
  echo "Active tunnels: $tunnels"
  sleep 60
done
```
