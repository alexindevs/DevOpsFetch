#!/bin/bash

# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run this script as root or using sudo."
    exit 1
fi

DEVOPSFETCH_SCRIPT="/usr/local/bin/devopsfetch"
MONITOR_SCRIPT="/usr/local/bin/devopsfetch_monitor"
LOG_ROTATION_SCRIPT="/usr/local/bin/devopsfetch_log_rotation"
SERVICE_FILE="/etc/systemd/system/devopsfetch_monitor.service"
CRONTAB_JOB="0 0 * * * /usr/local/bin/devopsfetch_log_rotation"

# Confirmation prompt
read -p "This will uninstall DevOpsFetch and remove all related components. Are you sure you want to proceed? (yes/no): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
    echo "Uninstallation aborted."
    exit 0
fi

# Stop and disable the systemd service
if systemctl is-active --quiet devopsfetch_monitor.service; then
    systemctl stop devopsfetch_monitor.service
fi
systemctl disable devopsfetch_monitor.service
rm -f "$SERVICE_FILE"

# Remove the scripts
rm -f "$DEVOPSFETCH_SCRIPT"
rm -f "$MONITOR_SCRIPT"
rm -f "$LOG_ROTATION_SCRIPT"

# Remove cron job
(crontab -l 2>/dev/null | grep -v "$CRONTAB_JOB") | crontab -

# Remove the sudoers entries
rm -f /etc/sudoers.d/devopsfetch
rm -f /etc/sudoers.d/devopsfetch_systemd

echo "Uninstallation complete."
