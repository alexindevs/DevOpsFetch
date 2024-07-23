#!/bin/bash

# Set the log file path
LOG_FILE="/var/log/devopsfetch.log"

# Function to log messages
log_message() {
    local category="$1"
    local message="$2"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $category - $message" >> "$LOG_FILE"
}

is_regular_user() {
    local user=$1
    local uid=$(id -u "$user" 2>/dev/null)
    [[ -n "$uid" && "$uid" -ge 1000 ]]
}

# Monitor user activities
monitor_user_activities() {
    tail -fn0 /var/log/auth.log | while read line; do
        if echo "$line" | grep -q "session opened"; then
            user=$(echo $line | awk '{print $9}')
            if is_regular_user "$user"; then
                log_message "User Activity" "User logged in: $user"
            fi
        elif echo "$line" | grep -q "session closed"; then
            user=$(echo $line | awk '{print $9}')
            if is_regular_user "$user"; then
                log_message "User Activity" "User logged out: $user"
            fi
        elif echo "$line" | grep -q "su:"; then
            from_user=$(echo $line | awk '{print $11}')
            to_user=$(echo $line | awk '{print $13}')
            if is_regular_user "$from_user"; then
                log_message "User Activity" "User switched: $from_user to $to_user"
            fi
        fi
    done &
}

# Monitor network activities on ports
monitor_network_activities() {
    touch /tmp/previous_ports
    while true; do
        netstat -tulpn | grep LISTEN | awk '{print $4,$7,$NF}' | sort > /tmp/current_ports
        diff /tmp/previous_ports /tmp/current_ports 2>/dev/null | while read line; do
            if [[ $line == "<"* ]]; then
                port=$(echo $line | awk '{print $2}')
                process=$(echo $line | awk '{print $3}')
                log_message "Network Activity" "Port closed: $port - Process: $process"
            elif [[ $line == ">"* ]]; then
                port=$(echo $line | awk '{print $2}')
                process=$(echo $line | awk '{print $3}')
                log_message "Network Activity" "Port opened: $port - Process: $process"
            fi
        done
        mv /tmp/current_ports /tmp/previous_ports
        sleep 5
    done &
}

# Monitor changes in nginx conf
monitor_nginx_conf() {
    inotifywait -m -r -e modify,create,delete,move /etc/nginx/sites-enabled 2>/dev/null | while read path action file; do
        if ! echo "$path $action $file" | grep -qE "Setting up watches|Watches established"; then
            user=$(who | awk '{print $1}' | sort -u | head -n1)
            log_message "Nginx Config" "$user $action $file in $path"
        fi
    done &
}

# Monitor Docker activities
monitor_docker_activities() {
    docker events --format '{{.Status}} {{.Type}} {{.Actor.ID}}' | while read event; do
        log_message "Docker Activity" "$event"
    done &
}

# Start all monitoring functions
monitor_user_activities
monitor_network_activities
monitor_nginx_conf
monitor_docker_activities

# Keep the script running
while true; do
    sleep 1
done