# FastConnect Production Deployment Guide

This guide provides comprehensive instructions for deploying the FastConnect landing page to production with SSL certificates, automated updates, and rollback capabilities.

## 📋 Prerequisites

- Ubuntu 20.04+ or Debian 10+ server
- Root or sudo access
- Domain name pointing to your server

## �� Quick Start

1. **Clone repository to server:**

   ```bash
   git clone https://github.com/your-username/fastconnect.git /var/www/fastconnect
   cd /var/www/fastconnect
   ```

2. **Run initial setup:**

   ```bash
   # Install dependencies
   sudo ./install-dependencies.sh

   # Generate SSL certificates
   sudo ./generate-ssl.sh your-domain.com admin@your-domain.com

   # Deploy the application
   sudo ./update-service.sh deploy
   ```

## 📁 Files Overview

| File                      | Purpose                                    |
| ------------------------- | ------------------------------------------ |
| `install-dependencies.sh` | Install required dependencies (nginx, php) |
| `update-service.sh`       | Service deployment from current directory  |
| `nginx.conf`              | Production-ready Nginx configuration       |
| `generate-ssl.sh`         | SSL certificate generation and management  |
| `healthcheck.sh`          | Comprehensive health checks                |
| `revert-changes.sh`       | Complete system rollback capabilities      |

## 🔧 Detailed Setup

### 1. Dependencies Installation (`install-dependencies.sh`)

**Features:**

- Automatic installation of Nginx, PHP 8.1, and required extensions
- Individual component installation
- Installation status checking
- Smart detection of already installed components

**Usage:**

```bash
# Install all dependencies
./install-dependencies.sh

# Install specific components
./install-dependencies.sh nginx
./install-dependencies.sh php

# Check installation status
./install-dependencies.sh status

# Help
./install-dependencies.sh --help
```

### 2. Service Deployment (`update-service.sh`)

**Features:**

- Automated deployment from current directory
- Service management (Nginx, PHP-FPM)
- Nginx configuration management
- Permission management
- Deployment status reporting

**Commands:**

```bash
# Deploy from current directory
./update-service.sh deploy

# Show deployment status
./update-service.sh status

# Help
./update-service.sh --help
```

**Configuration:**

```bash
PROJECT_DIR="/var/www/fastconnect"
NGINX_CONFIG="/etc/nginx/sites-available/fastconnect"
```

### 3. Nginx Configuration (`nginx.conf`)

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
The deployment script automatically handles nginx configuration using your project's `nginx.conf` file.

### 4. SSL Certificate Generation (`generate-ssl.sh`)

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

### 5. Health Checks (`healthcheck.sh`)

**Features:**

- System services monitoring (Nginx, PHP-FPM)
- PHP environment validation
- File system checks
- Network connectivity tests
- System resource monitoring
- Application functionality verification

**Commands:**

```bash
# Run health checks
./healthcheck.sh

# Quiet mode (only exit codes)
./healthcheck.sh --quiet

# JSON output
./healthcheck.sh --format json

# Save to file
./healthcheck.sh --output health-report.log
```

### 6. Revert Changes Script (`revert-changes.sh`)

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

# Show revert status
./revert-changes.sh status

# Verify revert was successful
./revert-changes.sh verify
```

## 🔄 Deployment Workflow

### Initial Deployment

1. **Clone repository to server:**

   ```bash
   # Clone repository to the target directory
   git clone https://github.com/your-username/fastconnect.git /var/www/fastconnect
   cd /var/www/fastconnect
   chmod +x *.sh
   ```

2. **Install dependencies:**

   ```bash
   # Install all required dependencies
   sudo ./install-dependencies.sh

   # Or install individually if needed
   sudo ./install-dependencies.sh nginx
   sudo ./install-dependencies.sh php
   ```

3. **Configure domain (if different from default):**

   ```bash
   # Edit scripts with your domain
   sed -i 's/fastconnectvpn.net/yourdomain.com/g' *.sh *.conf
   sed -i 's/admin@fastconnectvpn.net/admin@yourdomain.com/g' *.sh
   ```

4. **Generate SSL certificates:**

   ```bash
   sudo ./generate-ssl.sh yourdomain.com admin@yourdomain.com
   ```

5. **Deploy application:**

   ```bash
   sudo ./update-service.sh deploy
   ```

6. **Verify deployment:**
   ```bash
   ./healthcheck.sh
   sudo ./update-service.sh status
   ```

### Regular Updates

```bash
# Navigate to project directory
cd /var/www/fastconnect

# Pull latest changes
git pull origin main

# Deploy updates
sudo ./update-service.sh deploy

# Check status
sudo ./update-service.sh status

# Run health checks
./healthcheck.sh
```

### Emergency Procedures

**If deployment fails:**

```bash
# Check what went wrong
./healthcheck.sh

# Use revert script for rollback
sudo ./revert-changes.sh complete
```

**If SSL issues occur:**

```bash
# Regenerate certificates
sudo ./generate-ssl.sh yourdomain.com admin@yourdomain.com

# Or revert SSL only
sudo ./revert-changes.sh partial ssl
```

**Complete system restoration:**

```bash
# This will restore everything to pre-deployment state
sudo ./revert-changes.sh complete
```

## 📊 Monitoring and Logs

### Log Locations

- **Nginx Access:** `/var/log/nginx/fastconnect_access.log`
- **Nginx Error:** `/var/log/nginx/fastconnect_error.log`
- **Application Logs:** `/var/www/fastconnect/logs/`
- **SSL Renewal:** `/var/log/letsencrypt/`

### Health Checks

```bash
# Comprehensive health check
./healthcheck.sh

# Check specific installation status
./install-dependencies.sh status

# Check deployment status
sudo ./update-service.sh status

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
# Project files (handled automatically by deployment script)
chown -R www-data:www-data /var/www/fastconnect
chmod -R 755 /var/www/fastconnect
chmod -R 644 /var/www/fastconnect/*.php

# SSL certificates
chmod 644 /etc/ssl/certs/fastconnect.crt
chmod 600 /etc/ssl/private/fastconnect.key

# Scripts
chmod 700 /var/www/fastconnect/*.sh
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

# Run health checks
./healthcheck.sh
```

## 🚨 Troubleshooting

### Common Issues

**1. Dependencies Not Installed**

```bash
# Check what's missing
./install-dependencies.sh status

# Install missing dependencies
sudo ./install-dependencies.sh
```

**2. SSL Certificate Generation Fails**

```bash
# Check domain DNS
dig yourdomain.com

# Verify webroot is accessible
curl -I http://yourdomain.com/.well-known/acme-challenge/test

# Check certbot logs
tail -f /var/log/letsencrypt/letsencrypt.log
```

**3. Nginx Configuration Errors**

```bash
# Test configuration
nginx -t

# Check syntax errors
nginx -T

# Reload configuration
systemctl reload nginx
```

**4. PHP-FPM Issues**

```bash
# Check PHP-FPM status
systemctl status php8.1-fpm

# Check PHP-FPM logs
tail -f /var/log/php8.1-fpm.log

# Test PHP syntax
php -l /var/www/fastconnect/index.php
```

**5. Permission Issues**

```bash
# Redeploy to fix permissions
sudo ./update-service.sh deploy
```

### Recovery Procedures

**1. Use Health Checks for Diagnosis**

```bash
# Comprehensive system check
./healthcheck.sh

# Check installation status
./install-dependencies.sh status

# Check deployment status
sudo ./update-service.sh status
```

**2. Emergency SSL Recovery**

```bash
# Regenerate certificates
sudo ./generate-ssl.sh yourdomain.com admin@yourdomain.com
```

**3. Complete System Reset**

```bash
# This will remove everything and restore defaults
sudo ./revert-changes.sh complete remove-scripts
```

## 📞 Support

For issues or questions:

1. **Run diagnostics:**

   ```bash
   ./healthcheck.sh
   ./install-dependencies.sh status
   sudo ./update-service.sh status
   ```

2. **Check logs:**

   ```bash
   tail -f /var/log/nginx/fastconnect_error.log
   tail -f /var/www/fastconnect/logs/requests_$(date +%Y-%m-%d).log
   ```

3. **Verify services:**
   ```bash
   systemctl status nginx php8.1-fpm
   nginx -t
   ```

## 🔄 Automation

### Cron Jobs

The scripts automatically set up the following cron jobs:

```bash
# SSL certificate renewal (every 12 hours)
0 */12 * * * /usr/local/bin/renew-fastconnect-ssl.sh

# Optional: Daily health check
0 6 * * * /var/www/fastconnect/healthcheck.sh --quiet || echo "Health check failed" | mail -s "FastConnect Health Alert" admin@example.com

# Optional: Weekly comprehensive report
0 3 * * 0 /var/www/fastconnect/healthcheck.sh --format json --output /var/log/fastconnect-weekly-health.json
```

### CI/CD Integration

For automated deployments, you can integrate with CI/CD pipelines:

```bash
# Example GitHub Actions deployment
ssh root@your-server "cd /var/www/fastconnect && git pull origin main && sudo ./update-service.sh deploy"
```

## 📋 Script Reference

### Installation Script Commands

```bash
./install-dependencies.sh install    # Install all dependencies
./install-dependencies.sh nginx      # Install Nginx only
./install-dependencies.sh php        # Install PHP only
./install-dependencies.sh status     # Check installation status
```

### Deployment Script Commands

```bash
sudo ./update-service.sh deploy      # Deploy from current directory
sudo ./update-service.sh status      # Show deployment status
```

### Health Check Commands

```bash
./healthcheck.sh                     # Run all health checks
./healthcheck.sh --quiet             # Silent mode
./healthcheck.sh --format json       # JSON output
./healthcheck.sh --output file.log   # Save to file
```

---

**⚠️ Important Notes:**

- Always test scripts in a staging environment first
- Run health checks after any changes
- Keep emergency contact information handy
- Monitor SSL certificate expiry dates
- Keep scripts updated with latest security practices
- The deployment script must be run from the FastConnect project directory
