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

if [ -z "$ROLLBACK_LOG" ]; then
  log_error "Error: --roll-back argument is required."
  exit 1
fi

record_rollback() {
  echo "$1" >> "$ROLLBACK_LOG"
}


# Function to generate a simple password block
gen_simple_pw() {
  local length=$1
  openssl rand -hex $((length / 2))
}

# Function to generate a password with blocks
gen_canonical_pw() {
  local single_length=$1
  local repeat=$2
  local password=""

  for ((i = 0; i < repeat; i++)); do
    block=$(gen_simple_pw "$single_length")

    if [ $i -eq 0 ]; then
      password="$block"
    else
      password="$password-$block"
    fi

  done

  echo "$password"
}

# Function to set system user password
set_system_password() {
  local username=$1
  local password=$2

  # change pw
  echo "$username:$password" | chpasswd

  # Record rollback
  # If user password has not been set, you can not login to that user via SSH
  record_rollback "echo $username:* | chpasswd"

  if [ $? -eq 0 ]; then
    log "Password set successfully for system user: $username"
  else
    log_error "Failed to set password for system user: $username"
    exit 1
  fi
}

# Function to set MySQL user password
set_mysql_password() {
  local username=$1
  local password=$2

  # change pw
  mysql -e "ALTER USER '$username' IDENTIFIED WITH caching_sha2_password BY '$password'; FLUSH PRIVILEGES;"

  # Record rollback
  # Even if password is empty, `auth_socket` plugin will prevent non-password remote access.
  record_rollback "mysql -e \"ALTER USER '$username' IDENTIFIED WITH auth_socket BY ''; FLUSH PRIVILEGES;\""

  # Skipping rollback for MySQL pw
  # If a user has no pw in mysql, it doesn't restrict

  if [ $? -eq 0 ]; then
    log "Password has been set for MySQL user: $username"
  else
    log_error "Failed to set password for MySQL user: $username"
    exit 1
  fi
}


# Password will have {REPEAT} times repeated, {SINGLE_LEN} length of hexadecimal
# "111aaa-bbb222-c3c3c3" like so
# Even number are proper for {SINGLE_LEN}, since it use `openssl rand`
# If it's odd number, it will be truncated to lower evens
SINGLE_LEN=6
REPEAT=3

# Generate admin and dev passwords
log "Generating passwords..."
PW_ADMIN=$(gen_canonical_pw "$SINGLE_LEN" "$REPEAT")
PW_DEV=$(gen_canonical_pw "$SINGLE_LEN" "$REPEAT")


# Project users
SYSTEM_ADMIN_USER="${BASE_NAME}-admin"
SYSTEM_DEV_USER="${BASE_NAME}-dev"

MYSQL_ADMIN_USER="${BASE_NAME}-admin"
MYSQL_DEV_USER="${BASE_NAME}-dev"

# Set password
log "Setting system user passwords..."
set_system_password "${SYSTEM_ADMIN_USER}" "${PW_ADMIN}"
set_system_password "${SYSTEM_DEV_USER}" "${PW_DEV}"

log "Setting MySQL user passwords..."
set_mysql_password "${MYSQL_ADMIN_USER}" "${PW_ADMIN}"
set_mysql_password "${MYSQL_DEV_USER}" "${PW_DEV}"

log "Password assignment has been set properly."

# Create configuration files
log "Creating configuration files for users..."

CONFIG_REPORT_FILE="${PWD}/${BASE_NAME}-config-report.config"
touch "${CONFIG_REPORT_FILE}"
record_rollback "rm -f ${CONFIG_REPORT_FILE}"

# Function to query MySQL user privileges
query_mysql_privileges() {
  local username=$1
  mysql -e "SHOW GRANTS FOR '$username';"
}

# Function to generate config report
create_config_report() {
  local config_file=$1
  local base_name=$2
  local system_admin_user=$3
  local system_admin_password=$4
  local system_dev_user=$5
  local system_dev_password=$6
  local mysql_admin_user=$7
  local mysql_admin_password=$8
  local mysql_dev_user=$9
  local mysql_dev_password=${10}

  log "Generating configuration report: $config_file"

  {
    printf "Configuration Report for Project: %s\n" "$base_name"
    printf "Generated on: %s\n" "$(date)"
    printf "Server Public IP: %s\n\n" "$(curl -s ifconfig.me)"

    printf "1. System Users and Groups:\n"
    printf "   Groups:\n"
    printf "     - %s-group\n" "$base_name"
    printf "     - %s-admin\n" "$base_name"
    printf "     - %s-dev\n\n" "$base_name"

    printf "   Users:\n"
    printf "     - Username: %s\n" "$system_admin_user"
    printf "       Password: %s\n" "$system_admin_password"
    printf "       Groups: %s\n\n" "$(groups "$system_admin_user" 2>/dev/null | awk -F ':' '{print $2}' | xargs)"

    printf "     - Username: %s\n" "$system_dev_user"
    printf "       Password: %s\n" "$system_dev_password"
    printf "       Groups: %s\n\n" "$(groups "$system_dev_user" 2>/dev/null | awk -F ':' '{print $2}' | xargs)"

    printf "2. Database and MySQL Users:\n"
    printf "   Database Name: %s_db\n\n" "$base_name"

    printf "   Users:\n"
    printf "     - Username: %s\n" "$mysql_admin_user"
    printf "       Password: %s\n" "$mysql_admin_password"
    printf "       Privileges:\n"
    query_mysql_privileges "$mysql_admin_user" | sed 's/^/         /'
    printf "\n"

    printf "     - Username: %s\n" "$mysql_dev_user"
    printf "       Password: %s\n" "$mysql_dev_password"
    printf "       Privileges:\n"
    query_mysql_privileges "$mysql_dev_user" | sed 's/^/         /'
    printf "\n"

    printf "3. Additional Information:\n"
    printf "   Script executed by: %s\n" "$(whoami)"
    printf "   Hostname: %s\n" "$(hostname)"
  } > "$config_file"

  if [ $? -eq 0 ]; then
    log "Configuration report has been saved to: $config_file"
  else
    log_error "Failed to save configuration report."
    exit 1
  fi
}

create_config_report "${CONFIG_REPORT_FILE}" "${BASE_NAME}" \
  "${SYSTEM_ADMIN_USER}" "${PW_ADMIN}" \
  "${SYSTEM_DEV_USER}" "${PW_DEV}" \
  "${MYSQL_ADMIN_USER}" "${PW_ADMIN}" \
  "${MYSQL_DEV_USER}" "${PW_DEV}"

log "Passwords & configuration has been successfully recorded."