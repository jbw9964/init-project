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


# Removal directory & script
REMOVAL_DIR="${PWD}/${BASE_NAME}-removal"
REMOVAL_SCRIPT="${REMOVAL_DIR}/${BASE_NAME}-removal.sh"

# Create directory
mkdir "${REMOVAL_DIR}"
record_rollback "rm -rf ${REMOVAL_DIR}"

# Prepare the basic removal script
cat > "${REMOVAL_SCRIPT}" <<EOF
#!/bin/bash

# Colors for logs
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
RESET='\033[0m'

echo -e "\${YELLOW}WARNING: \${RED}Running this script will execute all rollback commands and may delete associated project data.\${RESET}"
read -p "Are you sure you want to proceed? Type 'y' to confirm: " CONFIRMATION

if [ "\$CONFIRMATION" != "y" ]; then
  echo -e "\${GREEN}Removal has been cancelled.\${RESET}"
  exit 0
fi

echo -e "\${CYAN}Starting rollback process...\${RESET}"

EOF

# Append rollback logs to removal script in reverse order
tac "${ROLLBACK_LOG}" >> "${REMOVAL_SCRIPT}"

# Add completion message to the removal script
cat >> "${REMOVAL_SCRIPT}" <<EOF

echo -e "\${GREEN}Rollback completed successfully.\${RESET}"
EOF

# Make script executable
chmod u+x --recursive "${REMOVAL_DIR}"

log "Removal for project [${BASE_NAME}] has been created at: ${REMOVAL_SCRIPT}"
