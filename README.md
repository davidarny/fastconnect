# FastConnect VPN Landing Page

A PHP-based landing page for FastConnect VPN with traffic cloaking, request logging, and automated deployment capabilities.

## 🚀 Features

- **Traffic Cloaking**: Intelligent traffic filtering using CloakIt API
- **Request Logging**: Comprehensive logging of all incoming requests and API responses
- **File Downloads**: Secure VPN client download functionality
- **SSL Support**: Automated SSL certificate generation and management
- **Production Ready**: Complete deployment scripts with backup and rollback capabilities
- **Log Viewer**: Web-based log viewing interface with filtering and search

## 📋 Requirements

- **PHP**: 7.2 or higher
- **PHP Extensions**:
  - cURL
  - mbstring
  - OpenSSL
  - JSON
  - Filter
- **Server**: Nginx (recommended) or Apache
- **OS**: Ubuntu 20.04+ or Debian 10+ (for deployment scripts)
- **SSL**: Let's Encrypt (automated via included scripts)

## 🛠️ Installation

### Quick Setup

1. **Clone or download the project:**

   ```bash
   git clone <repository-url> fastconnect
   cd fastconnect
   ```

2. **For production deployment:**

   ```bash
   # Copy files to your server
   scp -r . root@your-server:/root/fastconnect-deployment/

   # SSH to your server and run setup
   ssh root@your-server
   cd /root/fastconnect-deployment/
   ./generate-ssl.sh your-domain.com admin@your-domain.com
   ./update-service.sh deploy
   ```

### Manual Setup

1. **Configure your web server** to point to the project directory
2. **Set proper permissions:**
   ```bash
   chmod 755 index.php download.php logs.php
   chmod 755 logs/
   ```
3. **Ensure PHP extensions are installed**
4. **Configure SSL** (recommended for production)

## 📁 Project Structure

```
fastconnect/
├── index.php              # Main landing page with cloaking logic
├── download.php            # VPN client download handler
├── logs.php               # Web-based log viewer
├── nginx.conf             # Production Nginx configuration
├── generate-ssl.sh        # SSL certificate automation
├── update-service.sh      # Deployment and update automation
├── revert-changes.sh      # System rollback capabilities
├── DEPLOYMENT.md          # Detailed deployment guide
├── logs/                  # Request and API response logs
├── favicon/               # Favicon files
└── FastConnect_VPN.zip    # VPN client download file
```

## 🔧 Configuration

### Main Configuration

Edit the domain in `index.php`:

```php
$domain = 'https://fastconnectvpn.net';
```

### Cloaking Configuration

The system uses CloakIt API for traffic filtering. Configure the label in `index.php`:

```php
$request_data = [
    'label' => '7e4751d376339c9ba38f57829ccefe9a', // Your CloakIt label
    // ... other parameters
];
```

### Deployment Scripts Configuration

Edit variables in the deployment scripts:

**`generate-ssl.sh`:**

```bash
DOMAIN="fastconnectvpn.net"
EMAIL="admin@fastconnectvpn.net"
WEBROOT="/var/www/fastconnect"
```

**`update-service.sh`:**

```bash
PROJECT_DIR="/var/www/fastconnect"
BACKUP_DIR="/var/backups/fastconnect"
REPO_URL="https://github.com/your-username/fastconnect.git"
BRANCH="main"
```

## 📊 Logging

The system provides comprehensive logging capabilities:

### Request Logs

- **Location**: `logs/requests_YYYY-MM-DD.log`
- **Content**: IP address, user agent, referer, request details, browser language
- **Format**: JSON (one entry per line)

### API Response Logs

- **Location**: `logs/api_responses_YYYY-MM-DD.log`
- **Content**: CloakIt API responses, response times, HTTP codes
- **Format**: JSON (one entry per line)

### Log Viewer

Access the web-based log viewer at `/logs.php`:

- **Security**: IP-based access control (configure in `logs.php`)
- **Features**: Date filtering, log type selection, JSON formatting
- **URL Parameters**:
  - `?type=requests` or `?type=api_responses`
  - `?date=YYYY-MM-DD`
  - `?allow=1` (bypass IP restrictions)

## 🔒 Security Features

- **IP-based access control** for log viewer
- **SSL/TLS encryption** with modern cipher suites
- **Security headers** (HSTS, CSP, X-Frame-Options)
- **Rate limiting** via Nginx configuration
- **Input validation** and sanitization
- **Secure file downloads** with proper headers

## 🚀 Deployment

### Production Deployment

See [DEPLOYMENT.md](DEPLOYMENT.md) for comprehensive deployment instructions.

**Quick commands:**

```bash
# Initial deployment
./generate-ssl.sh your-domain.com admin@your-domain.com
./update-service.sh deploy

# Update deployment
./update-service.sh deploy

# Rollback if needed
./update-service.sh rollback

# Check status
./update-service.sh status
```

### Development Setup

1. **Local PHP server:**

   ```bash
   php -S localhost:8000
   ```

2. **With Docker:**
   ```bash
   docker run -p 8000:80 -v $(pwd):/var/www/html php:8.1-apache
   ```

## 📈 Monitoring

### Health Checks

The system provides comprehensive health checking capabilities through multiple interfaces:

#### Comprehensive Health Check Script

**`healthcheck.sh`** - Standalone bash script for system-level health checks:

```bash
# Basic health check
./healthcheck.sh

# Quiet mode (only exit code)
./healthcheck.sh --quiet

# JSON output
./healthcheck.sh --format json

# Save output to file
./healthcheck.sh --output health-report.log
```

**Features:**

- System services (Nginx, PHP-FPM)
- PHP environment and extensions
- File system permissions and required files
- Network connectivity and API endpoints
- System resources (disk, memory, CPU load)
- Application functionality and syntax checks

#### Deployment Script Integration

The deployment script includes health checks:

```bash
# Run health checks only
./update-service.sh health

# Health checks with JSON output
./update-service.sh health json

# Save health check results to file
./update-service.sh health text health-report.log
```

#### Exit Codes

- **0**: All checks passed (healthy)
- **1**: Some checks failed with warnings
- **2**: Critical checks failed (unhealthy)

#### Monitoring Integration

Add to crontab for automated monitoring:

```bash
# Daily health check with email notification
0 6 * * * /var/www/fastconnect/healthcheck.sh --quiet || echo "Health check failed" | mail -s "FastConnect Health Alert" admin@example.com

# Weekly comprehensive report
0 3 * * 0 /var/www/fastconnect/healthcheck.sh --format json --output /var/log/fastconnect-weekly-health.json
```

### Log Monitoring

Monitor logs in real-time:

```bash
# Request logs
tail -f logs/requests_$(date +%Y-%m-%d).log

# API response logs
tail -f logs/api_responses_$(date +%Y-%m-%d).log
```

### System Status

Check deployment status:

```bash
./update-service.sh status
```

## 🔄 Maintenance

### Backup

```bash
# Create manual backup
./update-service.sh backup

# Backups are stored in /var/backups/fastconnect/
```

### Updates

```bash
# Deploy latest changes
./update-service.sh deploy

# Deploy from specific directory
./update-service.sh deploy /path/to/local/files
```

### Rollback

```bash
# Rollback to previous version
./update-service.sh rollback

# Rollback to specific backup
./update-service.sh rollback /var/backups/fastconnect/20231201_143022

# Complete system revert
./revert-changes.sh complete
```

## 🐛 Troubleshooting

### Common Issues

1. **PHP Extensions Missing:**

   ```bash
   # Ubuntu/Debian
   sudo apt install php8.1-curl php8.1-mbstring php8.1-openssl php8.1-json
   ```

2. **Permission Issues:**

   ```bash
   chmod 755 *.php
   chmod 755 logs/
   chown -R www-data:www-data logs/
   ```

3. **SSL Certificate Issues:**

   ```bash
   # Regenerate SSL certificate
   ./generate-ssl.sh your-domain.com admin@your-domain.com
   ```

4. **Nginx Configuration:**

   ```bash
   # Test configuration
   nginx -t

   # Reload configuration
   systemctl reload nginx
   ```

### Log Analysis

Check logs for errors:

```bash
# PHP errors
tail -f /var/log/nginx/error.log

# Application logs
tail -f logs/requests_$(date +%Y-%m-%d).log | jq .

# API response logs
tail -f logs/api_responses_$(date +%Y-%m-%d).log | jq .
```

## 📝 License

This project is proprietary software. All rights reserved.

## 🤝 Support

For support and deployment assistance, please refer to the [DEPLOYMENT.md](DEPLOYMENT.md) guide or contact the development team.

---

**Note**: This landing page includes traffic cloaking functionality. Ensure compliance with all applicable laws and regulations in your jurisdiction.
