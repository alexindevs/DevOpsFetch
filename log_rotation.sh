#!/bin/bash

# Set the log file path
LOG_FILE="/var/log/devopsfetch.log"

# Get the current date in YYYY-MM-DD format
CURRENT_DATE=$(date '+%Y-%m-%d')

# Define the new log file name with a timestamp
OLD_LOG_FILE="/var/log/devopsfetch-$CURRENT_DATE.log"

# Move the current log file to the new log file
mv "$LOG_FILE" "$OLD_LOG_FILE"

# Create a new, empty log file
touch "$LOG_FILE"

# Set appropriate permissions (if necessary)
chmod 644 "$LOG_FILE"
