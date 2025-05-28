#!/bin/bash

# FastConnect Service Update Script
# This script updates the FastConnect landing page with backup and rollback capabilities

set -e

# Configuration
PROJECT_DIR="/var/www/fastconnect-landing"
BACKUP_DIR="/var/backups/fastconnect"
REPO_URL="https://github.com/your-username/fastconnect-landing.git"
BRANCH="main"
SERVICE_NAME="fastconnect"
NGINX_CONFIG="/etc/nginx/sites-available/fastconnect"
PHP_FPM_SERVICE="php8.1-fpm"

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

# Function to create backup
create_backup() {
    local backup_timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_path="$BACKUP_DIR/$backup_timestamp"
    
    log "Creating backup at $backup_path..."
    
    # Create backup directory
    mkdir -p "$backup_path"
    
    # Backup current files
    if [[ -d "$PROJECT_DIR" ]]; then
        cp -r "$PROJECT_DIR" "$backup_path/files"
        log "Files backed up successfully"
    else
        warning "Project directory does not exist, skipping file backup"
    fi
    
    # Backup nginx configuration
    if [[ -f "$NGINX_CONFIG" ]]; then
        cp "$NGINX_CONFIG" "$backup_path/nginx.conf"
        log "Nginx configuration backed up"
    fi
    
    # Backup database if exists (for future use)
    # mysqldump -u root -p fastconnect > "$backup_path/database.sql"
    
    # Create backup metadata
    cat > "$backup_path/metadata.json" << EOF
{
    "timestamp": "$backup_timestamp",
    "project_dir": "$PROJECT_DIR",
    "nginx_config": "$NGINX_CONFIG",
    "git_commit": "$(cd $PROJECT_DIR 2>/dev/null && git rev-parse HEAD 2>/dev/null || echo 'unknown')",
    "git_branch": "$(cd $PROJECT_DIR 2>/dev/null && git branch --show-current 2>/dev/null || echo 'unknown')",
    "php_version": "$(php -v | head -n1)",
    "nginx_version": "$(nginx -v 2>&1)"
}
EOF
    
    # Keep only last 10 backups
    cd "$BACKUP_DIR"
    ls -t | tail -n +11 | xargs -r rm -rf
    
    log "Backup created successfully: $backup_path"
    echo "$backup_path" > /tmp/fastconnect_last_backup
}

# Function to check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check if git is installed
    if ! command -v git &> /dev/null; then
        error "Git is not installed"
        exit 1
    fi
    
    # Check if nginx is installed
    if ! command -v nginx &> /dev/null; then
        error "Nginx is not installed"
        exit 1
    fi
    
    # Check if PHP is installed
    if ! command -v php &> /dev/null; then
        error "PHP is not installed"
        exit 1
    fi
    
    # Check if required PHP extensions are available
    local required_extensions=("curl" "mbstring" "openssl" "json" "filter")
    for ext in "${required_extensions[@]}"; do
        if ! php -m | grep -q "$ext"; then
            error "Required PHP extension '$ext' is not installed"
            exit 1
        fi
    done
    
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

# Function to deploy from git
deploy_from_git() {
    log "Deploying from Git repository..."
    
    if [[ -d "$PROJECT_DIR/.git" ]]; then
        # Update existing repository
        cd "$PROJECT_DIR"
        git fetch origin
        git reset --hard "origin/$BRANCH"
        log "Repository updated from origin/$BRANCH"
    else
        # Clone repository
        rm -rf "$PROJECT_DIR"
        git clone -b "$BRANCH" "$REPO_URL" "$PROJECT_DIR"
        log "Repository cloned from $REPO_URL"
    fi
    
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

# Function to deploy from local files
deploy_from_local() {
    local source_dir="$1"
    
    if [[ ! -d "$source_dir" ]]; then
        error "Source directory '$source_dir' does not exist"
        exit 1
    fi
    
    log "Deploying from local directory: $source_dir"
    
    # Copy files
    rsync -av --delete "$source_dir/" "$PROJECT_DIR/"
    
    # Set proper permissions
    chown -R www-data:www-data "$PROJECT_DIR"
    chmod -R 755 "$PROJECT_DIR"
    chmod -R 644 "$PROJECT_DIR"/*.php
    
    # Create logs directory if it doesn't exist
    mkdir -p "$PROJECT_DIR/logs"
    chown www-data:www-data "$PROJECT_DIR/logs"
    chmod 755 "$PROJECT_DIR/logs"
    
    log "Local deployment completed successfully"
}

# Function to run health checks
run_health_checks() {
    log "Running comprehensive health checks..."
    
    # Check if our comprehensive health check script exists
    local health_script="$PROJECT_DIR/healthcheck.sh"
    if [[ -f "$health_script" ]]; then
        # Run the comprehensive health check script
        if "$health_script" --quiet; then
            log "Comprehensive health checks passed"
            return 0
        else
            local exit_code=$?
            if [[ $exit_code -eq 1 ]]; then
                warning "Health checks completed with warnings"
                # Continue deployment but log warnings
                "$health_script" --format text | grep -E "\[⚠\]|\[✗\]" || true
                return 0
            else
                error "Health checks failed"
                # Show failed checks
                "$health_script" --format text | grep -E "\[⚠\]|\[✗\]" || true
                return 1
            fi
        fi
    else
        # Fallback to basic health checks if comprehensive script not available
        warning "Comprehensive health check script not found, using basic checks"
        run_basic_health_checks
    fi
}

# Basic health checks (fallback)
run_basic_health_checks() {
    log "Running basic health checks..."
    
    # Check if nginx is running
    if ! systemctl is-active --quiet nginx; then
        error "Nginx is not running"
        return 1
    fi
    
    # Check if PHP-FPM is running
    if ! systemctl is-active --quiet "$PHP_FPM_SERVICE"; then
        error "PHP-FPM is not running"
        return 1
    fi
    
    # Check if website is accessible
    local response_code=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/ || echo "000")
    if [[ "$response_code" != "200" ]]; then
        warning "Website returned HTTP $response_code (expected 200)"
    else
        log "Website is accessible (HTTP 200)"
    fi
    
    # Check PHP syntax
    if find "$PROJECT_DIR" -name "*.php" -exec php -l {} \; 2>&1 | grep -q "Parse error"; then
        error "PHP syntax errors found"
        return 1
    else
        log "PHP syntax check passed"
    fi
    
    log "Basic health checks completed successfully"
}

# Function to update nginx configuration
update_nginx_config() {
    log "Updating nginx configuration..."
    
    # Copy nginx config if it exists in the project
    if [[ -f "$PROJECT_DIR/nginx.conf" ]]; then
        cp "$PROJECT_DIR/nginx.conf" "$NGINX_CONFIG"
        log "Nginx configuration updated from project files"
    else
        log "No nginx configuration found in project, keeping existing"
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
    
    # Git information
    if [[ -d "$PROJECT_DIR/.git" ]]; then
        cd "$PROJECT_DIR"
        echo "Git Commit: $(git rev-parse HEAD)"
        echo "Git Branch: $(git branch --show-current)"
        echo "Last Commit: $(git log -1 --pretty=format:'%h - %s (%cr) <%an>')"
    fi
    
    # Service status
    echo "Nginx Status: $(systemctl is-active nginx)"
    echo "PHP-FPM Status: $(systemctl is-active $PHP_FPM_SERVICE)"
    
    # File permissions
    echo "Project Directory Owner: $(stat -c '%U:%G' $PROJECT_DIR)"
    echo "Project Directory Permissions: $(stat -c '%a' $PROJECT_DIR)"
    
    # Last backup
    if [[ -f "/tmp/fastconnect_last_backup" ]]; then
        echo "Last Backup: $(cat /tmp/fastconnect_last_backup)"
    fi
    
    echo "===================="
}

# Function to rollback to previous version
rollback() {
    local backup_path="$1"
    
    if [[ -z "$backup_path" ]]; then
        # Use last backup
        if [[ -f "/tmp/fastconnect_last_backup" ]]; then
            backup_path=$(cat /tmp/fastconnect_last_backup)
        else
            error "No backup path specified and no last backup found"
            exit 1
        fi
    fi
    
    if [[ ! -d "$backup_path" ]]; then
        error "Backup directory '$backup_path' does not exist"
        exit 1
    fi
    
    log "Rolling back to backup: $backup_path"
    
    # Stop services
    stop_services
    
    # Restore files
    if [[ -d "$backup_path/files" ]]; then
        rm -rf "$PROJECT_DIR"
        cp -r "$backup_path/files" "$PROJECT_DIR"
        log "Files restored from backup"
    fi
    
    # Restore nginx configuration
    if [[ -f "$backup_path/nginx.conf" ]]; then
        cp "$backup_path/nginx.conf" "$NGINX_CONFIG"
        log "Nginx configuration restored from backup"
    fi
    
    # Start services
    start_services
    
    # Run health checks
    if run_health_checks; then
        log "Rollback completed successfully"
    else
        error "Rollback completed but health checks failed"
        exit 1
    fi
}

# Main deployment function
deploy() {
    local source="$1"
    
    log "Starting FastConnect service update..."
    
    check_prerequisites
    create_backup
    
    # Deploy based on source type
    if [[ "$source" == "git" ]] || [[ -z "$source" ]]; then
        deploy_from_git
    elif [[ -d "$source" ]]; then
        deploy_from_local "$source"
    else
        error "Invalid source: $source"
        exit 1
    fi
    
    update_nginx_config
    reload_services
    
    # Run health checks
    if run_health_checks; then
        log "Deployment completed successfully!"
        show_status
    else
        error "Health checks failed, consider rolling back"
        exit 1
    fi
}

# Function to run standalone health checks
run_standalone_health_checks() {
    local format="${1:-text}"
    local output_file="$2"
    
    # Check if our comprehensive health check script exists
    local health_script="$PROJECT_DIR/healthcheck.sh"
    if [[ -f "$health_script" ]]; then
        log "Running comprehensive health checks..."
        
        # Build command arguments
        local cmd_args=()
        if [[ "$format" != "text" ]]; then
            cmd_args+=("--format" "$format")
        fi
        if [[ -n "$output_file" ]]; then
            cmd_args+=("--output" "$output_file")
        fi
        
        # Run the comprehensive health check
        "$health_script" "${cmd_args[@]}"
        local exit_code=$?
        
        case $exit_code in
            0)
                log "All health checks passed"
                ;;
            1)
                warning "Health checks completed with warnings"
                ;;
            2)
                error "Health checks failed"
                ;;
            *)
                error "Health check script returned unexpected exit code: $exit_code"
                ;;
        esac
        
        return $exit_code
    else
        # Fallback to basic health checks
        warning "Comprehensive health check script not found at $health_script"
        log "Using basic health checks instead"
        run_basic_health_checks
        return $?
    fi
}

# Help function
show_help() {
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo "FastConnect Service Update Script"
    echo ""
    echo "Commands:"
    echo "  deploy [source]     Deploy the service (default: git)"
    echo "  rollback [backup]   Rollback to previous version"
    echo "  status              Show deployment status"
    echo "  backup              Create backup only"
    echo "  health [format] [output_file]  Run health checks"
    echo ""
    echo "Options:"
    echo "  source              'git' or path to local directory"
    echo "  backup              Path to backup directory"
    echo "  format              Health check output format: text, json (default: text)"
    echo "  output_file         Save health check output to file"
    echo ""
    echo "Examples:"
    echo "  $0 deploy                    # Deploy from git"
    echo "  $0 deploy /path/to/files     # Deploy from local directory"
    echo "  $0 rollback                  # Rollback to last backup"
    echo "  $0 rollback /var/backups/... # Rollback to specific backup"
    echo "  $0 status                    # Show current status"
    echo "  $0 health                    # Run health checks with text output"
    echo "  $0 health json               # Run health checks with JSON output"
    echo "  $0 health text health.log    # Save health check output to file"
}

# Main execution
case "${1:-deploy}" in
    "deploy")
        deploy "$2"
        ;;
    "rollback")
        rollback "$2"
        ;;
    "status")
        show_status
        ;;
    "backup")
        check_prerequisites
        create_backup
        ;;
    "health")
        run_standalone_health_checks "$2" "$3"
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