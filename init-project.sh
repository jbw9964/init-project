#!/bin/bash

set -e

# Colors for logs
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
RESET='\033[0m'

log() {
  echo -e "${CYAN}$(date "+%Y-%m-%d %H:%M:%S") - $1${RESET}"
}

log_success() {
  echo -e "${GREEN}$(date "+%Y-%m-%d %H:%M:%S") - $1${RESET}"
}

log_error() {
  echo -e "${RED}$(date "+%Y-%m-%d %H:%M:%S") - $1${RESET}"
}

log_warning() {
  echo -e "${YELLOW}$(date "+%Y-%m-%d %H:%M:%S") - $1${RESET}"
}

rollback() {
  log_error "Rolling back actions..."
  if [ -f "$ROLLBACK_LOG" ]; then

    tac "$ROLLBACK_LOG" | while read -r cmd; do
      log_warning "Executing rollback command: $cmd"
      eval "$cmd" || log_error "Warning: Rollback command failed: $cmd"
    done
    
    log_warning "Rollback commands were executed. Removing rollback log"
    rm -f "$ROLLBACK_LOG"
    log_warning "Removed rollback log: ${ROLLBACK_LOG}"
  
  fi
  log_error "Rollback completed."
}

# Trap to ensure rollback log is cleaned up in case of errors
trap "if [ -f \"$ROLLBACK_LOG\" ]; then rm -f \"$ROLLBACK_LOG\"; log_success \"Cleanup completed: Removed rollback log $ROLLBACK_LOG\"; fi" EXIT

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
      log_warning "Usage: $0 --base-name=[PROJECT_BASENAME] --roll-back=[ROLLBACK_LOG]"
      exit 1
      ;;
  esac
done

if [ -z "$BASE_NAME" ]; then
  log_error "Error: --base-name argument is required."
  log_warning "Usage: $0 --base-name=[PROJECT_BASENAME] [--roll-back=ROLLBACK_LOG]"
  exit 1
fi

# Set rollback log file
DEFAULT_ROLLBACK_LOG="/tmp/${BASE_NAME}-project-init-rollback.log"
ROLLBACK_LOG=${ROLLBACK_LOG:-$DEFAULT_ROLLBACK_LOG}

log "Initialization started for project: $BASE_NAME with rollback log: $ROLLBACK_LOG"

# Execute steps in the "steps" directory
for step_dir in steps/*; do

  if [ -d "$step_dir" ]; then

    echo "" # Add newline
    log "Executing step directory: $step_dir"
    step_count=0

    for step_script in $(ls "$step_dir"/*.sh 2>/dev/null | sort); do
      step_count=$((step_count + 1))
      log "Running step script: $step_script"
      bash "$step_script" --base-name="$BASE_NAME" --roll-back="$ROLLBACK_LOG" || {

        echo ""
        ERR="Error has been occurred at ${step_script}. Triggering rollback."
        SIZE=${#ERR}
        WRAPPER=$(printf "=%.0s" $(seq 1 $((SIZE + 4))))
        log_error " $WRAPPER "
        log_error "|  $ERR  |"
        log_error " $WRAPPER "
        echo ""

        rollback
        exit 1
      }

      log_success "Step $step_script completed successfully."
    done

    if [ "$step_count" -eq 0 ]; then
      log_warning "No scripts found in step directory: $step_dir"
    fi

  fi
done

echo "" # Add newline
log_success "Initialization for project $BASE_NAME completed successfully."

# Explicitly delete the rollback log after success
if [ -f "$ROLLBACK_LOG" ]; then
  rm -f "$ROLLBACK_LOG"
  log_success "Removed rollback log: $ROLLBACK_LOG"
fi
