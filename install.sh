#!/bin/bash

# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run this script as root or using sudo."
    exit 1
fi

# Set variables
LOGFILE="/var/log/devopsfetch.log"
DEVOPSFETCH_SCRIPT="/usr/local/bin/devopsfetch"
MONITOR_SCRIPT="/usr/local/bin/devopsfetch_monitor"
SERVICE_FILE="/etc/systemd/system/devopsfetch_monitor.service"
LOG_ROTATION_SCRIPT="/usr/local/bin/devopsfetch_log_rotation"

touch "$LOGFILE"
chmod 644 "$LOGFILE"

apt-get update
apt-get install -y lsof docker.io nginx inotify-tools net-tools systemd cron
sudo systemctl start cron
sudo systemctl enable cron

cp devopsfetch.sh "$DEVOPSFETCH_SCRIPT"
chmod +x "$DEVOPSFETCH_SCRIPT"

echo "devopsfetch ALL=(ALL) NOPASSWD: /usr/bin/lsof, /usr/bin/docker, /usr/sbin/nginx, /bin/netstat, /bin/systemctl" >> /etc/sudoers.d/devopsfetch
chmod 0440 /etc/sudoers.d/devopsfetch

echo "devopsfetch ALL=(ALL) NOPASSWD: /bin/systemctl start devopsfetch_monitor.service, /bin/systemctl stop devopsfetch_monitor.service, /bin/systemctl restart devopsfetch_monitor.service, /bin/systemctl status devopsfetch_monitor.service" > /etc/sudoers.d/devopsfetch_systemd
chmod 0440 /etc/sudoers.d/devopsfetch_systemd

cp devopsfetch_monitor.sh "$MONITOR_SCRIPT"
chmod +x "$MONITOR_SCRIPT"

cp log_rotation.sh "$LOG_ROTATION_SCRIPT"
chmod +x "$LOG_ROTATION_SCRIPT"

(crontab -l 2>/dev/null || echo "") | grep -v "$LOG_ROTATION_SCRIPT" | (cat; echo "0 0 * * * $LOG_ROTATION_SCRIPT") | sudo crontab -

cat << EOF > "$SERVICE_FILE"
[Unit]
Description=DevOpsFetch Monitoring Service
After=network.target

[Service]
ExecStart=$MONITOR_SCRIPT
Restart=on-failure
User=root
Group=root
StandardOutput=append:$LOGFILE
StandardError=append:$LOGFILE

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable devopsfetch_monitor.service
systemctl start devopsfetch_monitor.service

if systemctl is-active --quiet devopsfetch_monitor.service; then
    echo "Installation successful. DevOpsFetch monitoring service is active and running."
    echo "You can now use 'devopsfetch -h' from anywhere in the system."
else
    echo "Installation completed, but the service failed to start. Please check the logs."
fi