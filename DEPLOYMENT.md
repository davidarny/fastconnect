# FastConnect Production Deployment Guide

This guide provides comprehensive instructions for deploying the FastConnect landing page to production with SSL certificates, automated updates, and rollback capabilities.

## 📋 Prerequisites

- Ubuntu 20.04+ or Debian 10+ server
- Root or sudo access
- Domain name pointing to your server
- Nginx and PHP 8.1+ installed
- Git installed

## 🚀 Quick Start

1. **Copy files to server:**

   ```bash
   scp -r . root@your-server:/root/fastconnect-deployment/
   ```

2. **Run initial setup:**
   ```bash
   cd /root/fastconnect-deployment/
   ./generate-ssl.sh your-domain.com admin@your-domain.com
   ./update-service.sh deploy
   ```

## 📁 Files Overview

| File                | Purpose                                   |
| ------------------- | ----------------------------------------- |
| `nginx.conf`        | Production-ready Nginx configuration      |
| `generate-ssl.sh`   | SSL certificate generation and management |
| `update-service.sh` | Service deployment and update automation  |
| `revert-changes.sh` | Complete system rollback capabilities     |

## 🔧 Detailed Setup

### 1. Nginx Configuration (`nginx.conf`)

**Features:**

- HTTP to HTTPS redirect
- SSL/TLS configuration with modern ciphers
- Security headers (HSTS, CSP, etc.)
- Gzip compression
- Rate limiting
- Static file caching
- PHP-FPM integration
- Log protection

**Installation:**

```bash
# Copy to nginx sites-available
cp nginx.conf /etc/nginx/sites-available/fastconnect

# Enable the site
ln -s /etc/nginx/sites-available/fastconnect /etc/nginx/sites-enabled/

# Test configuration
nginx -t

# Reload nginx
systemctl reload nginx
```

### 2. SSL Certificate Generation (`generate-ssl.sh`)

**Features:**

- Automatic Let's Encrypt certificate generation
- Domain validation via webroot
- Auto-renewal setup with cron jobs
- Certificate backup and restoration
- Multi-domain support

**Usage:**

```bash
# Basic usage (uses default domain)
./generate-ssl.sh

# Custom domain
./generate-ssl.sh yourdomain.com

# Custom domain and email
./generate-ssl.sh yourdomain.com admin@yourdomain.com

# Help
./generate-ssl.sh --help
```

**Configuration:**
Edit the script to change default values:

```bash
DOMAIN="fastconnectvpn.net"
EMAIL="admin@fastconnectvpn.net"
WEBROOT="/var/www/fastconnect"
```

### 3. Service Update Script (`update-service.sh`)

**Features:**

- Automated deployment from Git or local files
- Automatic backup before updates
- Health checks and rollback on failure
- Service management (Nginx, PHP-FPM)
- Permission management
- Deployment status reporting

**Commands:**

```bash
# Deploy from Git (default)
./update-service.sh deploy

# Deploy from local directory
./update-service.sh deploy /path/to/local/files

# Rollback to previous version
./update-service.sh rollback

# Rollback to specific backup
./update-service.sh rollback /var/backups/fastconnect/20231201_143022

# Show deployment status
./update-service.sh status

# Create backup only
./update-service.sh backup

# Run health checks only
./update-service.sh health
```

**Configuration:**

```bash
PROJECT_DIR="/var/www/fastconnect"
BACKUP_DIR="/var/backups/fastconnect"
REPO_URL="https://github.com/your-username/fastconnect.git"
BRANCH="main"
```

### 4. Revert Changes Script (`revert-changes.sh`)

**Features:**

- Complete system restoration
- Selective component removal
- Emergency backup creation
- Service restoration
- Verification and status reporting

**Commands:**

```bash
# Complete revert (keeps scripts)
./revert-changes.sh complete

# Complete revert (removes scripts too)
./revert-changes.sh complete remove-scripts

# Partial revert (specific components)
./revert-changes.sh partial ssl,nginx
./revert-changes.sh partial project
./revert-changes.sh partial backups

# Show revert status
./revert-changes.sh status

# Verify revert was successful
./revert-changes.sh verify
```

## 🔄 Deployment Workflow

### Initial Deployment

1. **Prepare server:**

   ```bash
   # Update system
   apt update && apt upgrade -y

   # Install required packages
   apt install -y nginx php8.1-fpm php8.1-curl php8.1-mbstring php8.1-openssl php8.1-json git certbot python3-certbot-nginx
   ```

2. **Deploy scripts:**

   ```bash
   mkdir -p /root/fastconnect-deployment
   cd /root/fastconnect-deployment
   # Copy all files here
   chmod +x *.sh
   ```

3. **Configure domain:**

   ```bash
   # Edit scripts with your domain
   sed -i 's/fastconnectvpn.net/yourdomain.com/g' *.sh *.conf
   sed -i 's/admin@fastconnectvpn.net/admin@yourdomain.com/g' *.sh
   ```

4. **Generate SSL certificates:**

   ```bash
   ./generate-ssl.sh yourdomain.com admin@yourdomain.com
   ```

5. **Deploy application:**
   ```bash
   ./update-service.sh deploy
   ```

### Regular Updates

```bash
# Update from Git
./update-service.sh deploy

# Check status
./update-service.sh status

# If issues occur, rollback
./update-service.sh rollback
```

### Emergency Procedures

**If deployment fails:**

```bash
# Rollback to last working version
./update-service.sh rollback

# Check what went wrong
./update-service.sh health
```

**If SSL issues occur:**

```bash
# Regenerate certificates
./generate-ssl.sh yourdomain.com admin@yourdomain.com

# Or revert SSL only
./revert-changes.sh partial ssl
```

**Complete system restoration:**

```bash
# This will restore everything to pre-deployment state
./revert-changes.sh complete
```

## 📊 Monitoring and Logs

### Log Locations

- **Nginx Access:** `/var/log/nginx/fastconnect_access.log`
- **Nginx Error:** `/var/log/nginx/fastconnect_error.log`
- **Application Logs:** `/var/www/fastconnect/logs/`
- **SSL Renewal:** `/var/log/letsencrypt/`

### Health Checks

```bash
# Manual health check
./update-service.sh health

# Check service status
systemctl status nginx php8.1-fpm

# Test SSL certificate
openssl s_client -connect yourdomain.com:443 -servername yourdomain.com

# Check certificate expiry
certbot certificates
```

## 🔐 Security Considerations

### File Permissions

```bash
# Project files
chown -R www-data:www-data /var/www/fastconnect
chmod -R 755 /var/www/fastconnect
chmod -R 644 /var/www/fastconnect/*.php

# SSL certificates
chmod 644 /etc/ssl/certs/fastconnect.crt
chmod 600 /etc/ssl/private/fastconnect.key

# Scripts
chmod 700 /root/fastconnect-deployment/*.sh
```

### Firewall Configuration

```bash
# Allow HTTP and HTTPS
ufw allow 80/tcp
ufw allow 443/tcp

# Enable firewall
ufw enable
```

### Regular Maintenance

```bash
# Update system packages
apt update && apt upgrade -y

# Check SSL certificate renewal
certbot renew --dry-run

# Clean old backups (keep last 10)
find /var/backups/fastconnect -type d -mtime +30 -exec rm -rf {} +
```

## 🚨 Troubleshooting

### Common Issues

**1. SSL Certificate Generation Fails**

```bash
# Check domain DNS
dig yourdomain.com

# Verify webroot is accessible
curl -I http://yourdomain.com/.well-known/acme-challenge/test

# Check certbot logs
tail -f /var/log/letsencrypt/letsencrypt.log
```

**2. Nginx Configuration Errors**

```bash
# Test configuration
nginx -t

# Check syntax errors
nginx -T

# Reload configuration
systemctl reload nginx
```

**3. PHP-FPM Issues**

```bash
# Check PHP-FPM status
systemctl status php8.1-fpm

# Check PHP-FPM logs
tail -f /var/log/php8.1-fpm.log

# Test PHP syntax
php -l /var/www/fastconnect/index.php
```

**4. Permission Issues**

```bash
# Fix ownership
chown -R www-data:www-data /var/www/fastconnect

# Fix permissions
find /var/www/fastconnect -type d -exec chmod 755 {} \;
find /var/www/fastconnect -type f -exec chmod 644 {} \;
```

### Recovery Procedures

**1. Restore from Backup**

```bash
# List available backups
ls -la /var/backups/fastconnect/

# Restore specific backup
./update-service.sh rollback /var/backups/fastconnect/20231201_143022
```

**2. Emergency SSL Recovery**

```bash
# Use emergency backup
cp /var/backups/fastconnect-emergency/*/letsencrypt /etc/ -r

# Or regenerate
./generate-ssl.sh yourdomain.com admin@yourdomain.com
```

**3. Complete System Reset**

```bash
# This will remove everything and restore defaults
./revert-changes.sh complete remove-scripts
```

## 📞 Support

For issues or questions:

1. Check the logs in `/var/log/nginx/` and `/var/www/fastconnect/logs/`
2. Run health checks: `./update-service.sh health`
3. Verify configuration: `nginx -t`
4. Check service status: `systemctl status nginx php8.1-fpm`

## 🔄 Automation

### Cron Jobs

The scripts automatically set up the following cron jobs:

```bash
# SSL certificate renewal (every 12 hours)
0 */12 * * * /usr/local/bin/renew-fastconnect-ssl.sh

# Optional: Daily backup
0 2 * * * /root/fastconnect-deployment/update-service.sh backup

# Optional: Weekly health check
0 3 * * 0 /root/fastconnect-deployment/update-service.sh health
```

### CI/CD Integration

For automated deployments, you can integrate with CI/CD pipelines:

```bash
# Example GitHub Actions deployment
ssh root@your-server "cd /root/fastconnect-deployment && ./update-service.sh deploy"
```

---

**⚠️ Important Notes:**

- Always test scripts in a staging environment first
- Keep emergency contact information handy
- Regularly backup your data
- Monitor SSL certificate expiry dates
- Keep scripts updated with latest security practices
