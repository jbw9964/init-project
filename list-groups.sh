#!/bin/bash

# Last Edited : 2025:01:22-22:45

# Header for the output with extended widths
printf "%-25s %-10s %-25s\n" "GROUPNAME" "GID" "GROUP MEMBERS"

# Sort the file by GID (third field) in ascending order
sort -t: -k3n /etc/group | while IFS=: read -r groupname _ gid members _; do

    # If group members exist, show them, otherwise show 'No members'
    if [ -n "$members" ]; then
      members_list="$members"
    else
      members_list="No members"
    fi

    # Print group name, gid, and members
    printf "%-25s %-10s %-25s\n" "$groupname" "$gid" "$members_list"

done