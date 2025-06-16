#!/bin/bash

# ProtectShield VPN Deployment Script
# This script deploys the ProtectShield VPN landing page to a fresh Ubuntu server
# Usage: ./deploy.sh [domain] [email]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Configuration
DOMAIN="${1:-protectshield.net}"
EMAIL="${2:-admin@${DOMAIN}}"
PROJECT_DIR="/var/www/protectshield"
NGINX_CONF="/etc/nginx/sites-available/protectshield"
PHP_VERSION="8.3"
LOG_FILE="/var/log/protectshield-deploy.log"

# Function to print colored output
print_status() {
  echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

print_success() {
  echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

print_warning() {
  echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

print_error() {
  echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

print_header() {
  echo -e "${PURPLE}================================${NC}"
  echo -e "${PURPLE}$1${NC}"
  echo -e "${PURPLE}================================${NC}"
}

# Function to check if command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Function to check if service is running
service_running() {
  systemctl is-active --quiet "$1"
}

# Function to backup existing files
backup_file() {
  local file="$1"
  if [ -f "$file" ]; then
    local backup="${file}.backup.$(date +%Y%m%d_%H%M%S)"
    print_status "Backing up $file to $backup"
    cp "$file" "$backup"
  fi
}

# Function to create directory if it doesn't exist
ensure_directory() {
  local dir="$1"
  local owner="${2:-www-data:www-data}"
  local perms="${3:-755}"

  if [ ! -d "$dir" ]; then
    print_status "Creating directory: $dir"
    mkdir -p "$dir"
    chown "$owner" "$dir"
    chmod "$perms" "$dir"
  fi
}

# Function to update system packages
update_system() {
  print_header "UPDATING SYSTEM PACKAGES"

  print_status "Updating package lists..."
  apt update -y >>"$LOG_FILE" 2>&1

  print_status "Upgrading system packages..."
  apt upgrade -y >>"$LOG_FILE" 2>&1

  print_status "Installing essential packages..."
  apt install -y curl wget unzip software-properties-common apt-transport-https ca-certificates gnupg lsb-release >>"$LOG_FILE" 2>&1

  print_success "System packages updated successfully"
}

# Function to install PHP 8.3
install_php() {
  print_header "INSTALLING PHP ${PHP_VERSION}"

  if command_exists php && php -v | grep -q "PHP ${PHP_VERSION}"; then
    print_warning "PHP ${PHP_VERSION} is already installed"
    return 0
  fi

  print_status "Adding Ondrej PHP repository..."
  add-apt-repository ppa:ondrej/php -y >>"$LOG_FILE" 2>&1
  apt update -y >>"$LOG_FILE" 2>&1

  print_status "Installing PHP ${PHP_VERSION} and extensions..."
  apt install -y \
    php${PHP_VERSION} \
    php${PHP_VERSION}-fpm \
    php${PHP_VERSION}-cli \
    php${PHP_VERSION}-curl \
    php${PHP_VERSION}-mbstring >>"$LOG_FILE" 2>&1

  print_status "Configuring PHP-FPM..."

  # Configure PHP-FPM pool
  local fpm_pool="/etc/php/${PHP_VERSION}/fpm/pool.d/www.conf"
  backup_file "$fpm_pool"

  # Update PHP-FPM configuration
  sed -i 's/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/' "/etc/php/${PHP_VERSION}/fpm/php.ini"
  sed -i 's/upload_max_filesize = 2M/upload_max_filesize = 10M/' "/etc/php/${PHP_VERSION}/fpm/php.ini"
  sed -i 's/post_max_size = 8M/post_max_size = 10M/' "/etc/php/${PHP_VERSION}/fpm/php.ini"
  sed -i 's/max_execution_time = 30/max_execution_time = 60/' "/etc/php/${PHP_VERSION}/fpm/php.ini"
  sed -i 's/memory_limit = 128M/memory_limit = 256M/' "/etc/php/${PHP_VERSION}/fpm/php.ini"

  # Enable and start PHP-FPM
  systemctl enable php${PHP_VERSION}-fpm >>"$LOG_FILE" 2>&1
  systemctl start php${PHP_VERSION}-fpm >>"$LOG_FILE" 2>&1

  print_success "PHP ${PHP_VERSION} installed and configured successfully"
}

# Function to install Nginx
install_nginx() {
  print_header "INSTALLING NGINX"

  if command_exists nginx; then
    print_warning "Nginx is already installed"
    return 0
  fi

  print_status "Installing Nginx..."
  apt install -y nginx >>"$LOG_FILE" 2>&1

  print_status "Configuring Nginx..."

  # Remove default site
  if [ -f "/etc/nginx/sites-enabled/default" ]; then
    rm -f /etc/nginx/sites-enabled/default
  fi

  # Enable and start Nginx
  systemctl enable nginx >>"$LOG_FILE" 2>&1
  systemctl start nginx >>"$LOG_FILE" 2>&1

  print_success "Nginx installed and started successfully"
}

# Function to install Certbot for SSL
install_certbot() {
  print_header "INSTALLING CERTBOT FOR SSL"

  if command_exists certbot; then
    print_warning "Certbot is already installed"
    return 0
  fi

  print_status "Installing Certbot..."
  apt install -y certbot python3-certbot-nginx >>"$LOG_FILE" 2>&1

  print_success "Certbot installed successfully"
}

# Function to deploy project files
deploy_project() {
  print_header "DEPLOYING PROJECT FILES"

  # Create project directory
  ensure_directory "$PROJECT_DIR" "www-data:www-data" "755"

  print_status "Copying project files..."

  # Copy all project files except .git and logs
  rsync -av --exclude='.git' --exclude='logs' --exclude='.DS_Store' --exclude='deploy.sh' ./ "$PROJECT_DIR/" >>"$LOG_FILE" 2>&1

  # Create logs directory
  ensure_directory "$PROJECT_DIR/logs" "www-data:www-data" "755"

  # Set proper permissions
  print_status "Setting file permissions..."
  chown -R www-data:www-data "$PROJECT_DIR"
  find "$PROJECT_DIR" -type f -exec chmod 644 {} \;
  find "$PROJECT_DIR" -type d -exec chmod 755 {} \;
  chmod 755 "$PROJECT_DIR/logs"

  print_success "Project files deployed successfully"
}

# Function to configure Nginx
configure_nginx() {
  print_header "CONFIGURING NGINX"

  backup_file "$NGINX_CONF"

  print_status "Creating Nginx configuration..."

  # Create initial HTTP-only configuration for SSL certificate generation
  cat >"$NGINX_CONF" <<EOF
server {
    listen 80;
    server_name $DOMAIN www.$DOMAIN;
    
    root $PROJECT_DIR;
    index index.php index.html;
    
    # Allow Certbot challenges
    location /.well-known/acme-challenge/ {
        root $PROJECT_DIR;
        allow all;
    }
    
    # Main location block
    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }
    
    # PHP-FPM Configuration
    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php${PHP_VERSION}-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
        
        # Security
        fastcgi_hide_header X-Powered-By;
        
        # Timeouts
        fastcgi_connect_timeout 60s;
        fastcgi_send_timeout 60s;
        fastcgi_read_timeout 60s;
        
        # Buffer sizes
        fastcgi_buffer_size 128k;
        fastcgi_buffers 4 256k;
        fastcgi_busy_buffers_size 256k;
    }
    
    # Static files caching
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|pdf|txt)\$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        access_log off;
    }
    
    # Logs directory protection
    location ^~ /logs/ {
        deny all;
        return 404;
    }
    
    # Hidden files protection
    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }
    
    # Favicon
    location = /favicon.ico {
        log_not_found off;
        access_log off;
    }
    
    # Error pages
    error_page 404 /index.php;
    error_page 500 502 503 504 /50x.html;
    
    # Logging
    access_log /var/log/nginx/fastconnect_access.log;
    error_log /var/log/nginx/fastconnect_error.log;
    
    # Client settings
    client_max_body_size 10M;
    client_body_timeout 60s;
    client_header_timeout 60s;
}
EOF

  # Enable the site
  ln -sf "$NGINX_CONF" /etc/nginx/sites-enabled/

  # Test Nginx configuration
  print_status "Testing Nginx configuration..."
  if nginx -t >>"$LOG_FILE" 2>&1; then
    print_success "Nginx configuration is valid"
    systemctl reload nginx >>"$LOG_FILE" 2>&1
  else
    print_error "Nginx configuration test failed"
    exit 1
  fi

  print_success "Nginx configured successfully"
}

# Function to setup SSL certificates
setup_ssl() {
  print_header "SETTING UP SSL CERTIFICATES"

  # Check if certificates already exist
  if [ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]; then
    print_warning "SSL certificates already exist for $DOMAIN"
    print_status "Updating Nginx configuration with existing SSL certificates..."
  else
    print_status "Obtaining SSL certificate for $DOMAIN..."

    # Stop nginx temporarily for standalone mode
    systemctl stop nginx >>"$LOG_FILE" 2>&1

    # Obtain certificate using standalone mode
    if certbot certonly --standalone --non-interactive --agree-tos --email "$EMAIL" -d "$DOMAIN" -d "www.$DOMAIN" >>"$LOG_FILE" 2>&1; then
      print_success "SSL certificate obtained successfully"
    else
      print_error "Failed to obtain SSL certificate"
      systemctl start nginx >>"$LOG_FILE" 2>&1
      return 1
    fi

    # Start nginx again
    systemctl start nginx >>"$LOG_FILE" 2>&1
  fi

  # Always update Nginx configuration with SSL (whether certificates are new or existing)
  print_status "Updating Nginx configuration with SSL..."

  # Update Nginx configuration with SSL
  cat >"$NGINX_CONF" <<EOF
server {
    listen 80;
    server_name $DOMAIN www.$DOMAIN;
    
    # Redirect all HTTP traffic to HTTPS
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $DOMAIN www.$DOMAIN;
    
    # Document root
    root $PROJECT_DIR;
    index index.php index.html;
    
    # SSL Configuration
    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-SHA384;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    ssl_stapling on;
    ssl_stapling_verify on;
    
    # Security Headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline' 'unsafe-eval'" always;
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    
    # Gzip Compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_proxied expired no-cache no-store private auth;
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/javascript
        application/xml+rss
        application/json
        image/svg+xml;
    
    # Main location block
    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }
    
    # PHP-FPM Configuration
    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php${PHP_VERSION}-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
        
        # Security
        fastcgi_hide_header X-Powered-By;
        
        # Timeouts
        fastcgi_connect_timeout 60s;
        fastcgi_send_timeout 60s;
        fastcgi_read_timeout 60s;
        
        # Buffer sizes
        fastcgi_buffer_size 128k;
        fastcgi_buffers 4 256k;
        fastcgi_busy_buffers_size 256k;
    }
    
    # Static files caching
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|pdf|txt)\$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        access_log off;
    }
    
    # Logs directory protection
    location ^~ /logs/ {
        deny all;
        return 404;
    }
    
    # Hidden files protection
    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }
    
    # Favicon
    location = /favicon.ico {
        log_not_found off;
        access_log off;
    }
    
    # Robots.txt
    location = /robots.txt {
        allow all;
        log_not_found off;
        access_log off;
    }
    
    # Error pages
    error_page 404 /index.php;
    error_page 500 502 503 504 /50x.html;
    
    # Logging
    access_log /var/log/nginx/fastconnect_access.log;
    error_log /var/log/nginx/fastconnect_error.log;
    
    # Client settings
    client_max_body_size 10M;
    client_body_timeout 60s;
    client_header_timeout 60s;
}
EOF

  # Test and reload Nginx
  if nginx -t >>"$LOG_FILE" 2>&1; then
    systemctl reload nginx >>"$LOG_FILE" 2>&1
    print_success "Nginx configuration updated with SSL"
  else
    print_error "Nginx SSL configuration test failed"
    exit 1
  fi

  # Setup automatic certificate renewal
  print_status "Setting up automatic certificate renewal..."
  (
    crontab -l 2>/dev/null
    echo "0 12 * * * /usr/bin/certbot renew --quiet --nginx"
  ) | crontab -

  print_success "SSL certificates configured successfully"
}

# Function to setup log rotation
setup_log_rotation() {
  print_header "SETTING UP LOG ROTATION"

  print_status "Creating logrotate configuration..."

  cat >/etc/logrotate.d/protectshield <<EOF
$PROJECT_DIR/logs/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 644 www-data www-data
    postrotate
        systemctl reload nginx > /dev/null 2>&1 || true
    endscript
}
EOF

  print_success "Log rotation configured successfully"
}

# Function to run health checks
run_health_checks() {
  print_header "RUNNING HEALTH CHECKS"

  local errors=0

  # Check if services are running
  print_status "Checking service status..."

  if service_running nginx; then
    print_success "✓ Nginx is running"
  else
    print_error "✗ Nginx is not running"
    ((errors++))
  fi

  if service_running php${PHP_VERSION}-fpm; then
    print_success "✓ PHP-FPM is running"
  else
    print_error "✗ PHP-FPM is not running"
    ((errors++))
  fi

  # Check if website is accessible
  print_status "Checking website accessibility..."

  if curl -s -o /dev/null -w "%{http_code}" "http://localhost" | grep -q "200\|301\|302"; then
    print_success "✓ Website is accessible via HTTP"
  else
    print_error "✗ Website is not accessible via HTTP"
    ((errors++))
  fi

  # Check SSL if certificates exist
  if [ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]; then
    if curl -s -o /dev/null -w "%{http_code}" "https://localhost" -k | grep -q "200"; then
      print_success "✓ Website is accessible via HTTPS"
    else
      print_error "✗ Website is not accessible via HTTPS"
      ((errors++))
    fi
  fi

  # Check PHP functionality
  print_status "Checking PHP functionality..."

  if php -v >/dev/null 2>&1; then
    print_success "✓ PHP is working"
  else
    print_error "✗ PHP is not working"
    ((errors++))
  fi

  # Check file permissions
  print_status "Checking file permissions..."

  if [ -r "$PROJECT_DIR/index.php" ] && [ -w "$PROJECT_DIR/logs" ]; then
    print_success "✓ File permissions are correct"
  else
    print_error "✗ File permissions are incorrect"
    ((errors++))
  fi

  # Summary
  if [ $errors -eq 0 ]; then
    print_success "All health checks passed! 🎉"
    return 0
  else
    print_error "$errors health check(s) failed!"
    return 1
  fi
}

# Function to display deployment summary
show_summary() {
  print_header "DEPLOYMENT SUMMARY"

  echo -e "${GREEN}ProtectShield VPN has been deployed successfully!${NC}"
  echo ""
  echo -e "${BLUE}Domain:${NC} $DOMAIN"
  echo -e "${BLUE}Project Directory:${NC} $PROJECT_DIR"
  echo -e "${BLUE}Nginx Config:${NC} $NGINX_CONF"
  echo -e "${BLUE}PHP Version:${NC} $PHP_VERSION"
  echo -e "${BLUE}Log File:${NC} $LOG_FILE"
  echo ""
  echo -e "${YELLOW}URLs:${NC}"
  echo -e "  HTTP:  http://$DOMAIN"
  echo -e "  HTTPS: https://$DOMAIN"
  echo -e "  Logs:  https://$DOMAIN/logs.php?allow=1"
  echo ""
  echo -e "${YELLOW}Useful Commands:${NC}"
  echo -e "  Check Nginx status:    systemctl status nginx"
  echo -e "  Check PHP-FPM status:  systemctl status php${PHP_VERSION}-fpm"
  echo -e "  View Nginx logs:       tail -f /var/log/nginx/fastconnect_error.log"
  echo -e "  View deployment logs:  tail -f $LOG_FILE"
  echo -e "  Renew SSL manually:    certbot renew --nginx"
  echo ""
  echo -e "${GREEN}Deployment completed successfully! 🚀${NC}"
}

# Main deployment function
main() {
  print_header "VPN DEPLOYMENT SCRIPT"

  # Check if running as root
  if [ "$EUID" -ne 0 ]; then
    print_error "This script must be run as root"
    exit 1
  fi

  # Create log file
  touch "$LOG_FILE"
  chmod 644 "$LOG_FILE"

  print_status "Starting deployment for domain: $DOMAIN"
  print_status "Email for SSL certificates: $EMAIL"
  print_status "Deployment log: $LOG_FILE"

  # Run deployment steps
  update_system
  install_php
  install_nginx
  install_certbot
  deploy_project
  configure_nginx
  setup_ssl
  setup_log_rotation

  # Run health checks
  if run_health_checks; then
    show_summary
    exit 0
  else
    print_error "Deployment completed with errors. Check the logs for details."
    exit 1
  fi
}

# Show usage if help is requested
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
  echo "ProtectShield VPN Deployment Script"
  echo ""
  echo "Usage: $0 [domain] [email]"
  echo ""
  echo "Arguments:"
  echo "  domain    Domain name for the website (default: protectshield.net)"
  echo "  email     Email address for SSL certificates (default: admin@domain)"
  echo ""
  echo "Examples:"
  echo "  $0"
  echo "  $0 example.com admin@example.com"
  echo ""
  echo "This script will:"
  echo "  - Update the system and install required packages"
  echo "  - Install and configure PHP 8.3-FPM"
  echo "  - Install and configure Nginx"
  echo "  - Deploy the ProtectShield VPN project files"
  echo "  - Setup SSL certificates with Let's Encrypt"
  echo "  - Configure firewall rules"
  echo "  - Setup log rotation"
  echo "  - Run comprehensive health checks"
  exit 0
fi

# Run main function
main "$@"

