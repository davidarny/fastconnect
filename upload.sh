#!/bin/bash

# Upload files to remote server
# Usage: ./upload-file.sh <filename>

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
REMOTE_USER="root"
REMOTE_HOST="5.183.11.191"
REMOTE_PATH="/var/www/protectshield/"

# Function to display usage
show_usage() {
  echo -e "${BLUE}Usage:${NC}"
  echo "  $0 <filename>         # Upload specific file"
  echo "  $0 --list            # List available files"
  echo "  $0 --help            # Show this help message"
  echo
  echo -e "${BLUE}Examples:${NC}"
  echo "  $0 setup.exe          # Upload setup.exe"
  echo "  $0 document.pdf       # Upload document.pdf"
  echo "  $0 image.png          # Upload image.png"
}

# Function to check if file exists
check_file_exists() {
  local file="$1"
  if [ ! -f "$file" ]; then
    echo -e "${RED}Error: File '$file' not found${NC}"
    return 1
  fi
  return 0
}

# Function to upload a single file
upload_file() {
  local filename="$1"
  local local_path="$filename"

  echo -e "${YELLOW}Uploading $filename...${NC}"

  # Check if file exists locally
  if ! check_file_exists "$filename"; then
    return 1
  fi

  # Get file size for progress indication
  local file_size=$(ls -lh "$local_path" | awk '{print $5}')
  echo -e "${BLUE}File size: $file_size${NC}"

  # Upload the file
  if scp "$local_path" "$REMOTE_USER@$REMOTE_HOST:$REMOTE_PATH"; then
    echo -e "${GREEN}✓ Successfully uploaded $filename${NC}"
    return 0
  else
    echo -e "${RED}✗ Failed to upload $filename${NC}"
    return 1
  fi
}

# Function to list available files
list_files() {
  echo -e "${BLUE}Available files:${NC}"
  if ls ./* 1>/dev/null 2>&1; then
    for file in ./*; do
      if [ -f "$file" ]; then
        local filename=$(basename "$file")
        local file_size=$(ls -lh "$file" | awk '{print $5}')
        echo -e "  ${GREEN}$filename${NC} (${YELLOW}$file_size${NC})"
      fi
    done
  else
    echo -e "${YELLOW}No files found${NC}"
  fi
}

# Main script logic
main() {
  echo -e "${GREEN}File Upload Script${NC}"
  echo -e "${BLUE}Remote destination: $REMOTE_USER@$REMOTE_HOST:$REMOTE_PATH${NC}"
  echo

  # Parse command line arguments
  case "${1:-}" in
  --help | -h)
    show_usage
    exit 0
    ;;
  --list | -l)
    list_files
    exit 0
    ;;
  "")
    # No arguments - show usage and require filename
    echo -e "${RED}Error: Filename is required${NC}"
    echo
    show_usage
    exit 1
    ;;
  *)
    # Any filename provided
    upload_file "$1"
    ;;
  esac
}

# Check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi

