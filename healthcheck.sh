#!/bin/bash

# FastConnect VPN Health Check Script
# This script performs comprehensive health checks on the FastConnect VPN application
# and system components.

set -e

# Configuration
PROJECT_DIR="/var/www/fastconnect-landing"
LOG_DIR="$PROJECT_DIR/logs"
DOWNLOAD_FILE="$PROJECT_DIR/FastConnect_VPN.zip"
CLOAKING_API="https://cloakit.house/api/v1/check"
DOMAIN="https://fastconnectvpn.net"
PHP_FPM_SERVICE="php8.1-fpm"
TIMEOUT=10

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Health check results
TOTAL_CHECKS=0
PASSED_CHECKS=0
WARNING_CHECKS=0
FAILED_CHECKS=0
OVERALL_STATUS="healthy"

# Parse command line arguments
QUIET=false
FORMAT="text"
OUTPUT_FILE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --quiet|-q)
            QUIET=true
            shift
            ;;
        --format|-f)
            FORMAT="$2"
            shift 2
            ;;
        --output|-o)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --quiet, -q          Only return exit code (no output)"
            echo "  --format, -f FORMAT  Output format: text, json (default: text)"
            echo "  --output, -o FILE    Write output to file"
            echo "  --help, -h           Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                   # Run health checks with text output"
            echo "  $0 --quiet           # Silent mode, only exit code"
            echo "  $0 --format json     # JSON output"
            echo "  $0 -o health.log     # Save output to file"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Logging functions
log_pass() {
    local name="$1"
    local message="$2"
    local details="$3"
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
    
    if [[ "$QUIET" != "true" ]]; then
        echo -e "${GREEN}[✓] $name: $message${NC}"
        [[ -n "$details" ]] && echo -e "    ${BLUE}$details${NC}"
    fi
}

log_warn() {
    local name="$1"
    local message="$2"
    local details="$3"
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    WARNING_CHECKS=$((WARNING_CHECKS + 1))
    
    if [[ "$OVERALL_STATUS" == "healthy" ]]; then
        OVERALL_STATUS="warning"
    fi
    
    if [[ "$QUIET" != "true" ]]; then
        echo -e "${YELLOW}[⚠] $name: $message${NC}"
        [[ -n "$details" ]] && echo -e "    ${BLUE}$details${NC}"
    fi
}

log_fail() {
    local name="$1"
    local message="$2"
    local details="$3"
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
    OVERALL_STATUS="unhealthy"
    
    if [[ "$QUIET" != "true" ]]; then
        echo -e "${RED}[✗] $name: $message${NC}"
        [[ -n "$details" ]] && echo -e "    ${BLUE}$details${NC}"
    fi
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check system services
check_services() {
    if [[ "$QUIET" != "true" ]]; then
        echo -e "\n${BLUE}=== System Services ===${NC}"
    fi
    
    # Check Nginx
    if command_exists nginx; then
        if systemctl is-active --quiet nginx; then
            log_pass "Nginx Service" "Running"
        else
            log_fail "Nginx Service" "Not running"
        fi
        
        # Check Nginx configuration
        if nginx -t >/dev/null 2>&1; then
            log_pass "Nginx Configuration" "Valid"
        else
            log_fail "Nginx Configuration" "Invalid configuration"
        fi
    else
        log_fail "Nginx" "Not installed"
    fi
    
    # Check PHP-FPM
    if command_exists php; then
        if systemctl is-active --quiet "$PHP_FPM_SERVICE"; then
            log_pass "PHP-FPM Service" "Running ($PHP_FPM_SERVICE)"
        else
            log_fail "PHP-FPM Service" "Not running ($PHP_FPM_SERVICE)"
        fi
    else
        log_fail "PHP" "Not installed"
    fi
}

# Check PHP environment
check_php_environment() {
    if [[ "$QUIET" != "true" ]]; then
        echo -e "\n${BLUE}=== PHP Environment ===${NC}"
    fi
    
    if ! command_exists php; then
        log_fail "PHP" "Not installed"
        return
    fi
    
    # PHP Version
    local php_version=$(php -v | head -n1 | cut -d' ' -f2)
    local required_version="7.2"
    
    if php -r "exit(version_compare('$php_version', '$required_version', '>=') ? 0 : 1);"; then
        log_pass "PHP Version" "PHP $php_version (>= $required_version)"
    else
        log_fail "PHP Version" "PHP $php_version (requires >= $required_version)"
    fi
    
    # PHP Extensions
    local required_extensions=("curl" "mbstring" "openssl" "json" "filter")
    local missing_extensions=()
    
    for ext in "${required_extensions[@]}"; do
        if ! php -m | grep -q "^$ext$"; then
            missing_extensions+=("$ext")
        fi
    done
    
    if [[ ${#missing_extensions[@]} -eq 0 ]]; then
        log_pass "PHP Extensions" "All required extensions loaded"
    else
        log_fail "PHP Extensions" "Missing extensions: ${missing_extensions[*]}"
    fi
    
    # PHP Settings
    if php -r "exit(ini_get('allow_url_fopen') ? 0 : 1);"; then
        log_pass "PHP Settings" "allow_url_fopen is enabled"
    else
        log_fail "PHP Settings" "allow_url_fopen is disabled (required)"
    fi
}

# Check file system
check_filesystem() {
    if [[ "$QUIET" != "true" ]]; then
        echo -e "\n${BLUE}=== File System ===${NC}"
    fi
    
    # Check project directory
    if [[ -d "$PROJECT_DIR" ]]; then
        log_pass "Project Directory" "Exists at $PROJECT_DIR"
    else
        log_fail "Project Directory" "Does not exist: $PROJECT_DIR"
        return
    fi
    
    # Check logs directory
    if [[ -d "$LOG_DIR" ]]; then
        if [[ -w "$LOG_DIR" ]]; then
            local log_count=$(find "$LOG_DIR" -name "*.log" 2>/dev/null | wc -l)
            log_pass "Logs Directory" "Writable with $log_count log files"
        else
            log_fail "Logs Directory" "Not writable: $LOG_DIR"
        fi
    else
        log_fail "Logs Directory" "Does not exist: $LOG_DIR"
    fi
    
    # Check download file
    if [[ -f "$DOWNLOAD_FILE" ]]; then
        local file_size=$(stat -c%s "$DOWNLOAD_FILE" 2>/dev/null || echo "0")
        local file_size_mb=$((file_size / 1024 / 1024))
        log_pass "Download File" "Exists (${file_size_mb}MB)"
    else
        log_warn "Download File" "Not found: $(basename "$DOWNLOAD_FILE")"
    fi
    
    # Check main application files
    local required_files=("index.php" "download.php")
    local missing_files=()
    
    for file in "${required_files[@]}"; do
        if [[ ! -f "$PROJECT_DIR/$file" ]]; then
            missing_files+=("$file")
        fi
    done
    
    if [[ ${#missing_files[@]} -eq 0 ]]; then
        log_pass "Application Files" "All required files exist"
    else
        log_fail "Application Files" "Missing files: ${missing_files[*]}"
    fi
    
    # Check file permissions
    if [[ -d "$PROJECT_DIR" ]]; then
        local owner=$(stat -c '%U:%G' "$PROJECT_DIR")
        local perms=$(stat -c '%a' "$PROJECT_DIR")
        log_pass "File Permissions" "Owner: $owner, Permissions: $perms"
    fi
}

# Check network connectivity
check_network() {
    if [[ "$QUIET" != "true" ]]; then
        echo -e "\n${BLUE}=== Network Connectivity ===${NC}"
    fi
    
    # Check internet connectivity
    if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        log_pass "Internet Connectivity" "Can reach external servers"
    else
        log_fail "Internet Connectivity" "Cannot reach external servers"
    fi
    
    # Check cloaking API
    if command_exists curl; then
        local start_time=$(date +%s%3N)
        local response=$(curl -s -w "%{http_code}" -o /dev/null \
            --max-time "$TIMEOUT" \
            -X POST \
            -d "label=health_check&user_agent=HealthCheck/1.0&ip_address=127.0.0.1" \
            "$CLOAKING_API" 2>/dev/null || echo "000")
        local end_time=$(date +%s%3N)
        local response_time=$((end_time - start_time))
        
        if [[ "$response" =~ ^[2-3][0-9][0-9]$ ]]; then
            log_pass "Cloaking API" "Responding (HTTP $response, ${response_time}ms)"
        elif [[ "$response" =~ ^[4][0-9][0-9]$ ]]; then
            log_warn "Cloaking API" "Client error (HTTP $response, ${response_time}ms)"
        elif [[ "$response" == "000" ]]; then
            log_fail "Cloaking API" "Connection failed (timeout or network error)"
        else
            log_fail "Cloaking API" "Server error (HTTP $response, ${response_time}ms)"
        fi
    else
        log_fail "cURL" "Not available for API testing"
    fi
    
    # Check local web server
    if command_exists curl; then
        local response=$(curl -s -w "%{http_code}" -o /dev/null \
            --max-time 5 \
            "http://localhost/" 2>/dev/null || echo "000")
        
        if [[ "$response" == "200" ]]; then
            log_pass "Local Web Server" "Responding (HTTP $response)"
        elif [[ "$response" == "000" ]]; then
            log_fail "Local Web Server" "Connection failed"
        else
            log_warn "Local Web Server" "Unexpected response (HTTP $response)"
        fi
    fi
}

# Check system resources
check_system_resources() {
    if [[ "$QUIET" != "true" ]]; then
        echo -e "\n${BLUE}=== System Resources ===${NC}"
    fi
    
    # Check disk space
    local disk_usage=$(df "$PROJECT_DIR" | awk 'NR==2 {print $5}' | sed 's/%//')
    if [[ "$disk_usage" -lt 90 ]]; then
        log_pass "Disk Space" "Usage: ${disk_usage}% (sufficient)"
    elif [[ "$disk_usage" -lt 95 ]]; then
        log_warn "Disk Space" "Usage: ${disk_usage}% (running low)"
    else
        log_fail "Disk Space" "Usage: ${disk_usage}% (critically low)"
    fi
    
    # Check memory usage
    if command_exists free; then
        local memory_usage=$(free | awk 'NR==2{printf "%.1f", $3*100/$2}')
        local memory_usage_int=${memory_usage%.*}
        
        if [[ "$memory_usage_int" -lt 80 ]]; then
            log_pass "Memory Usage" "Usage: ${memory_usage}% (normal)"
        elif [[ "$memory_usage_int" -lt 90 ]]; then
            log_warn "Memory Usage" "Usage: ${memory_usage}% (high)"
        else
            log_fail "Memory Usage" "Usage: ${memory_usage}% (critically high)"
        fi
    fi
    
    # Check load average
    if [[ -f /proc/loadavg ]]; then
        local load_avg=$(cut -d' ' -f1 /proc/loadavg)
        local cpu_count=$(nproc)
        local load_percent=$(echo "$load_avg * 100 / $cpu_count" | bc -l 2>/dev/null | cut -d'.' -f1)
        
        if [[ "$load_percent" -lt 70 ]]; then
            log_pass "System Load" "Load: $load_avg (${load_percent}% of $cpu_count CPUs)"
        elif [[ "$load_percent" -lt 90 ]]; then
            log_warn "System Load" "Load: $load_avg (${load_percent}% of $cpu_count CPUs)"
        else
            log_fail "System Load" "Load: $load_avg (${load_percent}% of $cpu_count CPUs)"
        fi
    fi
}

# Check application functionality
check_application() {
    if [[ "$QUIET" != "true" ]]; then
        echo -e "\n${BLUE}=== Application Functionality ===${NC}"
    fi
    
    # Check PHP syntax
    if command_exists php && [[ -d "$PROJECT_DIR" ]]; then
        local syntax_errors=$(find "$PROJECT_DIR" -name "*.php" -exec php -l {} \; 2>&1 | grep -c "Parse error" || true)
        
        if [[ "$syntax_errors" -eq 0 ]]; then
            log_pass "PHP Syntax" "No syntax errors found"
        else
            log_fail "PHP Syntax" "$syntax_errors syntax errors found"
        fi
    fi
    
    # Test main application
    if command_exists php && [[ -f "$PROJECT_DIR/healthcheck.php" ]]; then
        if php "$PROJECT_DIR/healthcheck.php" --quiet >/dev/null 2>&1; then
            log_pass "Application Health" "PHP health check passed"
        else
            log_fail "Application Health" "PHP health check failed"
        fi
    fi
}

# Generate JSON output
generate_json_output() {
    cat << EOF
{
    "status": "$OVERALL_STATUS",
    "timestamp": "$(date -Iseconds)",
    "summary": {
        "total_checks": $TOTAL_CHECKS,
        "passed": $PASSED_CHECKS,
        "warnings": $WARNING_CHECKS,
        "failed": $FAILED_CHECKS
    },
    "system_info": {
        "hostname": "$(hostname)",
        "uptime": "$(uptime -p 2>/dev/null || echo 'unknown')",
        "kernel": "$(uname -r)",
        "os": "$(lsb_release -d 2>/dev/null | cut -f2 || echo 'unknown')"
    }
}
EOF
}

# Main execution
main() {
    if [[ "$QUIET" != "true" ]]; then
        echo -e "${GREEN}FastConnect VPN Health Check${NC}"
        echo -e "${GREEN}============================${NC}"
        echo "Timestamp: $(date)"
        echo "Hostname: $(hostname)"
    fi
    
    # Run all health checks
    check_services
    check_php_environment
    check_filesystem
    check_network
    check_system_resources
    check_application
    
    # Generate output
    if [[ "$FORMAT" == "json" ]]; then
        output=$(generate_json_output)
    else
        if [[ "$QUIET" != "true" ]]; then
            echo -e "\n${BLUE}=== Summary ===${NC}"
            echo "Overall Status: $(echo "$OVERALL_STATUS" | tr '[:lower:]' '[:upper:]')"
            echo "Total Checks: $TOTAL_CHECKS"
            echo "✓ Passed: $PASSED_CHECKS"
            echo "⚠ Warnings: $WARNING_CHECKS"
            echo "✗ Failed: $FAILED_CHECKS"
        fi
        output=""
    fi
    
    # Write to file if specified
    if [[ -n "$OUTPUT_FILE" && -n "$output" ]]; then
        echo "$output" > "$OUTPUT_FILE"
        if [[ "$QUIET" != "true" ]]; then
            echo "Output written to: $OUTPUT_FILE"
        fi
    elif [[ -n "$output" ]]; then
        echo "$output"
    fi
    
    # Exit with appropriate code
    if [[ "$OVERALL_STATUS" == "healthy" ]]; then
        exit 0
    elif [[ "$OVERALL_STATUS" == "warning" ]]; then
        exit 1
    else
        exit 2
    fi
}

# Run main function
main "$@" 