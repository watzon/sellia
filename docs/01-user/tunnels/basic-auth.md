# Basic Authentication

Protect your tunnels with username and password authentication using basic auth. This ensures only authorized users can access your tunneled services.

## What is Basic Authentication?

Basic authentication adds a username/password requirement to your tunnel. When someone tries to access your tunnel URL, they're prompted for credentials before the request is forwarded to your local server.

### How It Works

```
User Request → Sellia Server → Check Credentials → If Valid: Forward to Local Server
                                                       → If Invalid: Return 401 Unauthorized
```

## Enabling Basic Authentication

### Command Line

Use the `--auth` flag when creating a tunnel:

```bash
sellia http 8080 --auth username:password
```

### Example: Protected Webhook Endpoint

```bash
# Start your webhook handler
node webhook-server.js &

# Create protected tunnel
sellia http 3000 --subdomain webhooks --auth admin:webhook-secret
```

Now anyone accessing your tunnel URL must provide credentials. The URL depends on your server configuration.

## Authentication Flow

### 1. Client Access Attempt

When a client (browser, curl, API client) tries to access the tunnel:

```bash
curl https://webhooks.sellia.me
```

### 2. Server Challenges

Sellia responds with `401 Unauthorized` and a `WWW-Authenticate` header:

```http
HTTP/1.1 401 Unauthorized
WWW-Authenticate: Basic realm="Sellia Tunnel"
```

### 3. Client Provides Credentials

The client resends the request with credentials:

```bash
curl -u admin:webhook-secret https://webhooks.sellia.me
```

Or in a browser, a dialog prompts for username and password.

### 4. Request Forwarded

If credentials match, the request is forwarded to your local server.

## Using Basic Auth with Different Clients

### Browser Access

When accessing via browser:
1. Navigate to the tunnel URL
2. Browser shows authentication dialog
3. Enter username and password
4. Browser caches credentials for the session

### cURL

```bash
# With -u flag
curl -u username:password https://tunnel.sellia.me

# Or include in URL (not recommended for production)
curl https://username:password@tunnel.sellia.me
```

### wget

```bash
wget --user=username --password=password https://tunnel.sellia.me
```

### JavaScript (Fetch API)

```javascript
fetch('https://tunnel.sellia.me', {
  headers: {
    'Authorization': 'Basic ' + btoa('username:password')
  }
})
.then(response => response.json())
.then(data => console.log(data));
```

### JavaScript (Axios)

```javascript
axios.get('https://tunnel.sellia.me', {
  auth: {
    username: 'username',
    password: 'password'
  }
})
.then(response => console.log(response.data));
```

### Python (requests)

```python
import requests

response = requests.get('https://tunnel.sellia.me', auth=('username', 'password'))
print(response.text)
```

### Python (urllib)

```python
import urllib.request
import base64

url = 'https://tunnel.sellia.me'
credentials = base64.b64encode(b'username:password').decode('utf-8')

request = urllib.request.Request(url)
request.add_header('Authorization', f'Basic {credentials}')

with urllib.request.urlopen(request) as response:
    print(response.read().decode())
```

### Node.js (https)

```javascript
const https = require('https');
const auth = 'Basic ' + Buffer.from('username:password').toString('base64');

const options = {
  hostname: 'tunnel.sellia.me',
  path: '/',
  headers: { 'Authorization': auth }
};

https.get(options, (res) => {
  let data = '';
  res.on('data', (chunk) => data += chunk);
  res.on('end', () => console.log(data));
});
```

## Configuration File

Set basic auth in `sellia.yml`:

```yaml
server: https://sellia.me

tunnels:
  web:
    port: 3000
    subdomain: myapp
    auth: admin:secret123

  api:
    port: 4000
    subdomain: myapp-api
    auth: apiuser:apipass

  public:
    port: 5000
    subdomain: public-site
    # No auth - public tunnel
```

Start tunnels:

```bash
sellia start
```

## Security Best Practices

### 1. Use Strong Passwords

Generate secure random passwords:

```bash
# Generate 32-character random password
openssl rand -base64 32
```

### 2. Unique Credentials per Tunnel

Don't reuse credentials:

```yaml
tunnels:
  staging:
    port: 3000
    auth: staging-user:$(openssl rand -base64 32)

  production:
    port: 3001
    auth: prod-user:$(openssl rand -base64 32)
```

### 3. Environment Variables

Store credentials in environment variables, not in config files:

```bash
# .env
SELLIA_WEB_AUTH=user:pass
SELLIA_API_AUTH=apiuser:apipass
```

```yaml
# sellia.yml
tunnels:
  web:
    port: 3000
    auth: ${SELLIA_WEB_AUTH}
```

### 4. Rotate Credentials Regularly

Change passwords periodically, especially after:
- Team member changes
- Suspected unauthorized access
- Regular security cycles

### 5. Use HTTPS

Always use a tunnel server with HTTPS enabled for production to prevent credentials from being sent in plaintext:

```bash
# The server should be configured with --https flag
sellia server --https --domain yourdomain.com

# Client will automatically use HTTPS URLs
sellia http 3000 --auth user:pass --server https://yourdomain.com
```

### 6. Log Access Attempts

Monitor your server logs for authentication failures:

```bash
# Check for failed auth attempts
grep "401" /var/log/sellia/access.log
```

## Use Cases

### 1. Protected Webhook Testing

Test webhooks without exposing them publicly:

```bash
sellia http 3000 --subdomain stripe-webhooks --auth stripe-test:secret-key
```

Only you can access the webhook endpoint for testing.

### 2. Private API Development

Work on private APIs securely:

```bash
sellia http 4000 --subdomain private-api --auth dev-team:team-secret
```

Share credentials only with authorized team members.

### 3. Client Demos with Access Control

Give clients access to demos with control:

```bash
sellia http 5000 --subdomain demo-acme --auth acme-client:demo-pass
```

Provide unique credentials for each client.

### 4. Staging Environment Protection

Protect staging environments:

```bash
sellia http 3000 --subdomain staging-app --auth staging:staging-pass
```

### 5. Internal Tools Access

Securely access internal tools remotely:

```bash
sellia http 8080 --subdomain admin-tools --auth admin:admin-pass
```

## Troubleshooting

### "401 Unauthorized" Error

Check that:
1. Username and password are correct
2. No extra spaces in credentials: `user:pass` (not `user: pass`)
3. Credentials are properly URL-encoded if in URL

### Credentials Not Working

Verify the auth string format:

```bash
# Correct
sellia http 8080 --auth user:pass

# Incorrect (missing colon)
sellia http 8080 --auth userpass
```

### Browser Keeps Prompting

If browser repeatedly prompts for credentials:
1. Check username/password are correct
2. Try in incognito/private mode
3. Clear browser cache for that site

### API Clients Can't Authenticate

Ensure credentials are base64-encoded in Authorization header:

```javascript
// Correct
'Authorization': 'Basic ' + btoa('user:pass')

// Incorrect
'Authorization': 'user:pass'
```

## Limitations

### Security Considerations

Basic authentication:
- Sends credentials with every request (base64 encoded)
- Should only be used over HTTPS
- Credentials can be intercepted if not using TLS
- No built-in session management

### When Not to Use Basic Auth

Consider alternatives for:
- High-security applications (use OAuth2, JWT)
- Complex permission systems (use application-level auth)
- Public APIs (use API keys instead)
- Mobile apps (use token-based auth)

## Alternatives

### Application-Level Authentication

Instead of tunnel auth, implement auth in your application:

```javascript
// Express middleware
app.use((req, res, next) => {
  const auth = req.headers['authorization'];
  if (!auth || !validateAuth(auth)) {
    return res.status(401).send('Unauthorized');
  }
  next();
});
```

This gives you more control but requires application changes.

### Token-Based Authentication

Use API tokens or JWT:

```javascript
const token = 'your-api-token';
fetch('https://tunnel.sellia.me', {
  headers: { 'X-API-Token': token }
});
```

### IP Whitelisting

Restrict access by IP at the server level (configure in reverse proxy):

```nginx
# Nginx example
allow 1.2.3.4;
deny all;
```

## Advanced Examples

### Example 1: Multiple Authenticated Environments

```yaml
tunnels:
  dev:
    port: 3000
    subdomain: dev-app
    auth: dev-team:dev-pass

  staging:
    port: 3001
    subdomain: staging-app
    auth: qa-team:qa-pass

  prod-mirror:
    port: 3002
    subdomain: prod-mirror
    auth: admins:admin-pass
```

### Example 2: Webhook Testing with Services

```yaml
# Test webhooks from multiple services
tunnels:
  stripe:
    port: 3000
    subdomain: stripe-test
    auth: stripe-test:${STRIPE_TEST_TOKEN}

  github:
    port: 3001
    subdomain: github-test
    auth: github-test:${GITHUB_TEST_TOKEN}

  slack:
    port: 3002
    subdomain: slack-test
    auth: slack-test:${SLACK_TEST_TOKEN}
```

### Example 3: Client-Specific Credentials

```bash
# Generate unique credentials per client
for client in acme corp startup; do
  password=$(openssl rand -base64 16)
  echo "$client:$password" >> clients.txt
done

# Use in config or CLI
while read client pass; do
  sellia http 3000 --subdomain demo-$client --auth $client:$pass &
done < clients.txt
```

## Next Steps

- [Subdomain Management](./subdomains.md) - Custom URLs
- [HTTP Tunnels](./http-tunnels.md) - Basic tunnel usage
- [Configuration File](../configuration/config-file.md) - Persistent config
- [Deployment](../deployment/docker.md) - Production deployment

## Security Checklist

Before using basic auth in production:

- [ ] Using HTTPS for all tunnels
- [ ] Strong, unique passwords (16+ characters)
- [ ] Credentials stored in environment variables
- [ ] Regular credential rotation
- [ ] Monitoring authentication logs
- [ ] Team knows security procedures
- [ ] Alternative auth methods considered
- [ ] Documented credential recovery process
