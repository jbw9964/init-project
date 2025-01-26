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

execute_mysql_cmd() {
  mysql -e "$1"
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

if [ -z "$ROLLBACK_LOG" ]; then
  log_error "Error: --roll-back argument is required."
  exit 1
fi

record_rollback() {
  echo "$1" >> "$ROLLBACK_LOG"
}


# Database and user names
DB_NAME="${BASE_NAME}_db"
ADMIN_USER="'${BASE_NAME}-admin'@'%'"
DEV_USER="'${BASE_NAME}-dev'@'%'"

# All users can be accessed on local & remote
# Use a format like 'localhost' or 'x.x.x.%' to limit their access


# Create database
log "Creating project database: ${DB_NAME}"
execute_mysql_cmd "CREATE DATABASE \`${DB_NAME}\`;"
record_rollback "mysql -e \"DROP DATABASE \\\`${DB_NAME}\\\`;\""

# Create users
# By using `auth_socket` plugin, you can prevent non-password remote access with created user.

# Admin user
log "Creating admin user for project: ${ADMIN_USER}"
execute_mysql_cmd "CREATE USER ${ADMIN_USER} IDENTIFIED WITH auth_socket;"
record_rollback "mysql -e \"DROP USER ${ADMIN_USER}\""

# Dev user
log "Creating dev user for project: ${DEV_USER}"
execute_mysql_cmd "CREATE USER ${DEV_USER} IDENTIFIED WITH auth_socket;"
record_rollback "mysql -e \"DROP USER ${DEV_USER}\""


# Grant privileges to users
log "Granting privileges to users" 

# Admin user has all privileges
execute_mysql_cmd "GRANT ALL ON *.* TO ${ADMIN_USER};"

# Dev user has all privileges limited to {DB_NAME} db
execute_mysql_cmd "GRANT ALL ON ${DB_NAME}.* TO ${DEV_USER}"

log "MySQL resources are successfully created."
