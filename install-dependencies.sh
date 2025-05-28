#!/bin/bash

# FastConnect Dependencies Installation Script
# This script installs required dependencies (nginx, php, git) on Ubuntu systems

set -e

# Configuration
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

# Function to update package lists
update_package_lists() {
    log "Updating package lists..."
    apt-get update -y
    log "Package lists updated"
}

# Function to install git
install_git() {
    log "Installing Git..."
    apt-get install -y git
    
    if command -v git &> /dev/null; then
        log "Git installed successfully: $(git --version)"
    else
        error "Failed to install Git"
        exit 1
    fi
}

# Function to install nginx
install_nginx() {
    log "Installing Nginx..."
    apt-get install -y nginx
    
    if command -v nginx &> /dev/null; then
        log "Nginx installed successfully: $(nginx -v 2>&1)"
        
        # Enable nginx service
        systemctl enable nginx
        log "Nginx enabled"
        
        # Don't start nginx yet - it will be configured and started during deployment
        log "Nginx installation completed (will be configured and started during deployment)"
    else
        error "Failed to install Nginx"
        exit 1
    fi
}

# Function to install PHP and required extensions
install_php() {
    log "Installing PHP and required extensions..."
    
    # Install basic dependencies first
    log "Installing basic dependencies..."
    apt-get install -y software-properties-common apt-transport-https lsb-release ca-certificates wget curl gnupg unzip
    
    # Add PHP repository if not already added
    log "Adding PHP repository..."
    if ! grep -q "ondrej/php" /etc/apt/sources.list.d/* 2>/dev/null; then
        LC_ALL=C.UTF-8 add-apt-repository ppa:ondrej/php -y
        apt-get update
        log "PHP repository added and package lists updated"
    else
        log "PHP repository already exists"
    fi
    
    # Install PHP 8.3 and required extensions
    log "Installing PHP 8.3 and extensions..."
    apt-get install -y php8.3-fpm php8.3-curl php8.3-mbstring php8.3-xml php8.3-cli php8.3-zip php8.3-gd
    
    if command -v php &> /dev/null; then
        log "PHP installed successfully: $(php -v | head -n1)"
        
        # Enable and start PHP-FPM
        systemctl enable "$PHP_FPM_SERVICE"
        systemctl start "$PHP_FPM_SERVICE"
        log "PHP-FPM enabled and started"
        
        # Verify required extensions
        local missing_extensions=()
        for ext in curl mbstring openssl json filter xml zip gd; do
            if ! php -m | grep -q "$ext"; then
                missing_extensions+=("$ext")
            fi
        done
        
        if [[ ${#missing_extensions[@]} -gt 0 ]]; then
            warning "Some PHP extensions are still missing: ${missing_extensions[*]}"
            warning "You may need to install them manually"
        else
            log "All required PHP extensions are available"
        fi
    else
        error "Failed to install PHP"
        exit 1
    fi
}

# Function to install all dependencies
install_all() {
    log "Installing all required dependencies for FastConnect..."
    
    # Update package lists first
    update_package_lists
    
    # Install dependencies in order
    if ! command -v git &> /dev/null; then
        install_git
    else
        log "Git is already installed: $(git --version)"
    fi
    
    if ! command -v nginx &> /dev/null; then
        install_nginx
    else
        log "Nginx is already installed: $(nginx -v 2>&1)"
    fi
    
    if ! command -v php &> /dev/null; then
        install_php
    else
        log "PHP is already installed: $(php -v | head -n1)"
        
        # Check if PHP-FPM service exists and is enabled
        if ! systemctl is-enabled --quiet "$PHP_FPM_SERVICE" 2>/dev/null; then
            warning "PHP-FPM service is not enabled, enabling it..."
            systemctl enable "$PHP_FPM_SERVICE"
        fi
        
        if ! systemctl is-active --quiet "$PHP_FPM_SERVICE"; then
            warning "PHP-FPM service is not running, starting it..."
            systemctl start "$PHP_FPM_SERVICE"
        fi
    fi
    
    log "All dependencies installed successfully!"
    info "Run './update-service.sh deploy' to deploy the FastConnect service"
}

# Function to check what's installed
check_status() {
    log "Checking installation status..."
    echo "================================"
    
    # Check Git
    if command -v git &> /dev/null; then
        echo "✓ Git: $(git --version)"
    else
        echo "✗ Git: Not installed"
    fi
    
    # Check Nginx
    if command -v nginx &> /dev/null; then
        echo "✓ Nginx: $(nginx -v 2>&1)"
        echo "  Status: $(systemctl is-active nginx 2>/dev/null || echo "inactive")"
        echo "  Enabled: $(systemctl is-enabled nginx 2>/dev/null || echo "disabled")"
    else
        echo "✗ Nginx: Not installed"
    fi
    
    # Check PHP
    if command -v php &> /dev/null; then
        echo "✓ PHP: $(php -v | head -n1)"
        echo "  FPM Status: $(systemctl is-active $PHP_FPM_SERVICE 2>/dev/null || echo "inactive")"
        echo "  FPM Enabled: $(systemctl is-enabled $PHP_FPM_SERVICE 2>/dev/null || echo "disabled")"
        
        # Check extensions
        local required_extensions=("curl" "mbstring" "openssl" "json" "filter" "xml" "zip" "gd")
        local missing_extensions=()
        
        for ext in "${required_extensions[@]}"; do
            if ! php -m | grep -q "$ext"; then
                missing_extensions+=("$ext")
            fi
        done
        
        if [[ ${#missing_extensions[@]} -eq 0 ]]; then
            echo "  Extensions: All required extensions available"
        else
            echo "  Extensions: Missing ${missing_extensions[*]}"
        fi
    else
        echo "✗ PHP: Not installed"
    fi
    
    echo "================================"
}

# Help function
show_help() {
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "FastConnect Dependencies Installation Script"
    echo ""
    echo "Commands:"
    echo "  install     Install all dependencies (git, nginx, php)"
    echo "  git         Install Git only"
    echo "  nginx       Install Nginx only"
    echo "  php         Install PHP and extensions only"
    echo "  status      Check installation status"
    echo ""
    echo "Examples:"
    echo "  $0 install  # Install all dependencies"
    echo "  $0 status   # Check what's installed"
    echo "  $0 nginx    # Install only Nginx"
}

# Main execution
case "${1:-install}" in
    "install")
        install_all
        ;;
    "git")
        update_package_lists
        install_git
        ;;
    "nginx")
        update_package_lists
        install_nginx
        ;;
    "php")
        update_package_lists
        install_php
        ;;
    "status")
        check_status
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