# FastConnect VPN Landing Page

A modern, responsive landing page for FastConnect VPN with advanced privacy features, dynamic location switching, and AI-powered security. Built with PHP, featuring a sleek design with Tailwind CSS and Alpine.js.

## 🚀 Features

- **Modern Design**: Clean, responsive interface built with Tailwind CSS
- **Dynamic Content**: Interactive elements powered by Alpine.js
- **Cloaking System**: Integrated with cloaking API for traffic filtering
- **Comprehensive Logging**: Request tracking and API response logging
- **SSL Ready**: Automatic SSL certificate setup with Let's Encrypt
- **Security Headers**: Comprehensive security configuration
- **Performance Optimized**: Gzip compression, caching, and optimized assets

## 📋 Requirements

- Ubuntu 18.04+ (recommended: Ubuntu 22.04 LTS)
- Root access to the server
- Domain name pointing to your server
- Email address for SSL certificates

## 🛠 Quick Deployment

### Automated Deployment (Recommended)

1. **Clone the repository** on your local machine:

   ```bash
   git clone <repository-url>
   cd fastconnect
   ```

2. **Upload to server** using the provided upload script:

   ```bash
   # Upload the deployment script first
   ./upload.sh deploy.sh

   # Upload all project files
   rsync -av --exclude='.git' --exclude='logs' --exclude='.DS_Store' ./ root@69.62.70.193:/root/fastconnect/
   ```

3. **SSH to your server**:

   ```bash
   ssh root@69.62.70.193
   cd /root/fastconnect
   ```

4. **Run the deployment script**:

   ```bash
   # Basic deployment with default domain
   ./deploy.sh

   # Or specify custom domain and email
   ./deploy.sh yourdomain.com admin@yourdomain.com
   ```

The script will automatically:

- Update the system and install dependencies
- Install and configure PHP 8.3-FPM
- Install and configure Nginx
- Deploy project files
- Setup SSL certificates with Let's Encrypt
- Configure firewall rules
- Setup log rotation
- Run comprehensive health checks

### Manual Deployment

If you prefer manual deployment, follow these steps:

<details>
<summary>Click to expand manual deployment steps</summary>

1. **Update system packages**:

   ```bash
   apt update && apt upgrade -y
   apt install -y curl wget unzip software-properties-common
   ```

2. **Install PHP 8.3**:

   ```bash
   add-apt-repository ppa:ondrej/php -y
   apt update
   apt install -y php8.3 php8.3-fpm php8.3-cli php8.3-common php8.3-curl php8.3-mbstring php8.3-xml php8.3-zip php8.3-json php8.3-opcache
   ```

3. **Install Nginx**:

   ```bash
   apt install -y nginx
   systemctl enable nginx
   systemctl start nginx
   ```

4. **Install Certbot**:

   ```bash
   apt install -y certbot python3-certbot-nginx
   ```

5. **Deploy project files**:

   ```bash
   mkdir -p /var/www/fastconnect
   # Copy your project files to /var/www/fastconnect
   chown -R www-data:www-data /var/www/fastconnect
   ```

6. **Configure Nginx** (use the provided nginx.conf as reference)

7. **Setup SSL certificates**:
   ```bash
   certbot --nginx -d yourdomain.com -d www.yourdomain.com
   ```

</details>

## 📁 Project Structure

```
fastconnect/
├── index.php              # Main landing page
├── download.php            # File download handler
├── logs.php               # Log viewer (protected)
├── upload.sh              # File upload utility
├── deploy.sh              # Automated deployment script
├── nginx.conf             # Nginx configuration template
├── favicon.ico            # Website favicon
├── favicon/               # Favicon variants
│   ├── apple-touch-icon.png
│   ├── favicon-16x16.png
│   ├── favicon-32x32.png
│   └── site.webmanifest
├── logs/                  # Application logs (auto-created)
│   ├── requests_YYYY-MM-DD.log
│   └── api_responses_YYYY-MM-DD.log
├── FastConnect_VPN.zip    # VPN application download
└── README.md              # This file
```

## 🔧 Configuration

### Environment Variables

The application uses the following configuration in `index.php`:

```php
$domain = 'https://fastconnectvpn.net';  // Your domain
```

### Cloaking API

The application integrates with a cloaking service. Configure the API endpoint and label in `index.php`:

```php
$request_data = [
    'label' => '7e4751d376339c9ba38f57829ccefe9a',  // Your cloaking label
    // ... other parameters
];
```

### Nginx Configuration

The deployment script automatically configures Nginx with:

- SSL/TLS encryption (TLS 1.2/1.3)
- Security headers
- Gzip compression
- Static file caching
- PHP-FPM integration
- Log protection

## 📊 Monitoring & Logs

### Log Files

The application generates several types of logs:

1. **Request Logs** (`logs/requests_YYYY-MM-DD.log`):

   - User IP addresses
   - User agents
   - Referrers
   - Request timestamps
   - Browser languages

2. **API Response Logs** (`logs/api_responses_YYYY-MM-DD.log`):

   - Cloaking API responses
   - Response times
   - HTTP status codes
   - Error messages

3. **System Logs**:
   - Nginx access: `/var/log/nginx/fastconnect_access.log`
   - Nginx errors: `/var/log/nginx/fastconnect_error.log`
   - Deployment: `/var/log/fastconnect-deploy.log`

### Log Viewer

Access the web-based log viewer at:

```
https://yourdomain.com/logs.php?allow=1
```

**Note**: The log viewer is IP-restricted for security. Add your IP to the allowed list in `logs.php` or use the `?allow=1` parameter.

### Health Checks

Run health checks manually:

```bash
# Check service status
systemctl status nginx
systemctl status php8.3-fpm

# Check website accessibility
curl -I http://yourdomain.com
curl -I https://yourdomain.com

# View recent logs
tail -f /var/log/nginx/fastconnect_error.log
tail -f /var/www/fastconnect/logs/requests_$(date +%Y-%m-%d).log
```

## 🔒 Security Features

### Built-in Security

- **SSL/TLS Encryption**: Automatic HTTPS with Let's Encrypt
- **Security Headers**: HSTS, CSP, X-Frame-Options, etc.
- **Log Protection**: Nginx blocks access to log files
- **Hidden Files Protection**: Blocks access to dotfiles
- **Input Validation**: PHP filters and validation
- **Firewall Configuration**: UFW rules for HTTP/HTTPS/SSH

### IP Restrictions

The log viewer includes IP restrictions. To add your IP:

1. Edit `logs.php`
2. Add your IP to the `$allowed_ips` array:
   ```php
   $allowed_ips = ['127.0.0.1', '::1', 'YOUR.IP.ADDRESS.HERE'];
   ```

## 🚀 Performance Optimization

### Caching

- **Static Files**: 1-year cache for images, CSS, JS
- **Gzip Compression**: Enabled for text-based files
- **PHP OPcache**: Enabled for improved PHP performance

### CDN Integration

The application loads external resources from CDNs:

- Tailwind CSS
- Alpine.js
- Lucide Icons
- Google Fonts (Geist)

## 🔄 Maintenance

### SSL Certificate Renewal

Certificates are automatically renewed via cron job:

```bash
# View current cron jobs
crontab -l

# Manual renewal
certbot renew --nginx
```

### Log Rotation

Logs are automatically rotated daily and compressed:

- Keeps 30 days of logs
- Compresses old logs
- Maintains proper permissions

### Updates

To update the application:

1. **Backup current installation**:

   ```bash
   cp -r /var/www/fastconnect /var/www/fastconnect.backup.$(date +%Y%m%d)
   ```

2. **Upload new files**:

   ```bash
   # From your local machine
   rsync -av --exclude='.git' --exclude='logs' ./ root@69.62.70.193:/var/www/fastconnect/
   ```

3. **Set permissions**:
   ```bash
   chown -R www-data:www-data /var/www/fastconnect
   chmod -R 644 /var/www/fastconnect
   find /var/www/fastconnect -type d -exec chmod 755 {} \;
   ```

## 🛠 Troubleshooting

### Common Issues

1. **Website not accessible**:

   ```bash
   # Check Nginx status
   systemctl status nginx

   # Check Nginx configuration
   nginx -t

   # Check firewall
   ufw status
   ```

2. **PHP errors**:

   ```bash
   # Check PHP-FPM status
   systemctl status php8.3-fpm

   # Check PHP error logs
   tail -f /var/log/php8.3-fpm.log
   ```

3. **SSL certificate issues**:

   ```bash
   # Check certificate status
   certbot certificates

   # Test SSL configuration
   openssl s_client -connect yourdomain.com:443
   ```

4. **Permission issues**:
   ```bash
   # Fix file permissions
   chown -R www-data:www-data /var/www/fastconnect
   find /var/www/fastconnect -type f -exec chmod 644 {} \;
   find /var/www/fastconnect -type d -exec chmod 755 {} \;
   ```

### Log Analysis

Check application logs for issues:

```bash
# View recent requests
tail -f /var/www/fastconnect/logs/requests_$(date +%Y-%m-%d).log

# View API responses
tail -f /var/www/fastconnect/logs/api_responses_$(date +%Y-%m-%d).log

# View Nginx errors
tail -f /var/log/nginx/fastconnect_error.log
```

## 📞 Support

For deployment issues or questions:

1. Check the deployment logs: `/var/log/fastconnect-deploy.log`
2. Review the troubleshooting section above
3. Verify all services are running: `systemctl status nginx php8.3-fpm`

## 📄 License

This project is proprietary software. All rights reserved.

---

**FastConnect VPN** - Revolutionary VPN technology for the privacy-conscious user.
