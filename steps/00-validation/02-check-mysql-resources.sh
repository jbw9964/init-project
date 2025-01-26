#!/bin/bash

# Colors for logs
RED='\033[0;31m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

log() {
  echo -e "${CYAN}$(date "+%Y-%m-%d %H:%M:%S") - $1${RESET}"
}

log_error() {
  echo -e "${RED}$(date "+%Y-%m-%d %H:%M:%S") - $1${RESET}"
}

log_warning() {
  echo -e "${YELLOW}$(date "+%Y-%m-%d %H:%M:%S") - $1${RESET}"
}

# Parse arguments
for arg in "$@"; do
  case $arg in
    --base-name=*)
      BASE_NAME="${arg#*=}"
      ;;
    --roll-back=*)
      ROLLBACK_LOG="${arg#*=}"
      ;;
    *)
      log_error "Unknown argument: $arg"
      log_warning "Usage: $0 --base-name=PROJECT_BASENAME [--roll-back=ROLLBACK_LOG]"
      exit 1
      ;;
  esac
done

if [ -z "$BASE_NAME" ]; then
  log_error "Error: --base-name argument is required."
  exit 1
fi

# Database and user names
DB_NAME="${BASE_NAME}_db"
ADMIN_USER="${BASE_NAME}-admin"
DEV_USER="${BASE_NAME}-dev"

# Check for database existence
if mysql -N -B -e "SHOW DATABASES LIKE '${DB_NAME}';" | grep -q "${DB_NAME}"; then
  log_error "Error: Database $DB_NAME already exists."
  exit 1
fi

log "No duplicate database exists."

# Check for admin user existence
if mysql -N -B -e "SELECT user FROM mysql.user WHERE user = '${ADMIN_USER}';" | grep -q "${ADMIN_USER}"; then
  log_error "Error: MySQL user $ADMIN_USER already exists."
  exit 1
fi

# Check for dev user existence
if mysql -N -B -e "SELECT user FROM mysql.user WHERE user = '${DEV_USER}';" | grep -q "${DEV_USER}"; then
  log_error "Error: MySQL user $DEV_USER already exists."
  exit 1
fi

log "No duplicate users exist."

log "MySQL validation passed for project: $BASE_NAME"
