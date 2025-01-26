#!/bin/bash

# Default values for arguments
MAX_CHAR=20
SORT_NAME=true

# Function to display help
print_help() {
  echo "Usage: $0 [OPTIONS]"
  echo ""
  echo "Options:"
  echo "  --max-char N    Set the maximum character length for usernames (default: 20)"
  echo "                  (N must be a positive integer)"
  echo "  --no-sort-name  Disable sorting the output by username"
  echo "  -h, --help      Display this help message and exit"
  echo ""
  echo "Description:"
  echo "  This script lists users currently logged in via SSH. The output includes the username,"
  echo "  process ID, process status, start time, CPU time, and command for SSH sessions."
  echo "  The --max-char option limits the width of the username column. By default, the output"
  echo "  is sorted by username; use --no-sort-name to disable sorting."
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --max-char)
      if [[ $2 =~ ^[1-9][0-9]*$ ]]; then
        MAX_CHAR=$2
        shift 2
      else
        echo "Error: Invalid value for --max-char. It must be a positive integer."
        exit 1
      fi
      ;;
    --no-sort-name)
      SORT_NAME=false
      shift
      ;;
    -h|--help)
      print_help
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Use -h or --help for usage information."
      exit 1
      ;;
  esac
done

# Build the ps command with dynamic user column width for username only
PS_COMMAND="ps axo user:${MAX_CHAR},pid,stat,lstart,time,comm"

# Get the process list for sshd
OUTPUT=$($PS_COMMAND | grep sshd | grep -v grep)

# Get the header from ps command
HEADER=$($PS_COMMAND | head -n 1)

# Sort the output if sorting is enabled
if $SORT_NAME; then
  OUTPUT=$(echo "$OUTPUT" | sort)
fi

# Adjust the output to prevent splitting of the start date
OUTPUT=$(echo "$OUTPUT" | awk '{
  # Combine the split lstart columns back into one date-time string
  lstart = $4 " " $5 " " $6 " " $7 " " $8
  $4 = lstart
  $5 = $6 = $7 = $8 = ""
  print $0
}')

# Define column widths
COLUMN_WIDTH_PID=10
COLUMN_WIDTH_STAT=10
COLUMN_WIDTH_STARTED=30
COLUMN_WIDTH_TIME=15
COLUMN_WIDTH_CMD=15

# Print the header with dynamic width for USER and fixed width for other columns
# Adjusting header printing to avoid treating the STARTED column as multiple columns
echo "$HEADER" | awk \
  -v max_user_len="$MAX_CHAR" \
  -v pid_width=$COLUMN_WIDTH_PID \
  -v stat_width=$COLUMN_WIDTH_STAT \
  -v started_width=$COLUMN_WIDTH_STARTED \
  -v time_width=$COLUMN_WIDTH_TIME \
  -v cmd_width=$COLUMN_WIDTH_CMD \
  '{ printf "%-*s%-*s%-*s%-*s %-*s %-*s\n",
  max_user_len, $1,
  pid_width, $2,
  stat_width, $3,
  started_width, $4,
  time_width, $5,
  cmd_width, $6 }'

# Print the output with the same logic
echo "$OUTPUT" | awk \
  -v max_user_len="$MAX_CHAR" \
  -v pid_width=$COLUMN_WIDTH_PID \
  -v stat_width=$COLUMN_WIDTH_STAT \
  -v started_width=$COLUMN_WIDTH_STARTED \
  -v time_width=$COLUMN_WIDTH_TIME \
  -v cmd_width=$COLUMN_WIDTH_CMD \
  '{ printf "%-*s%-*s%-*s%-*s %-*s %-*s\n",
  max_user_len, $1,
  pid_width, $2,
  stat_width, $3,
  started_width, $4 " " $5 " " $6 " " $7 " " $8,
  time_width, $9,
  cmd_width, $10 }'