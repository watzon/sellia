# Storage

Data persistence and storage options for Sellia.

## Overview

Sellia can store various types of data including tunnel registrations, authentication information, and request logs. This section covers storage configuration and options.

## Storage Types

### In-Memory (Default)

By default, Sellia stores data in memory:

- **Pros:** Fast, no setup required
- **Cons:** Data lost on restart, limited by available memory
- **Use Case:** Development, testing, temporary deployments

### SQLite

Persistent storage using SQLite database:

- **Pros:** Persistent, lightweight, single file
- **Cons:** Single-server only
- **Use Case:** Production deployments with single server

### PostgreSQL (Future)

PostgreSQL support planned for:

- **Pros:** Scalable, concurrent access, backups
- **Cons:** Requires separate database server
- **Use Case:** Multi-server deployments, high-availability

## Configuration

### SQLite Setup

Enable SQLite storage:

```bash
# Environment variable
export SELLIA_DB_PATH="/var/lib/sellia/sellia.db"

# Or disable database
export SELLIA_NO_DB="true"

# Or in configuration (note: database.enabled=false disables the database)
database:
  enabled: true
  path: /var/lib/sellia/sellia.db
```

### PostgreSQL Setup (Future)

```bash
# Connection string
export SELLIA_DATABASE=postgresql://user:password@localhost:5432/sellia
```

## Data Stored

Sellia stores the following data:

### Reserved Subdomains

- Subdomain names that cannot be claimed by tunnel clients
- Reasons/documentation for reservations
- Default vs. custom reservations

### Authentication Data

- API keys (hashed)
- Key prefix for identification
- Master key designation
- Active/inactive status
- Creation and last-used timestamps

## Storage Paths

### Default Locations

```
/var/lib/sellia/
├── sellia.db           # SQLite database
├── tunnels/            # Tunnel data
└── logs/               # Request logs
```

### Custom Paths

Configure custom storage paths:

```bash
# Environment variable
export SELLIA_STORAGE_PATH=/custom/path

# Or in configuration
storage:
  path: /custom/path
```

## Docker Volumes

### Named Volume

```yaml
services:
  sellia-server:
    volumes:
      - sellia-data:/var/lib/sellia

volumes:
  sellia-data:
```

### Bind Mount

```yaml
services:
  sellia-server:
    volumes:
      - ./data:/var/lib/sellia
```

### Docker Compose Example

```yaml
version: '3.8'
services:
  sellia-server:
    image: sellia-server
    environment:
      - SELLIA_DATABASE=sqlite:///var/lib/sellia/sellia.db
    volumes:
      - sellia-data:/var/lib/sellia
    ports:
      - "3000:3000"

volumes:
  sellia-data:
    driver: local
```

## Backup

### SQLite Backup

```bash
# Backup database
cp /var/lib/sellia/sellia.db /backup/sellia-$(date +%Y%m%d).db

# Or using sqlite3
sqlite3 /var/lib/sellia/sellia.db ".backup /backup/sellia.db"
```

### Automated Backup

```bash
#!/bin/bash
# backup-sellia.sh

BACKUP_DIR="/backup/sellia"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p "$BACKUP_DIR"

# Backup database
cp /var/lib/sellia/sellia.db "$BACKUP_DIR/sellia-$DATE.db"

# Backup configuration
tar -czf "$BACKUP_DIR/config-$DATE.tar.gz" /etc/sellia/

# Remove old backups (keep last 30 days)
find "$BACKUP_DIR" -name "sellia-*.db" -mtime +30 -delete
find "$BACKUP_DIR" -name "config-*.tar.gz" -mtime +30 -delete
```

Add to crontab:

```bash
# Daily backup at 2 AM
0 2 * * * /path/to/backup-sellia.sh
```

### Docker Volume Backup

```bash
# Backup volume
docker run --rm \
  -v sellia-data:/data \
  -v $(pwd):/backup \
  alpine tar czf /backup/sellia-backup-$(date +%Y%m%d).tar.gz /data
```

## Restore

### SQLite Restore

```bash
# Stop server
docker compose down

# Restore database
cp /backup/sellia-20250130.db /var/lib/sellia/sellia.db

# Restart server
docker compose up -d
```

### Docker Volume Restore

```bash
# Restore volume
docker run --rm \
  -v sellia-data:/data \
  -v $(pwd):/backup \
  alpine tar xzf /backup/sellia-backup-20250130.tar.gz -C /
```

## Performance

### SQLite Optimization

```bash
# Optimize database
sqlite3 /var/lib/sellia/sellia.db "VACUUM;"

# Analyze for query optimization
sqlite3 /var/lib/sellia/sellia.db "ANALYZE;"
```

### Storage Maintenance

Regular maintenance tasks:

```bash
# Rebuild database
sqlite3 /var/lib/sellia/sellia.db "VACUUM;"

# Analyze for query optimization
sqlite3 /var/lib/sellia/sellia.db "ANALYZE;"
```

## Monitoring

### Disk Space

Monitor storage usage:

```bash
# Check database size
ls -lh /var/lib/sellia/sellia.db

# Check disk usage
du -sh /var/lib/sellia/

# Alert if low on space
DISK_USAGE=$(df /var/lib/sellia | tail -1 | awk '{print $5}' | sed 's/%//')
if [ $DISK_USAGE -gt 80 ]; then
    echo "Warning: Disk usage is ${DISK_USAGE}%"
fi
```

### Database Statistics

```bash
# API keys in database
sqlite3 /var/lib/sellia/sellia.db "SELECT COUNT(*) FROM api_keys WHERE active = 1;"

# Reserved subdomains
sqlite3 /var/lib/sellia/sellia.db "SELECT COUNT(*) FROM reserved_subdomains;"

# Database version
sqlite3 /var/lib/sellia/sellia.db "SELECT MAX(version) FROM schema_migrations;"
```

## Security

### File Permissions

Set appropriate permissions:

```bash
# Database directory
chmod 750 /var/lib/sellia/
chown sellia:sellia /var/lib/sellia/

# Database file
chmod 640 /var/lib/sellia/sellia.db
chown sellia:sellia /var/lib/sellia/sellia.db
```

### Encryption

For sensitive data, consider:

- Full disk encryption (LUKS)
- Encrypted backup archives
- Secure backup storage (S3 with encryption, etc.)

## Scaling

### When to Upgrade Storage

Consider upgrading when:

- Database size > 1GB
- High request volume
- Multiple servers needed
- Complex queries needed

### Migration Path

SQLite → PostgreSQL migration (when supported):

1. Export SQLite data
2. Import to PostgreSQL
3. Update configuration
4. Test thoroughly
5. Switch over

## Best Practices

### Development

- Use in-memory storage
- No backup needed
- Fast iteration

### Production

- Always use persistent storage
- Regular automated backups
- Monitor disk usage
- Test restore procedure

### High Availability

- Use PostgreSQL with replication
- Regular backups
- Failover procedures
- Monitoring and alerts

## Troubleshooting

### Database Locked

**Problem:** "Database is locked" error

**Solutions:**
- Check for multiple instances
- Restart server
- Check file permissions
- Enable WAL mode

### Disk Full

**Problem:** Out of disk space

**Solutions:**
- Clean old logs
- Archive old data
- Expand disk capacity
- Implement log rotation

### Slow Queries

**Problem:** Database operations slow

**Solutions:**
- Run `VACUUM` and `ANALYZE`
- Check database size
- Consider upgrading to PostgreSQL
- Optimize queries

## Next Steps

- [Deployment](../deployment/) - Production deployment with storage
- [Admin Guide](../admin/) - Ongoing maintenance
- [Configuration](../configuration/) - Storage configuration options
