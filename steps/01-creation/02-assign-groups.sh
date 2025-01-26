#!/bin/bash

# Colors for logs
RED='\033[0;31m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

# System-wide admin user
SUDO_ADMIN='cheongju-admin'

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
      echo "Usage: $0 --base-name=PROJECT_BASENAME [--roll-back=ROLLBACK_LOG]"
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


# Groups for project
PROJECT_GRP="${BASE_NAME}-group"
PROJECT_ADMIN_GRP="${BASE_NAME}-admin"
PROJECT_DEV_GRP="${BASE_NAME}-dev"

# Create project groups
log "Creating groups for project: $BASE_NAME"
groupadd "${PROJECT_GRP}"
record_rollback "groupdel ${PROJECT_GRP}"


# No roll back required to delete primary groups
# Primary groups will be automatically deleted when each users deleted.


# Assign groups to project users

ADMIN_USER="${BASE_NAME}-admin"
DEV_USER="${BASE_NAME}-dev"

# Groups for admin
log "Adding groups to users"
gpasswd -a "${ADMIN_USER}" "${PROJECT_GRP}"
record_rollback "gpasswd --delete ${ADMIN_USER} ${PROJECT_GRP}"

gpasswd -a "${ADMIN_USER}" "${PROJECT_ADMIN_GRP}"
record_rollback "gpasswd --delete ${ADMIN_USER} ${PROJECT_ADMIN_GRP}"

gpasswd -a "${ADMIN_USER}" sudo
record_rollback "gpasswd --delete ${ADMIN_USER} sudo"

# Groups for dev
gpasswd -a "${DEV_USER}" "${PROJECT_GRP}"
record_rollback "gpasswd --delete ${DEV_USER} ${PROJECT_GRP}"

gpasswd -a "${DEV_USER}" "${PROJECT_DEV_GRP}"
record_rollback "gpasswd --delete ${DEV_USER} ${PROJECT_DEV_GRP}"

# Assign application groups to dev user
log "Adding application groups to dev"
if [ -f "Application-groups.config" ]; then
  while IFS= read -r group; do

    # Skip empty or whitespace-only groups
    if [[ -z "${group// }" ]]; then
      continue
    fi

    # Check if group exists in the system
    if ! getent group "$group" > /dev/null 2>&1; then
      log_error "Group '$group' does not exist. Exiting script."
      exit 1
    fi

    # Add user to the group
    gpasswd -a "${DEV_USER}" "$group"

    # Log the rollback command
    record_rollback "gpasswd --delete ${DEV_USER} ${group}"
  done < Application-groups.config
else
    log_warning "Cannot find Application-groups.config in directory $PWD"
    log_warning "Skipping application group assignment..."
fi


# Add {SUDO_ADMIN} to the project groups
log "Adding the executing user ${SUDO_ADMIN} to the groups"
gpasswd -a "${SUDO_ADMIN}" "${PROJECT_GRP}"
record_rollback "gpasswd --delete ${SUDO_ADMIN} ${PROJECT_GRP}"

gpasswd -a "${SUDO_ADMIN}" "${PROJECT_ADMIN_GRP}"
record_rollback "gpasswd --delete ${SUDO_ADMIN} ${PROJECT_ADMIN_GRP}"

gpasswd -a "${SUDO_ADMIN}" "${PROJECT_DEV_GRP}"
record_rollback "gpasswd --delete ${SUDO_ADMIN} ${PROJECT_DEV_GRP}"

log "Groups were assigned successfully for project: $BASE_NAME"
