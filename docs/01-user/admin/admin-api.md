# Admin API

The Sellia Admin API provides HTTP endpoints for managing reserved subdomains and API keys. All endpoints require authentication with a master API key.

## Base URL

The Admin API is served from the same host as your Sellia server:

```
https://your-domain.com/api/admin
```

## Authentication

All Admin API endpoints require authentication with a **master API key**.

### Methods

**Authorization Header:**

```http
Authorization: Bearer your-api-key-here
```

**X-API-Key Header:**

```http
X-API-Key: your-api-key-here
```

Both methods are supported and checked. The client sends both headers for compatibility.

### Example with cURL

```bash
export SELLIA_ADMIN_API_KEY="a1b2c3d4e5f6..."

curl -H "Authorization: Bearer $SELLIA_ADMIN_API_KEY" \
  https://sellia.example.com/api/admin/reserved
```

### Error Response

If authentication fails or key is not a master key:

```http
HTTP/1.1 401 Unauthorized
Content-Type: application/json

{
  "error": "Unauthorized: Admin API key required"
}
```

## Response Format

Success responses use appropriate HTTP status codes:

- `200 OK` - Successful GET, DELETE
- `201 Created` - Successful POST
- `400 Bad Request` - Invalid request parameters
- `401 Unauthorized` - Missing or invalid authentication
- `403 Forbidden` - Operation not allowed (e.g., removing default reserved subdomain)
- `404 Not Found` - Resource doesn't exist
- `409 Conflict` - Resource already exists
- `503 Service Unavailable` - Database not available

## Endpoints

### Reserved Subdomains

#### List Reserved Subdomains

Get all reserved subdomains.

```http
GET /api/admin/reserved
```

**Response:** 200 OK

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
    "reason": "Payment processing",
    "is_default": false,
    "created_at": "2024-01-15T10:30:00.000000Z"
  }
]
```

**cURL example:**

```bash
curl -H "Authorization: Bearer $SELLIA_ADMIN_API_KEY" \
  https://sellia.example.com/api/admin/reserved
```

#### Add Reserved Subdomain

Reserve a subdomain to prevent tunnel clients from using it.

```http
POST /api/admin/reserved
Content-Type: application/json

{
  "subdomain": "mycompany",
  "reason": "Company name protection"
}
```

**Request body fields:**

- `subdomain` (required, string) - Subdomain to reserve (3-63 chars, a-z, 0-9, hyphens; must start and end with alphanumeric)
- `reason` (optional, string) - Reason/documentation for the reservation

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

- `400 Bad Request` - Invalid subdomain format

  ```json
  {
    "error": "Subdomain must be at least 3 characters"
  }
  ```

  ```json
  {
    "error": "Subdomain must be at most 63 characters"
  }
  ```

  ```json
  {
    "error": "Subdomain can only contain lowercase letters, numbers, and hyphens"
  }
  ```

- `409 Conflict` - Subdomain already reserved

  ```json
  {
    "error": "Subdomain already reserved"
  }
  ```

**cURL example:**

```bash
curl -X POST \
  -H "Authorization: Bearer $SELLIA_ADMIN_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"subdomain": "mycompany", "reason": "Company name"}' \
  https://sellia.example.com/api/admin/reserved
```

#### Remove Reserved Subdomain

Remove a reservation (allows the subdomain to be used again).

```http
DELETE /api/admin/reserved/:subdomain
```

**URL parameters:**

- `subdomain` - The subdomain to remove from reserved list

**Response:** 200 OK

```json
{
  "message": "Reserved subdomain 'mycompany' removed"
}
```

**Error responses:**

- `403 Forbidden` - Attempting to remove default reserved subdomain

  ```json
  {
    "error": "Cannot remove default reserved subdomain"
  }
  ```

- `404 Not Found` - Subdomain not in reserved list

  ```json
  {
    "error": "Reserved subdomain not found"
  }
  ```

**cURL example:**

```bash
curl -X DELETE \
  -H "Authorization: Bearer $SELLIA_ADMIN_API_KEY" \
  https://sellia.example.com/api/admin/reserved/mycompany
```

### API Keys

#### List API Keys

Get all API keys in the database.

```http
GET /api/admin/api-keys
```

**Response:** 200 OK

```json
[
  {
    "id": 1,
    "key_prefix": "a1b2c3d4",
    "name": "Development Key",
    "is_master": true,
    "active": true,
    "created_at": "2024-01-15T10:30:00.000000Z",
    "last_used_at": "2024-01-20T14:22:00.000000Z"
  },
  {
    "id": 2,
    "key_prefix": "e5f6g7h8",
    "name": "Production API",
    "is_master": false,
    "active": true,
    "created_at": "2024-01-20T14:22:00.000000Z",
    "last_used_at": null
  }
]
```

**Note:** The full API key is never returned in listings. Only the prefix is shown.

**cURL example:**

```bash
curl -H "Authorization: Bearer $SELLIA_ADMIN_API_KEY" \
  https://sellia.example.com/api/admin/api-keys
```

#### Create API Key

Generate a new API key.

```http
POST /api/admin/api-keys
Content-Type: application/json

{
  "name": "My Service Key",
  "is_master": false
}
```

**Request body fields:**

- `name` (optional, string) - Friendly name for the key
- `is_master` (optional, boolean) - Create master key (default: false)

**Response:** 201 Created

```json
{
  "id": 3,
  "key": "9a8b7c6d5e4f3g2h1i2j3k4l5m6n7o8p9q0r1s2t3u4v5w6x7y8z9a0b1c2d3e4f5g6h7i8j9k0l1m2n3o4p5q6r7s8t9u0v1w2x3y4z5",
  "key_prefix": "9a8b7c6d",
  "name": "My Service Key",
  "is_master": false,
  "active": true,
  "created_at": "2024-01-20T15:00:00.000000Z"
}
```

**Important:** The `key` field contains the full API key and is **only shown once** during creation. Save it securely.

**cURL example:**

```bash
# Standard key
curl -X POST \
  -H "Authorization: Bearer $SELLIA_ADMIN_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"name": "Service Key"}' \
  https://sellia.example.com/api/admin/api-keys

# Master key
curl -X POST \
  -H "Authorization: Bearer $SELLIA_ADMIN_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"name": "Admin Key", "is_master": true}' \
  https://sellia.example.com/api/admin/api-keys
```

#### Revoke API Key

Revoke an API key by its prefix.

```http
DELETE /api/admin/api-keys/:prefix
```

**URL parameters:**

- `prefix` - The key prefix (first 8 characters)

**Response:** 200 OK

```json
{
  "message": "API key 'a1b2c3d4' revoked"
}
```

**Error responses:**

- `404 Not Found` - Key prefix not found

  ```json
  {
    "error": "API key not found"
  }
  ```

**cURL example:**

```bash
curl -X DELETE \
  -H "Authorization: Bearer $SELLIA_ADMIN_API_KEY" \
  https://sellia.example.com/api/admin/api-keys/a1b2c3d4
```

## Using with Different Languages

### Python

```python
import requests

ADMIN_KEY = "your-64-char-hex-key"
BASE_URL = "https://sellia.example.com/api/admin"

headers = {
    "Authorization": f"Bearer {ADMIN_KEY}",
    "Content-Type": "application/json"
}

# List reserved subdomains
response = requests.get(f"{BASE_URL}/reserved", headers=headers)
print(response.json())

# Add reserved subdomain
data = {"subdomain": "mycompany", "reason": "Company name"}
response = requests.post(f"{BASE_URL}/reserved", headers=headers, json=data)
print(response.json())

# Create API key
data = {"name": "Service Key", "is_master": False}
response = requests.post(f"{BASE_URL}/api-keys", headers=headers, json=data)
key_data = response.json()
print(f"New key: {key_data['key']}")
```

### JavaScript/Node.js

```javascript
const ADMIN_KEY = 'your-64-char-hex-key';
const BASE_URL = 'https://sellia.example.com/api/admin';

const headers = {
  'Authorization': `Bearer ${ADMIN_KEY}`,
  'Content-Type': 'application/json'
};

// List reserved subdomains
fetch(`${BASE_URL}/reserved`, { headers })
  .then(r => r.json())
  .then(console.log);

// Add reserved subdomain
fetch(`${BASE_URL}/reserved`, {
  method: 'POST',
  headers,
  body: JSON.stringify({
    subdomain: 'mycompany',
    reason: 'Company name'
  })
})
  .then(r => r.json())
  .then(console.log);

// Create API key
fetch(`${BASE_URL}/api-keys`, {
  method: 'POST',
  headers,
  body: JSON.stringify({
    name: 'Service Key',
    is_master: false
  })
})
  .then(r => r.json())
  .then(data => console.log(`New key: ${data.key}`));
```

### Ruby

```ruby
require 'net/http'
require 'json'
require 'uri'

ADMIN_KEY = 'your-64-char-hex-key'
BASE_URL = 'https://sellia.example.com/api/admin'

def headers
  {
    'Authorization' => "Bearer #{ADMIN_KEY}",
    'Content-Type' => 'application/json'
  }
end

# List reserved subdomains
uri = URI("#{BASE_URL}/reserved")
response = Net::HTTP.get(uri, headers)
puts JSON.parse(response)

# Add reserved subdomain
uri = URI("#{BASE_URL}/reserved")
req = Net::HTTP::Post.new(uri, headers)
req.body = { subdomain: 'mycompany', reason: 'Company name' }.to_json
res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(req) }
puts res.body
```

### Go

```go
package main

import (
    "bytes"
    "encoding/json"
    "fmt"
    "io"
    "net/http"
)

const (
    ADMIN_KEY = "your-64-char-hex-key"
    BASE_URL  = "https://sellia.example.com/api/admin"
)

func main() {
    client := &http.Client{}

    // List reserved subdomains
    req, _ := http.NewRequest("GET", BASE_URL+"/reserved", nil)
    req.Header.Set("Authorization", "Bearer "+ADMIN_KEY)
    resp, _ := client.Do(req)
    defer resp.Body.Close()
    body, _ := io.ReadAll(resp.Body)
    fmt.Println(string(body))

    // Add reserved subdomain
    data := map[string]string{"subdomain": "mycompany", "reason": "Company name"}
    jsonData, _ := json.Marshal(data)
    req, _ = http.NewRequest("POST", BASE_URL+"/reserved", bytes.NewBuffer(jsonData))
    req.Header.Set("Authorization", "Bearer "+ADMIN_KEY)
    req.Header.Set("Content-Type", "application/json")
    resp, _ = client.Do(req)
    defer resp.Body.Close()
    body, _ = io.ReadAll(resp.Body)
    fmt.Println(string(body))
}
```

## Rate Limiting

As of the current version, the Admin API does not enforce rate limiting. However, best practices include:

- Implementing client-side rate limiting for automation
- Using linear backoff for retries
- Monitoring API usage for abuse detection

## Error Handling

Always check the HTTP status code and response body:

```python
response = requests.post(url, headers=headers, json=data)

if response.status_code == 401:
    print("Authentication failed - check your API key")
elif response.status_code == 409:
    error = response.json()['error']
    print(f"Conflict: {error}")
elif response.status_code == 201:
    print("Success!")
else:
    print(f"Unexpected status: {response.status_code}")
    print(response.text)
```

## Webhook Support (Future)

Future versions may include webhook notifications for events like:

- New tunnel created
- Tunnel disconnected
- API key created/revoked
- Reserved subdomain added/removed

Check the server documentation for webhook capabilities.

## Troubleshooting

### cURL: SSL Certificate Problem

```
SSL certificate problem: unable to get local issuer certificate
```

**Solution:** For development only, disable SSL verification (not recommended for production):

```bash
curl -k https://sellia.example.com/api/admin/reserved
```

Or add the CA certificate:

```bash
curl --cacert /path/to/ca.crt https://sellia.example.com/api/admin/reserved
```

### 401 Unauthorized Despite Valid Key

**Possible causes:**

1. Key is not a master key
2. Database not available on server
3. Wrong server URL

**Debug:**

```bash
# Check if key is master
curl -H "Authorization: Bearer $KEY" \
  https://sellia.example.com/api/admin/api-keys

# Should return list of keys if master
# Should return 401 if standard key
```

### 503 Service Unavailable

```
{"error":"Database not available"}
```

**Cause:** Server started without database or database file missing.

**Solution:**

```bash
# Check database file
ls -la /var/lib/sellia/sellia.db

# Restart server with database
export SELLIA_DB_PATH="/var/lib/sellia/sellia.db"
sellia-server restart
```

## See Also

- [Reserved Subdomains](./reserved-subdomains.md) - Managing reserved subdomains via CLI
- [API Key Management](./api-key-management.md) - Managing API keys via CLI
- [Server Auth](../authentication/server-auth.md) - Authentication configuration
- [Database Schema](../storage/migrations.md) - Database table definitions
