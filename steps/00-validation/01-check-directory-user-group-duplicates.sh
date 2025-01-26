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

log "Validation started for project: $BASE_NAME"

# Validate home directory
if [ -d "/home/$BASE_NAME" ]; then
  log_error "Error: Directory /home/$BASE_NAME already exists."
  exit 1
fi

# Validate groups
for group in "${BASE_NAME}-group" "${BASE_NAME}-admin" "${BASE_NAME}-dev"; do
  if getent group "$group" >/dev/null; then
    log_error "Error: Group $group already exists."
    exit 1
  fi
done

# Validate users
for user in "${BASE_NAME}-admin" "${BASE_NAME}-dev"; do
  if id "$user" >/dev/null 2>&1; then
    log_error "Error: User $user already exists."
    exit 1
  fi
done

log "Directory & Groups & User validation  passed for project: $BASE_NAME"
