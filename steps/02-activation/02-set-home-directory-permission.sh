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


HOME_DIR="/home/${BASE_NAME}"
PROJECT_GRP="${BASE_NAME}-group"
PROJECT_ADMIN_GRP="${BASE_NAME}-admin"

# Change directory group owner
log "Changing project home directory group owner..."
chgrp --recursive "${PROJECT_GRP}" "${HOME_DIR}"
record_rollback "chgrp --recursive ${PROJECT_ADMIN_GRP} ${HOME_DIR}"

# Change group permission to home directory
log "Changing group permissions..."
chmod --recursive g+rwx "${HOME_DIR}"

log "Project group ${PROJECT_GRP} now owns all resources in ${HOME_DIR}."
log "${PROJECT_GRP} has all permissions to ${HOME_DIR} recursively."
