#!/bin/bash

LOG_FILE="/var/log/devopsfetch.log"

YESTERDAY_DATE=$(date -d "yesterday" '+%Y-%m-%d')

OLD_LOG_FILE="/var/log/devopsfetch-$YESTERDAY_DATE.log"

mv "$LOG_FILE" "$OLD_LOG_FILE"

touch "$LOG_FILE"

chmod 644 "$LOG_FILE"

gzip "$OLD_LOG_FILE"