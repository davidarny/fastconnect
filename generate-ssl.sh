#!/bin/bash

# FastConnect SSL Certificate Generation Script
# This script generates SSL certificates using Let's Encrypt

set -e

# Configuration
DOMAIN="fastconnectvpn.net"
EMAIL="admin@fastconnectvpn.net"
WEBROOT="/var/www/fastconnect"
NGINX_CONFIG="/etc/nginx/sites-available/fastconnect"
SSL_DIR="/etc/ssl"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
}

warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   error "This script must be run as root"
   exit 1
fi

# Function to install certbot if not present
install_certbot() {
    log "Checking if certbot is installed..."
    
    if ! command -v certbot &> /dev/null; then
        log "Installing certbot..."
        
        # Detect OS and install accordingly
        if [[ -f /etc/debian_version ]]; then
            apt-get update
            apt-get install -y certbot python3-certbot-nginx
        elif [[ -f /etc/redhat-release ]]; then
            yum install -y epel-release
            yum install -y certbot python3-certbot-nginx
        else
            error "Unsupported operating system"
            exit 1
        fi
    else
        log "Certbot is already installed"
    fi
}

# Function to backup existing certificates
backup_existing_certs() {
    if [[ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]]; then
        log "Backing up existing certificates..."
        mkdir -p /root/ssl-backup/$(date +%Y%m%d_%H%M%S)
        cp -r /etc/letsencrypt/live/$DOMAIN /root/ssl-backup/$(date +%Y%m%d_%H%M%S)/
        log "Certificates backed up to /root/ssl-backup/"
    fi
}

# Function to create temporary nginx config for certificate generation
create_temp_nginx_config() {
    log "Creating temporary nginx configuration..."
    
    cat > /etc/nginx/sites-available/fastconnect-temp << EOF
server {
    listen 80;
    server_name $DOMAIN www.$DOMAIN;
    
    root $WEBROOT;
    index index.php index.html;
    
    location /.well-known/acme-challenge/ {
        root $WEBROOT;
        try_files \$uri =404;
    }
    
    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }
    
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.3-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }
}
EOF

    # Enable temporary config
    ln -sf /etc/nginx/sites-available/fastconnect-temp /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/fastconnect
    
    # Test and reload nginx
    nginx -t && systemctl reload nginx
}

# Function to generate SSL certificate
generate_certificate() {
    log "Generating SSL certificate for $DOMAIN..."
    
    # Create webroot directory if it doesn't exist
    mkdir -p $WEBROOT
    
    # Generate certificate
    certbot certonly \
        --webroot \
        --webroot-path=$WEBROOT \
        --email $EMAIL \
        --agree-tos \
        --no-eff-email \
        --domains $DOMAIN,www.$DOMAIN \
        --non-interactive \
        --expand
    
    if [[ $? -eq 0 ]]; then
        log "SSL certificate generated successfully!"
    else
        error "Failed to generate SSL certificate"
        exit 1
    fi
}

# Function to create SSL certificate symlinks
create_ssl_symlinks() {
    log "Creating SSL certificate symlinks..."
    
    mkdir -p $SSL_DIR/certs
    mkdir -p $SSL_DIR/private
    
    # Create symlinks
    ln -sf /etc/letsencrypt/live/$DOMAIN/fullchain.pem $SSL_DIR/certs/fastconnect.crt
    ln -sf /etc/letsencrypt/live/$DOMAIN/privkey.pem $SSL_DIR/private/fastconnect.key
    
    # Set proper permissions
    chmod 644 $SSL_DIR/certs/fastconnect.crt
    chmod 600 $SSL_DIR/private/fastconnect.key
    
    log "SSL symlinks created successfully"
}

# Function to enable production nginx config
enable_production_config() {
    log "Enabling production nginx configuration..."
    
    # Remove temporary config
    rm -f /etc/nginx/sites-enabled/fastconnect-temp
    
    # Enable production config
    ln -sf /etc/nginx/sites-available/fastconnect /etc/nginx/sites-enabled/
    
    # Test and reload nginx
    nginx -t && systemctl reload nginx
    
    log "Production nginx configuration enabled"
}

# Function to setup auto-renewal
setup_auto_renewal() {
    log "Setting up automatic certificate renewal..."
    
    # Create renewal script
    cat > /usr/local/bin/renew-fastconnect-ssl.sh << 'EOF'
#!/bin/bash

# FastConnect SSL Renewal Script
certbot renew --quiet --no-self-upgrade

# Reload nginx if certificates were renewed
if [[ $? -eq 0 ]]; then
    systemctl reload nginx
fi
EOF

    chmod +x /usr/local/bin/renew-fastconnect-ssl.sh
    
    # Add cron job for automatic renewal (runs twice daily)
    (crontab -l 2>/dev/null; echo "0 */12 * * * /usr/local/bin/renew-fastconnect-ssl.sh") | crontab -
    
    log "Auto-renewal setup complete"
}

# Function to test SSL configuration
test_ssl() {
    log "Testing SSL configuration..."
    
    # Test SSL certificate
    if openssl x509 -in /etc/letsencrypt/live/$DOMAIN/fullchain.pem -text -noout > /dev/null 2>&1; then
        log "SSL certificate is valid"
    else
        error "SSL certificate validation failed"
        exit 1
    fi
    
    # Test nginx configuration
    if nginx -t > /dev/null 2>&1; then
        log "Nginx configuration is valid"
    else
        error "Nginx configuration test failed"
        exit 1
    fi
    
    log "SSL configuration test completed successfully"
}

# Main execution
main() {
    log "Starting SSL certificate generation for FastConnect..."
    
    # Check if domain is provided as argument
    if [[ $# -eq 1 ]]; then
        DOMAIN=$1
        log "Using domain: $DOMAIN"
    fi
    
    # Check if email is provided as second argument
    if [[ $# -eq 2 ]]; then
        EMAIL=$2
        log "Using email: $EMAIL"
    fi
    
    install_certbot
    backup_existing_certs
    create_temp_nginx_config
    generate_certificate
    create_ssl_symlinks
    enable_production_config
    setup_auto_renewal
    test_ssl
    
    log "SSL certificate generation completed successfully!"
    log "Certificate location: /etc/letsencrypt/live/$DOMAIN/"
    log "Certificate will auto-renew every 12 hours"
    
    # Display certificate information
    log "Certificate information:"
    certbot certificates
}

# Help function
show_help() {
    echo "Usage: $0 [domain] [email]"
    echo ""
    echo "Generate SSL certificates for FastConnect landing page"
    echo ""
    echo "Arguments:"
    echo "  domain    Domain name (default: fastconnectvpn.net)"
    echo "  email     Email for Let's Encrypt (default: admin@fastconnectvpn.net)"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Use default domain and email"
    echo "  $0 mysite.com                        # Use custom domain"
    echo "  $0 mysite.com admin@mysite.com       # Use custom domain and email"
}

# Check for help flag
if [[ $1 == "-h" ]] || [[ $1 == "--help" ]]; then
    show_help
    exit 0
fi

# Run main function
main "$@" 