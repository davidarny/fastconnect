#!/bin/bash

# FastConnect Revert Changes Script
# This script reverts all changes made by the deployment and SSL scripts

set -e

# Configuration
PROJECT_DIR="/var/www/fastconnect"
BACKUP_DIR="/var/backups/fastconnect"
NGINX_CONFIG="/etc/nginx/sites-available/fastconnect"
NGINX_TEMP_CONFIG="/etc/nginx/sites-available/fastconnect-temp"
SSL_DIR="/etc/ssl"
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

# Function to create emergency backup before reverting
create_emergency_backup() {
    local emergency_backup_dir="/var/backups/fastconnect-emergency/$(date +%Y%m%d_%H%M%S)"
    
    log "Creating emergency backup before reverting..."
    mkdir -p "$emergency_backup_dir"
    
    # Backup current state
    if [[ -d "$PROJECT_DIR" ]]; then
        cp -r "$PROJECT_DIR" "$emergency_backup_dir/project"
    fi
    
    if [[ -f "$NGINX_CONFIG" ]]; then
        cp "$NGINX_CONFIG" "$emergency_backup_dir/nginx.conf"
    fi
    
    # Backup SSL certificates
    if [[ -d "/etc/letsencrypt" ]]; then
        cp -r "/etc/letsencrypt" "$emergency_backup_dir/letsencrypt"
    fi
    
    log "Emergency backup created at: $emergency_backup_dir"
    echo "$emergency_backup_dir" > /tmp/fastconnect_emergency_backup
}

# Function to stop all services
stop_services() {
    log "Stopping services..."
    
    # Stop nginx
    if systemctl is-active --quiet nginx; then
        systemctl stop nginx
        log "Nginx stopped"
    fi
    
    # Stop PHP-FPM
    if systemctl is-active --quiet "$PHP_FPM_SERVICE"; then
        systemctl stop "$PHP_FPM_SERVICE"
        log "PHP-FPM stopped"
    fi
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

# Function to remove SSL certificates
remove_ssl_certificates() {
    log "Removing SSL certificates..."
    
    # Remove Let's Encrypt certificates
    if command -v certbot &> /dev/null; then
        local domains=$(certbot certificates 2>/dev/null | grep "Certificate Name:" | awk '{print $3}' | grep -E "(fastconnect|fastconnectvpn)" || true)
        
        for domain in $domains; do
            if [[ -n "$domain" ]]; then
                log "Removing certificate for domain: $domain"
                certbot delete --cert-name "$domain" --non-interactive
            fi
        done
    fi
    
    # Remove SSL symlinks
    if [[ -L "$SSL_DIR/certs/fastconnect.crt" ]]; then
        rm -f "$SSL_DIR/certs/fastconnect.crt"
        log "Removed SSL certificate symlink"
    fi
    
    if [[ -L "$SSL_DIR/private/fastconnect.key" ]]; then
        rm -f "$SSL_DIR/private/fastconnect.key"
        log "Removed SSL private key symlink"
    fi
    
    # Remove auto-renewal script
    if [[ -f "/usr/local/bin/renew-fastconnect-ssl.sh" ]]; then
        rm -f "/usr/local/bin/renew-fastconnect-ssl.sh"
        log "Removed SSL renewal script"
    fi
    
    # Remove cron job
    (crontab -l 2>/dev/null | grep -v "renew-fastconnect-ssl.sh") | crontab -
    log "Removed SSL renewal cron job"
}

# Function to remove nginx configuration
remove_nginx_config() {
    log "Removing nginx configuration..."
    
    # Remove nginx config files
    if [[ -f "$NGINX_CONFIG" ]]; then
        rm -f "$NGINX_CONFIG"
        log "Removed nginx configuration file"
    fi
    
    if [[ -f "$NGINX_TEMP_CONFIG" ]]; then
        rm -f "$NGINX_TEMP_CONFIG"
        log "Removed temporary nginx configuration file"
    fi
    
    # Remove symlinks
    if [[ -L "/etc/nginx/sites-enabled/fastconnect" ]]; then
        rm -f "/etc/nginx/sites-enabled/fastconnect"
        log "Removed nginx configuration symlink"
    fi
    
    if [[ -L "/etc/nginx/sites-enabled/fastconnect-temp" ]]; then
        rm -f "/etc/nginx/sites-enabled/fastconnect-temp"
        log "Removed temporary nginx configuration symlink"
    fi
}

# Function to remove project files
remove_project_files() {
    log "Removing project files..."
    
    if [[ -d "$PROJECT_DIR" ]]; then
        rm -rf "$PROJECT_DIR"
        log "Removed project directory: $PROJECT_DIR"
    fi
}

# Function to remove backup files
remove_backup_files() {
    local keep_emergency_backup="$1"
    
    log "Removing backup files..."
    
    # Remove regular backups
    if [[ -d "$BACKUP_DIR" ]]; then
        rm -rf "$BACKUP_DIR"
        log "Removed backup directory: $BACKUP_DIR"
    fi
    
    # Remove emergency backups (unless specified to keep)
    if [[ "$keep_emergency_backup" != "keep" ]] && [[ -d "/var/backups/fastconnect-emergency" ]]; then
        rm -rf "/var/backups/fastconnect-emergency"
        log "Removed emergency backup directory"
    fi
    
    # Remove temporary files
    rm -f /tmp/fastconnect_last_backup
    rm -f /tmp/fastconnect_emergency_backup
    log "Removed temporary backup references"
}

# Function to remove scripts
remove_scripts() {
    log "Removing deployment scripts..."
    
    local script_dir=$(dirname "$(readlink -f "$0")")
    
    # List of scripts to remove
    local scripts=(
        "generate-ssl.sh"
        "update-service.sh"
        "revert-changes.sh"
        "nginx.conf"
    )
    
    for script in "${scripts[@]}"; do
        local script_path="$script_dir/$script"
        if [[ -f "$script_path" ]] && [[ "$script_path" != "$0" ]]; then
            rm -f "$script_path"
            log "Removed script: $script"
        fi
    done
    
    # Remove this script last (if requested)
    if [[ "$1" == "remove-self" ]]; then
        log "Removing revert script itself..."
        rm -f "$0"
    fi
}

# Function to restore default nginx configuration
restore_default_nginx() {
    log "Restoring default nginx configuration..."
    
    # Create a basic default nginx configuration
    cat > /etc/nginx/sites-available/default << 'EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    root /var/www/html;
    index index.html index.htm index.nginx-debian.html;

    server_name _;

    location / {
        try_files $uri $uri/ =404;
    }
}
EOF

    # Enable default configuration
    ln -sf /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default
    
    log "Default nginx configuration restored"
}

# Function to clean up logs
clean_logs() {
    log "Cleaning up logs..."
    
    # Remove nginx logs
    rm -f /var/log/nginx/fastconnect_access.log*
    rm -f /var/log/nginx/fastconnect_error.log*
    
    # Remove application logs
    if [[ -d "$PROJECT_DIR/logs" ]]; then
        rm -rf "$PROJECT_DIR/logs"
    fi
    
    log "Logs cleaned up"
}

# Function to verify revert
verify_revert() {
    log "Verifying revert process..."
    
    local issues=0
    
    # Check if project directory is removed
    if [[ -d "$PROJECT_DIR" ]]; then
        warning "Project directory still exists: $PROJECT_DIR"
        ((issues++))
    fi
    
    # Check if nginx config is removed
    if [[ -f "$NGINX_CONFIG" ]]; then
        warning "Nginx configuration still exists: $NGINX_CONFIG"
        ((issues++))
    fi
    
    # Check if SSL certificates are removed
    if [[ -f "$SSL_DIR/certs/fastconnect.crt" ]]; then
        warning "SSL certificate still exists"
        ((issues++))
    fi
    
    # Check if services are running
    if ! systemctl is-active --quiet nginx; then
        warning "Nginx is not running"
        ((issues++))
    fi
    
    if ! systemctl is-active --quiet "$PHP_FPM_SERVICE"; then
        warning "PHP-FPM is not running"
        ((issues++))
    fi
    
    if [[ $issues -eq 0 ]]; then
        log "Revert verification completed successfully"
        return 0
    else
        warning "Revert verification found $issues issues"
        return 1
    fi
}

# Function to show revert status
show_revert_status() {
    log "Revert Status Report:"
    echo "====================="
    
    echo "Project Directory: $([ -d "$PROJECT_DIR" ] && echo "EXISTS" || echo "REMOVED")"
    echo "Nginx Config: $([ -f "$NGINX_CONFIG" ] && echo "EXISTS" || echo "REMOVED")"
    echo "SSL Certificates: $([ -f "$SSL_DIR/certs/fastconnect.crt" ] && echo "EXISTS" || echo "REMOVED")"
    echo "Backup Directory: $([ -d "$BACKUP_DIR" ] && echo "EXISTS" || echo "REMOVED")"
    echo "Nginx Status: $(systemctl is-active nginx 2>/dev/null || echo "INACTIVE")"
    echo "PHP-FPM Status: $(systemctl is-active $PHP_FPM_SERVICE 2>/dev/null || echo "INACTIVE")"
    
    if [[ -f "/tmp/fastconnect_emergency_backup" ]]; then
        echo "Emergency Backup: $(cat /tmp/fastconnect_emergency_backup)"
    fi
    
    echo "====================="
}

# Function for partial revert (selective removal)
partial_revert() {
    local components="$1"
    
    log "Performing partial revert for: $components"
    
    IFS=',' read -ra ADDR <<< "$components"
    for component in "${ADDR[@]}"; do
        case "$component" in
            "ssl")
                remove_ssl_certificates
                ;;
            "nginx")
                stop_services
                remove_nginx_config
                restore_default_nginx
                start_services
                ;;
            "project")
                remove_project_files
                ;;
            "backups")
                remove_backup_files
                ;;
            "scripts")
                remove_scripts
                ;;
            *)
                warning "Unknown component: $component"
                ;;
        esac
    done
}

# Function for complete revert
complete_revert() {
    local remove_self="$1"
    
    log "Starting complete revert of FastConnect deployment..."
    
    create_emergency_backup
    stop_services
    remove_ssl_certificates
    remove_nginx_config
    remove_project_files
    clean_logs
    restore_default_nginx
    
    # Test nginx configuration
    if nginx -t; then
        start_services
    else
        error "Nginx configuration test failed, manual intervention required"
        exit 1
    fi
    
    remove_backup_files
    
    if verify_revert; then
        log "Complete revert completed successfully!"
    else
        warning "Revert completed with some issues, check the status above"
    fi
    
    show_revert_status
    
    # Remove scripts last
    if [[ "$remove_self" == "remove-scripts" ]]; then
        remove_scripts "remove-self"
    else
        remove_scripts
    fi
}

# Help function
show_help() {
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo "FastConnect Revert Changes Script"
    echo ""
    echo "Commands:"
    echo "  complete [remove-scripts]   Complete revert of all changes"
    echo "  partial <components>        Partial revert of specific components"
    echo "  status                      Show current revert status"
    echo "  verify                      Verify if revert was successful"
    echo ""
    echo "Components for partial revert:"
    echo "  ssl                         Remove SSL certificates only"
    echo "  nginx                       Remove nginx configuration only"
    echo "  project                     Remove project files only"
    echo "  backups                     Remove backup files only"
    echo "  scripts                     Remove deployment scripts only"
    echo ""
    echo "Options:"
    echo "  remove-scripts              Also remove all deployment scripts"
    echo ""
    echo "Examples:"
    echo "  $0 complete                 # Complete revert, keep scripts"
    echo "  $0 complete remove-scripts  # Complete revert, remove scripts"
    echo "  $0 partial ssl,nginx        # Remove only SSL and nginx config"
    echo "  $0 status                   # Show current status"
    echo "  $0 verify                   # Verify revert was successful"
}

# Confirmation function
confirm_revert() {
    local action="$1"
    
    echo ""
    warning "This will $action FastConnect deployment!"
    warning "This action cannot be undone (except from emergency backup)."
    echo ""
    read -p "Are you sure you want to continue? (yes/no): " -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        log "Revert cancelled by user"
        exit 0
    fi
}

# Main execution
case "${1:-help}" in
    "complete")
        confirm_revert "completely revert"
        complete_revert "$2"
        ;;
    "partial")
        if [[ -z "$2" ]]; then
            error "Components must be specified for partial revert"
            show_help
            exit 1
        fi
        confirm_revert "partially revert ($2)"
        partial_revert "$2"
        ;;
    "status")
        show_revert_status
        ;;
    "verify")
        verify_revert
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