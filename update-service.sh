#!/bin/bash

# FastConnect Service Update Script
# This script deploys the FastConnect landing page from current directory

set -e

# Configuration
PROJECT_DIR="/var/www/fastconnect"
NGINX_CONFIG="/etc/nginx/sites-available/fastconnect"
PHP_FPM_SERVICE="php8.3-fpm"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   error "This script must be run as root"
   exit 1
fi

# Function to check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    local missing_deps=()
    
    # Check if nginx is installed
    if ! command -v nginx &> /dev/null; then
        missing_deps+=("nginx")
    fi
    
    # Check if PHP is installed
    if ! command -v php &> /dev/null; then
        missing_deps+=("php")
    else
        # Check if required PHP extensions are available
        local required_extensions=("curl" "mbstring" "openssl" "json" "filter")
        local missing_extensions=()
        
        for ext in "${required_extensions[@]}"; do
            if ! php -m | grep -q "$ext"; then
                missing_extensions+=("$ext")
            fi
        done
        
        if [[ ${#missing_extensions[@]} -gt 0 ]]; then
            missing_deps+=("php-extensions")
            warning "Missing PHP extensions: ${missing_extensions[*]}"
        fi
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        error "Missing dependencies: ${missing_deps[*]}"
        info "Run './install-dependencies.sh' to install missing dependencies"
        exit 1
    fi
    
    log "Prerequisites check passed"
}

# Function to stop services
stop_services() {
    log "Stopping services..."
    
    # Stop nginx
    systemctl stop nginx
    log "Nginx stopped"
    
    # Stop PHP-FPM
    systemctl stop "$PHP_FPM_SERVICE"
    log "PHP-FPM stopped"
}

# Function to start services
start_services() {
    log "Starting services..."
    
    # Start PHP-FPM
    systemctl start "$PHP_FPM_SERVICE"
    log "PHP-FPM started"
    
    # Start nginx
    systemctl start nginx
    log "Nginx started"
}

# Function to reload services
reload_services() {
    log "Reloading services..."
    
    # Test nginx configuration
    if nginx -t; then
        systemctl reload nginx
        log "Nginx reloaded"
    else
        error "Nginx configuration test failed"
        return 1
    fi
    
    # Reload PHP-FPM
    systemctl reload "$PHP_FPM_SERVICE"
    log "PHP-FPM reloaded"
}

# Function to deploy from current directory
deploy_from_current() {
    local current_dir="$(pwd)"
    
    log "Deploying from current directory: $current_dir"
    
    # Verify we have the required files
    if [[ ! -f "index.php" ]]; then
        error "index.php not found in current directory. Are you in the correct project directory?"
        exit 1
    fi
    
    # Copy files to project directory
    rsync -av --exclude='.git' --exclude='logs' "$current_dir/" "$PROJECT_DIR/"
    
    # Set proper permissions
    chown -R www-data:www-data "$PROJECT_DIR"
    chmod -R 755 "$PROJECT_DIR"
    chmod -R 644 "$PROJECT_DIR"/*.php
    
    # Create logs directory if it doesn't exist
    mkdir -p "$PROJECT_DIR/logs"
    chown www-data:www-data "$PROJECT_DIR/logs"
    chmod 755 "$PROJECT_DIR/logs"
    
    log "Deployment completed successfully"
}

# Function to update nginx configuration
update_nginx_config() {
    log "Updating nginx configuration..."
    
    # Copy nginx config if it exists in the project
    if [[ -f "$PROJECT_DIR/nginx.conf" ]]; then
        cp "$PROJECT_DIR/nginx.conf" "$NGINX_CONFIG"
        log "Nginx configuration updated from project files"
        
        # Enable the site
        if [[ ! -L "/etc/nginx/sites-enabled/fastconnect" ]]; then
            ln -s "$NGINX_CONFIG" /etc/nginx/sites-enabled/
            log "FastConnect site enabled"
        fi
        
        # Remove default nginx site if it exists
        if [[ -L "/etc/nginx/sites-enabled/default" ]]; then
            rm /etc/nginx/sites-enabled/default
            log "Default nginx site disabled"
        fi
    else
        warning "No nginx configuration found in project"
        return 1
    fi
    
    # Test nginx configuration
    if ! nginx -t; then
        error "Nginx configuration test failed"
        return 1
    fi
    
    log "Nginx configuration updated successfully"
}

# Function to show deployment status
show_status() {
    log "Deployment Status:"
    echo "===================="
    
    # Service status
    echo "Nginx Status: $(systemctl is-active nginx)"
    echo "PHP-FPM Status: $(systemctl is-active $PHP_FPM_SERVICE)"
    
    # File permissions
    echo "Project Directory Owner: $(stat -c '%U:%G' $PROJECT_DIR)"
    echo "Project Directory Permissions: $(stat -c '%a' $PROJECT_DIR)"
    
    # Check if main files exist
    echo "Main Files:"
    for file in "index.php" "nginx.conf"; do
        if [[ -f "$PROJECT_DIR/$file" ]]; then
            echo "  ✓ $file exists"
        else
            echo "  ✗ $file missing"
        fi
    done
    
    echo "===================="
}

# Main deployment function
deploy() {
    log "Starting FastConnect service deployment..."
    
    check_prerequisites
    deploy_from_current
    update_nginx_config
    reload_services
    
    log "Deployment completed successfully!"
    show_status
}

# Help function
show_help() {
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "FastConnect Service Deployment Script"
    echo ""
    echo "Commands:"
    echo "  deploy              Deploy the service from current directory"
    echo "  status              Show deployment status"
    echo ""
    echo "Examples:"
    echo "  $0 deploy           # Deploy from current directory"
    echo "  $0 status           # Show current status"
    echo ""
    echo "Other available scripts:"
    echo "  ./install-dependencies.sh   # Install required dependencies"
    echo "  ./healthcheck.sh            # Run health checks"
    echo "  ./revert-changes.sh         # Revert deployment"
    echo ""
    echo "Note: This script must be run from the FastConnect project directory"
    echo "      and will deploy files from the current directory to $PROJECT_DIR"
}

# Main execution
case "${1:-deploy}" in
    "deploy")
        deploy
        ;;
    "status")
        show_status
        ;;
    "-h"|"--help"|"help")
        show_help
        ;;
    *)
        error "Unknown command: $1"
        show_help
        exit 1
        ;;
esac 