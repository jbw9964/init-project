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

# Login timeout
# 1800s = 30m
TIMEOUT=1800

# User profile on home directory
PROFILE="/home/${BASE_NAME}/.profile"

# Check weather profile exists
log "Verifying user profile..."
if [ ! -f "$PROFILE" ]; then
  log_error "Error: profile ${PROFILE} doesn't exists."
  exit 1
fi
log "User profile exists."

append_to_profile() {
  echo "$1" >> "$PROFILE"
}

# Append timeout to profile
log "Setting profile timeout..."
append_to_profile ""
append_to_profile "# login timeout (sec)"
append_to_profile "TMOUT=${TIMEOUT}"
append_to_profile "export TMOUT"
append_to_profile ""

log "User profile timeout has been set successfully."
