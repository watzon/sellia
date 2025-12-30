# Production Deployment Checklist

A comprehensive security and production hardening checklist for deploying Sellia servers.

## Pre-Deployment Planning

### Requirements Gathering

- [ ] Define expected concurrent tunnel count
- [ ] Estimate bandwidth requirements
- [ ] Identify authentication requirements (public vs private)
- [ ] Determine backup and recovery strategy
- [ ] Plan for monitoring and alerting
- [ ] Define disaster recovery procedures

### Resource Planning

**Minimum Requirements (Small Deployment):**
- [ ] CPU: 2 cores
- [ ] RAM: 2 GB
- [ ] Storage: 20 GB SSD
- [ ] Network: 100 Mbps
- [ ] Concurrent tunnels: Up to 50

**Recommended (Production):**
- [ ] CPU: 4+ cores
- [ ] RAM: 4+ GB
- [ ] Storage: 50+ GB SSD
- [ ] Network: 1+ Gbps
- [ ] Concurrent tunnels: 100+

**High Availability:**
- [ ] Load balancer (HAProxy, ALB, etc.)
- [ ] Multiple Sellia server instances
- [ ] Shared database (PostgreSQL instead of SQLite)
- [ ] Health checks and failover

## Server Configuration

### Operating System

**Linux Distribution:**
- [ ] Ubuntu 22.04 LTS or 24.04 LTS
- [ ] Debian 12 (Bookworm)
- [ ] Rocky Linux 9 or AlmaLinux 9

**System Updates:**

```bash
# Update system packages
sudo apt update && sudo apt upgrade -y

# Enable automatic security updates
sudo apt install unattended-upgrades
sudo dpkg-reconfigure -plow unattended-upgrades
```

### Firewall Configuration

```bash
# UFW (Ubuntu/Debian)
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 80/tcp    # HTTP
sudo ufw allow 443/tcp   # HTTPS
sudo ufw enable

# Firewalld (RHEL/CentOS/Rocky)
sudo firewall-cmd --permanent --add-service=ssh
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --reload
```

**Additional hardening:**
- [ ] Disable password authentication for SSH (use keys only)
- [ ] Change default SSH port (optional, security through obscurity)
- [ ] Install fail2ban for SSH protection
- [ ] Limit SSH access to specific IP ranges (if possible)

### Time Synchronization

```bash
# Install and configure NTP
sudo apt install chrony
sudo systemctl enable chrony
sudo systemctl start chrony

# Verify time sync
timedatectl
```

## SSL/TLS Configuration

### Certificate Setup

**Option 1: Let's Encrypt (Automated)**
- [ ] Certbot installed
- [ ] DNS A records configured
- [ ] Wildcard DNS for subdomains (optional)
- [ ] Auto-renewal configured
- [ ] Test renewal: `sudo certbot renew --dry-run`

**Option 2: Custom Certificates**
- [ ] Certificate files in `/etc/ssl/certs/`
- [ ] Private key files in `/etc/ssl/private/`
- [ ] Permissions: 644 for certs, 600 for keys
- [ ] Certificate chain complete
- [ ] Expiry monitoring configured

### TLS Configuration

**Reverse Proxy (Caddy or Nginx):**
- [ ] HTTP/2 enabled
- [ ] Strong cipher suites
- [ ] TLS 1.2 and 1.3 only (no SSLv3, TLS 1.0, 1.1)
- [ ] HSTS enabled (after testing)
- [ ] OCSP stapling (optional)
- [ ] Perfect Forward Secrecy (Ephemeral Diffie-Hellman)

**Test TLS configuration:**

```bash
# Test SSL configuration
openssl s_client -connect yourdomain.com:443 -tls1_2
openssl s_client -connect yourdomain.com:443 -tls1_3

# Online test
# Visit: https://www.ssllabs.com/ssltest/
```

## Authentication Setup

### Server-Side Authentication

**Enable Authentication:**
- [ ] `SELLIA_REQUIRE_AUTH=true` set
- [ ] `SELLIA_MASTER_KEY` configured (cryptographically random, use `openssl rand -hex 32`)
- [ ] Database enabled by default (disabled with `SELLIA_NO_DB=true`)
- [ ] Optional: `SELLIA_DB_PATH=/var/lib/sellia/sellia.db` for custom database location
- [ ] Database directory created with proper permissions
- [ ] Initial admin API key created (using master key)

**Generate Master Key:**

```bash
# Generate secure 32-byte key
openssl rand -hex 32
```

### API Key Management

**Initial Setup:**
- [ ] Master key stored in secure password manager
- [ ] Master key not committed to version control
- [ ] Separate keys for dev/staging/production
- [ ] Key rotation policy documented
- [ ] Key revocation process tested

**Environment Variables:**
```bash
SELLIA_REQUIRE_AUTH=true
SELLIA_MASTER_KEY="your-generated-key"
# Optional - defaults are shown
# SELLIA_DB_PATH="/var/lib/sellia/sellia.db"
# SELLIA_NO_DB=false  # Set to true to disable database
```

## Database Configuration

### SQLite Setup

**Directory Structure:**
- [ ] Database directory: `/var/lib/sellia/`
- [ ] Directory owned by `sellia` user
- [ ] Directory permissions: `755`
- [ ] Database file permissions: `640`
- [ ] Automatic backups configured

**Backup Script:**

```bash
#!/bin/bash
# /opt/sellia/scripts/backup.sh

BACKUP_DIR="/backup/sellia"
DATE=$(date +%Y%m%d_%H%M%S)
mkdir -p "$BACKUP_DIR"

# Online backup
sqlite3 /var/lib/sellia/sellia.db ".backup $BACKUP_DIR/sellia.db.$DATE"

# Compress older backups
find "$BACKUP_DIR" -name "sellia.db.*" -mtime +7 -exec gzip {} \;

# Delete backups older than 30 days
find "$BACKUP_DIR" -name "sellia.db.*.gz" -mtime +30 -delete
```

**Add to crontab:**

```bash
# Daily backup at 2 AM
0 2 * * * /opt/sellia/scripts/backup.sh
```

## Reserved Subdomains

**Initial Setup:**
- [ ] Server started successfully (seeds default reserved subdomains)
- [ ] Company-specific subdomains reserved
- [ ] Service subdomains reserved (api, admin, dashboard, etc.)
- [ ] Document reasons for custom reservations

**Example:**

```bash
sellia admin reserved add mycompany --reason "Company brand"
sellia admin reserved add api --reason "API gateway"
sellia admin reserved add billing --reason "Payment system"
```

## Application Configuration

### Environment Variables

**Required:**
```bash
SELLIA_REQUIRE_AUTH=true
SELLIA_MASTER_KEY="generated-key"
```

**Optional (with defaults shown):**
```bash
# Host configuration
SELLIA_HOST=0.0.0.0
SELLIA_PORT=3000
SELLIA_DOMAIN=localhost

# HTTPS configuration (set by reverse proxy automatically)
SELLIA_USE_HTTPS=true

# Database (defaults to ~/.sellia/sellia.db)
SELLIA_DB_PATH="/var/lib/sellia/sellia.db"
SELLIA_NO_DB=false  # Set to true to disable database

# Feature flags
SELLIA_RATE_LIMITING=true  # Set to false to disable
SELLIA_DISABLE_LANDING=false  # Set to true to disable landing page
```

### Config File (Optional)

**Create `/opt/sellia/sellia-server.yml`:**

```yaml
server:
  require_auth: true
  master_key: ${SELLIA_MASTER_KEY}
  host: 0.0.0.0
  port: 3000
  domain: yourdomain.com
  use_https: true
  rate_limiting: true
  landing_enabled: true

database:
  enabled: true
  path: /var/lib/sellia/sellia.db
```

### Service Configuration

**Systemd Service:**

```ini
# /etc/systemd/system/sellia.service
[Unit]
Description=Sellia Tunnel Server
After=network.target

[Service]
Type=simple
User=sellia
Group=sellia
WorkingDirectory=/opt/sellia
Environment="SELLIA_REQUIRE_AUTH=true"
Environment="SELLIA_MASTER_KEY=${SELLIA_MASTER_KEY}"
Environment="SELLIA_USE_HTTPS=true"
ExecStart=/opt/sellia/bin/sellia-server
Restart=always
RestartSec=10

# Security
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/var/lib/sellia

[Install]
WantedBy=multi-user.target
```

**Enable and start:**

```bash
sudo systemctl daemon-reload
sudo systemctl enable sellia
sudo systemctl start sellia
```

## Reverse Proxy Configuration

### Choose Your Proxy

- [ ] Caddy (automatic HTTPS, easier setup)
- [ ] Nginx (more configurable, widely used)

### Caddy Configuration

- [ ] Caddyfile configured with your domain
- [ ] TLS certificates (Let's Encrypt or custom)
- [ ] HTTP/3 disabled (for WebSocket compatibility)
- [ ] HTTP/1.1 transport to backend
- [ ] Wildcard subdomain handling
- [ ] Logging configured

**Reference:** [Caddy Deployment Guide](./caddy.md)

### Nginx Configuration

- [ ] Nginx installed and enabled
- [ ] Virtual host configured for your domain
- [ ] TLS certificates configured
- [ ] HTTP/2 enabled
- [ ] WebSocket headers configured
- [ ] Proper timeouts for long-lived connections
- [ ] Logging configured
- [ ] Log rotation configured

**Reference:** [Nginx Deployment Guide](./nginx.md)

## Monitoring and Logging

### Application Logs

**Log Locations:**
- [ ] Sellia server logs: `/var/log/sellia/server.log`
- [ ] Reverse proxy logs: `/var/log/nginx/` or `/var/log/caddy/`
- [ ] System logs: `journalctl -u sellia`

**Log Rotation:**
- [ ] logrotate configured for Sellia logs
- [ ] Retention policy defined (e.g., 30 days)
- [ ] Compress old logs
- [ ] Regular cleanup

### Monitoring Setup

**Basic Monitoring:**
- [ ] Server process monitoring (systemd)
- [ ] Disk space monitoring
- [ ] Memory usage monitoring
- [ ] CPU usage monitoring
- [ ] Network traffic monitoring

**Advanced Monitoring (Optional):**
- [ ] Prometheus metrics exporter
- [ ] Grafana dashboards
- [ ] Alertmanager alerts
- [ ] Uptime monitoring (Pingdom, UptimeRobot, etc.)

**Health Checks:**

```bash
# Simple health check script
#!/bin/bash
# /opt/sellia/scripts/health-check.sh

# Check Sellia server
curl -f http://localhost:3000/health || exit 1

# Check database
sqlite3 /var/lib/sellia/sellia.db "PRAGMA integrity_check;" | grep -q "ok" || exit 1

# Check disk space
df /var/lib/sellia | tail -1 | awk '{ if ($5+0 > 90) exit 1; }'

echo "All checks passed"
```

**Add to crontab:**

```bash
# Run every 5 minutes
*/5 * * * * /opt/sellia/scripts/health-check.sh
```

## Security Hardening

### SELinux Configuration (RHEL/CentOS/Fedora)

```bash
# Check SELinux status
sestatus

# Allow Sellia to connect to network
sudo setsebool -P httpd_can_network_connect 1

# Context for database directory
sudo semanage fcontext -a -t httpd_sys_rw_content_t "/var/lib/sellia(/.*)?"
sudo restorecon -Rv /var/lib/sellia
```

### AppArmor Configuration (Ubuntu/Debian)

```bash
# Check AppArmor status
sudo aa-status

# Create Sellia profile
sudo nano /etc/apparmor.d/opt.sellia.bin.sellia-server

# Reload profiles
sudo apparmor_parser -r /etc/apparmor.d/opt.sellia.bin.sellia-server
```

### File Permissions

```bash
# Sellia user and group
sudo adduser --system --group --home /opt/sellia sellia

# Directory permissions
sudo chown -R sellia:sellia /opt/sellia
sudo chmod 755 /opt/sellia

# Database permissions
sudo chown -R sellia:sellia /var/lib/sellia
sudo chmod 755 /var/lib/sellia
sudo chmod 640 /var/lib/sellia/sellia.db

# Log permissions
sudo chown -R sellia:adm /var/log/sellia
sudo chmod 750 /var/log/sellia
```

### System Hardening

```bash
# Disable unused services
sudo systemctl disable bluetooth
sudo systemctl disable cups

# Install security updates automatically
sudo apt install unattended-upgrades
sudo dpkg-reconfigure -plow unattended-upgrades

# Install fail2ban
sudo apt install fail2ban
sudo systemctl enable fail2ban
sudo systemctl start fail2ban
```

## DNS Configuration

### Required DNS Records

```dns
# Base domain
A     yourdomain.com          →  your-server-ip

# Wildcard for subdomains
A     *.yourdomain.com        →  your-server-ip

# Optional: WWW
CNAME www.yourdomain.com      →  yourdomain.com
```

**Cloudflare-Specific:**
- [ ] If using Cloudflare proxy (orange cloud), set WebSocket to "Full" or "Off"
- [ ] Or use DNS-only (grey cloud) for Sellia subdomains
- [ ] Create Cloudflare Origin Certificate for better security

### DNS Verification

```bash
# Check DNS propagation
dig yourdomain.com
dig *.yourdomain.com
dig myapp.yourdomain.com

# Check from multiple locations
# Visit: https://www.whatsmydns.net/
```

## Testing

### Pre-Launch Testing

**Functionality Tests:**
- [ ] Create tunnel with API key
- [ ] Verify tunnel is accessible via HTTPS
- [ ] Test WebSocket connection
- [ ] Create tunnel with reserved subdomain (should fail)
- [ ] Create tunnel with path routing
- [ ] Test inspector UI

**Load Testing:**
- [ ] Test with expected concurrent tunnel count
- [ ] Monitor CPU and memory usage
- [ ] Check database performance
- [ ] Verify no connection drops

**Security Tests:**
- [ ] Test without API key (should fail)
- [ ] Test with invalid API key (should fail)
- [ ] Test with standard key (should work for tunnels)
- [ ] Test admin API with standard key (should fail)
- [ ] Test admin API with master key (should work)
- [ ] Verify TLS configuration (SSL Labs)

### Monitoring Verification

- [ ] Check logs are being written
- [ ] Verify log rotation works
- [ ] Test health check script
- [ ] Verify backup script runs
- [ ] Test monitoring alerts (if configured)

## Disaster Recovery

### Backup Strategy

**What to Backup:**
- [ ] Database: `/var/lib/sellia/sellia.db`
- [ ] Configuration: `/opt/sellia/sellia-server.yml`
- [ ] Environment variables
- [ ] TLS certificates (if not using Let's Encrypt)
- [ ] Nginx/Caddy configuration

**Backup Locations:**
- [ ] Local backup directory
- [ ] Off-site backup (S3, GCS, etc.)
- [ ] Backup encryption (for off-site)

### Restore Procedure

**Document restore process:**

```bash
#!/bin/bash
# /opt/sellia/scripts/restore.sh

BACKUP_FILE=$1

if [ -z "$BACKUP_FILE" ]; then
    echo "Usage: $0 <backup-file>"
    exit 1
fi

# Stop Sellia
sudo systemctl stop sellia

# Restore database
cp "$BACKUP_FILE" /var/lib/sellia/sellia.db
chown sellia:sellia /var/lib/sellia/sellia.db
chmod 640 /var/lib/sellia/sellia.db

# Start Sellia
sudo systemctl start sellia

echo "Restore complete"
```

### Failover Planning

**For High Availability:**
- [ ] Document failover procedure
- [ ] Test failover procedure
- [ ] DNS failover configured (if using multiple servers)
- [ ] Load balancer health checks configured
- [ ] Data replication configured (if using PostgreSQL)

## Documentation

### Runbook

Create and maintain runbook with:
- [ ] Common issues and solutions
- [ ] Escalation procedures
- [ ] Contact information for team members
- [ ] Vendor contacts (DNS provider, hosting provider, etc.)
- [ ] Login credentials stored securely (password manager)
- [ ] Diagrams of architecture

### Change Management

- [ ] Document all configuration changes
- [ ] Use version control for configuration files
- [ ] Test changes in staging first
- [ ] Rollback procedure documented

## Post-Deployment

### Performance Tuning

- [ ] Monitor resource usage for first week
- [ ] Adjust worker connections if needed
- [ ] Tune database cache size
- [ ] Adjust reverse proxy timeouts based on usage
- [ ] Set up alerts for resource thresholds

### Regular Maintenance

**Weekly:**
- [ ] Review logs for errors
- [ ] Check disk space
- [ ] Verify backups are running

**Monthly:**
- [ ] Review and update reserved subdomains
- [ ] Audit API keys (revoke unused)
- [ ] Review security updates
- [ ] Test restore procedure

**Quarterly:**
- [ ] Security audit
- [ ] Performance review
- [ ] Capacity planning
- [ ] Disaster recovery test

## Compliance

### Data Protection

- [ ] GDPR compliance (if storing EU data)
- [ ] CCPA compliance (if storing California data)
- [ ] Data retention policy documented
- [ ] Data deletion procedure documented

### Audit Trail

- [ ] Enable audit logging
- [ ] Log all admin operations
- [ ] Log all tunnel creations
- [ ] Protect logs from tampering
- [ ] Regular log reviews

## Final Verification

Before going live:

- [ ] All tests passed
- [ ] Monitoring configured and verified
- [ ] Backups running successfully
- [ ] Documentation complete
- [ ] Team trained on operations
- [ ] Incident response plan created
- [ ] Communication plan for outages

## See Also

- [Caddy Deployment](./caddy.md) - Caddy reverse proxy setup
- [Nginx Deployment](./nginx.md) - Nginx reverse proxy setup
- [Server Auth](../authentication/server-auth.md) - Authentication configuration
- [Database Configuration](../storage/database-config.md) - Database setup
