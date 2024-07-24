#!/bin/bash

# This script applies changes to the devopsfetch and devopsfetch_monitor executable, makes them executable, and restarts the devopsfetch_monitor service. 

# Apply changes to devopsfetch executable
cp devopsfetch.sh /usr/local/bin/devopsfetch
chmod +x /usr/local/bin/devopsfetch

# Apply changes to devopsfetch_monitor executable
cp devopsfetch_monitor.sh /usr/local/bin/devopsfetch_monitor
chmod +x /usr/local/bin/devopsfetch_monitor

cp log_rotation.sh /usr/local/bin/devopsfetch_log_rotation
chmod +x /usr/local/bin/devopsfetch_log_rotation

# Restart devopsfetch_monitor service
systemctl restart devopsfetch_monitor

echo "Changes applied successfully!"