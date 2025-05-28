# FastConnect VPN Landing Page

A PHP-based landing page for FastConnect VPN with traffic cloaking, request logging, and automated deployment capabilities.

## 🚀 Features

- **Traffic Cloaking**: Intelligent traffic filtering using CloakIt API
- **Request Logging**: Comprehensive logging of all incoming requests and API responses
- **File Downloads**: Secure VPN client download functionality
- **SSL Support**: Automated SSL certificate generation and management
- **Production Ready**: Complete deployment scripts with automated installation and rollback capabilities
- **Log Viewer**: Web-based log viewing interface with filtering and search
- **Health Monitoring**: Comprehensive health checks and system monitoring

## 📋 Requirements

- **PHP**: 8.1 or higher
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

### Quick Production Setup

1. **Clone repository to your server:**

   ```bash
   git clone https://github.com/your-username/fastconnect.git /var/www/fastconnect
   cd /var/www/fastconnect
   ```

2. **Run setup:**

   ```bash
   # Install dependencies
   sudo ./install-dependencies.sh

   # Generate SSL certificates
   sudo ./generate-ssl.sh your-domain.com admin@your-domain.com

   # Deploy the application
   sudo ./update-service.sh deploy
   ```

### Manual Setup

1. **Install dependencies manually:**

   ```bash
   # Ubuntu/Debian
   apt update
   apt install -y nginx php8.1-fpm php8.1-curl php8.1-mbstring php8.1-openssl php8.1-json
   ```

2. **Configure your web server** to point to the project directory

3. **Set proper permissions:**
   ```bash
   chmod 755 index.php download.php logs.php
   chmod 755 logs/
   ```

## 📁 Project Structure

```
fastconnect/
├── index.php                 # Main landing page with cloaking logic
├── download.php              # VPN client download handler
├── logs.php                  # Web-based log viewer
├── install-dependencies.sh   # Dependencies installation script
├── update-service.sh         # Deployment automation script
├── nginx.conf                # Production Nginx configuration
├── generate-ssl.sh           # SSL certificate automation
├── healthcheck.sh            # Comprehensive health checks
├── revert-changes.sh         # System rollback capabilities
├── DEPLOYMENT.md             # Detailed deployment guide
├── logs/                     # Request and API response logs
├── favicon/                  # Favicon files
└── FastConnect_VPN.zip       # VPN client download file
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
NGINX_CONFIG="/etc/nginx/sites-available/fastconnect"
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
# Clone repository
git clone https://github.com/your-username/fastconnect.git /var/www/fastconnect
cd /var/www/fastconnect

# Install dependencies
sudo ./install-dependencies.sh

# Generate SSL certificates
sudo ./generate-ssl.sh your-domain.com admin@your-domain.com

# Deploy application
sudo ./update-service.sh deploy

# Check deployment status
sudo ./update-service.sh status

# Run health checks
./healthcheck.sh
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

The system provides comprehensive health checking capabilities:

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

#### Installation Status Check

Check what dependencies are installed:

```bash
# Check installation status
./install-dependencies.sh status
```

#### Deployment Status Check

Check deployment status:

```bash
# Show deployment status
sudo ./update-service.sh status
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

## 🔄 Maintenance

### Dependencies Management

```bash
# Check what's installed
./install-dependencies.sh status

# Install missing dependencies
sudo ./install-dependencies.sh
```

### Updates

```bash
# Navigate to project directory
cd /var/www/fastconnect

# Pull latest changes
git pull origin main

# Deploy updates
sudo ./update-service.sh deploy
```

### Health Monitoring

```bash
# Run comprehensive health check
./healthcheck.sh

# Check specific components
./install-dependencies.sh status
sudo ./update-service.sh status
```

### Rollback

```bash
# Complete system revert
sudo ./revert-changes.sh complete

# Partial revert (specific components)
sudo ./revert-changes.sh partial ssl
sudo ./revert-changes.sh partial nginx
sudo ./revert-changes.sh partial project
```

## 🐛 Troubleshooting

### Common Issues

1. **Dependencies Missing:**

   ```bash
   # Check what's missing
   ./install-dependencies.sh status

   # Install missing dependencies
   sudo ./install-dependencies.sh
   ```

2. **Permission Issues:**

   ```bash
   # Redeploy to fix permissions
   sudo ./update-service.sh deploy
   ```

3. **SSL Certificate Issues:**

   ```bash
   # Regenerate SSL certificate
   sudo ./generate-ssl.sh your-domain.com admin@your-domain.com
   ```

4. **Nginx Configuration:**

   ```bash
   # Test configuration
   nginx -t

   # Reload configuration
   systemctl reload nginx
   ```

5. **Service Issues:**

   ```bash
   # Check service status
   systemctl status nginx php8.1-fpm

   # Restart services
   systemctl restart nginx php8.1-fpm
   ```

### Diagnostic Tools

Use the built-in diagnostic tools:

```bash
# Comprehensive system check
./healthcheck.sh

# Check installation status
./install-dependencies.sh status

# Check deployment status
sudo ./update-service.sh status

# Check logs
tail -f /var/log/nginx/error.log
tail -f logs/requests_$(date +%Y-%m-%d).log
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

## 📋 Script Reference

### Installation Script

```bash
./install-dependencies.sh install    # Install all dependencies
./install-dependencies.sh nginx      # Install Nginx only
./install-dependencies.sh php        # Install PHP only
./install-dependencies.sh status     # Check installation status
```

### Deployment Script

```bash
sudo ./update-service.sh deploy      # Deploy from current directory
sudo ./update-service.sh status      # Show deployment status
```

### Health Check Script

```bash
./healthcheck.sh                     # Run all health checks
./healthcheck.sh --quiet             # Silent mode
./healthcheck.sh --format json       # JSON output
./healthcheck.sh --output file.log   # Save to file
```

### SSL Management

```bash
./generate-ssl.sh                    # Generate with default domain
./generate-ssl.sh domain.com         # Generate for specific domain
./generate-ssl.sh domain.com email   # Generate with custom email
```

### System Recovery

```bash
sudo ./revert-changes.sh complete    # Complete system revert
sudo ./revert-changes.sh partial ssl # Revert SSL only
sudo ./revert-changes.sh status      # Show revert status
```

## 📝 License

This project is proprietary software. All rights reserved.

## 🤝 Support

For support and deployment assistance, please refer to the [DEPLOYMENT.md](DEPLOYMENT.md) guide or contact the development team.

---

**Note**: This landing page includes traffic cloaking functionality. Ensure compliance with all applicable laws and regulations in your jurisdiction.
