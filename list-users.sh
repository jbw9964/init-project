#!/bin/bash

# Last edited : 2025:01:22-22:45

# Header for the output with extended widths
printf "%-25s %-25s %-10s %-10s\n" "USERNAME" "PRIORITY GROUP" "UID" "GID"

# Sort the /etc/passwd file by UID numerically and iterate through the sorted entries
sort -t: -k3n /etc/passwd | while IFS=: read -r username _ uid gid _ _ _; do

  # Ignore system accounts with UID less than 1000
  if [ "$uid" -ge 1000 ]; then
    # Get the primary group name for the user
    group=$(getent group "$gid" | cut -d: -f1)

    # If the group name exists, print user, group, uid, and gid
    if [ -n "$group" ]; then
      printf "%-25s %-25s %-10s %-10s\n" "$username" "$group" "$uid" "$gid"
    fi

  fi

done