#!/bin/bash

# create log file
USER=$(logname)
LOGFILE="/home/$USER/devopsfetch.log"
[ -f "$LOGFILE" ] || touch "$LOGFILE"

# completed
get_ports() {
  if [ -z "$1" ]; then
    sudo lsof -i -P | format_output
  else
    sudo lsof -i -P | grep ":$1" | format_output
  fi
}

# completed
get_docker_info() {
  if ! command -v docker &> /dev/null; then
    echo "Docker is not installed. Please install it and try again."
    return 1
  fi

  if [ -z "$1" ]; then
    sudo docker ps -a --format 'table {{.ID}}\t{{.Image}}\t{{.Names}}\t{{.CreatedAt}}\t{{.Status}}\t{{.Ports}}' | column -t -s $'\t'
    sudo docker images --format 'table {{.Repository}}\t{{.Tag}}\t{{.CreatedAt}}\t{{.Size}}' | column -t -s $'\t'
  else
    sudo docker inspect "$1" | jq -r '[
      .[0] | {
        ID: (.Id[0:16]),
        NAME: ((.Name // .RepoTags[0])),
        CREATED: .Created,
        STATUS: .State.Status,
        ARGS: (.Config.Cmd | join(" ")),
        "EXPOSED PORTS": (.Config.ExposedPorts | keys | join(", "))
      }
    ] | (.[0] | keys_unsorted), (.[] | [.[]]) | @tsv' | column -t -s $'\t'
  fi
}

log_nginx_information() {
    local parameter=$1
    if ! command -v nginx &> /dev/null; then
        echo "Nginx is not installed."
        return 1
    fi

    nginx_conf="/etc/nginx/nginx.conf"
    if [ ! -f "$nginx_conf" ]; then
        echo "Nginx configuration file not found at $nginx_conf"
        return 1
    fi

    # Function to get all included files
    get_included_files() {
        local conf_file=$1
        local base_dir=$(dirname "$conf_file")
        grep -oP 'include\s+\K[^;]+' "$conf_file" | while read -r include_path; do
            if [[ "$include_path" == /* ]]; then
                find "$include_path" -type f 2>/dev/null
            else
                find "$base_dir/$include_path" -type f 2>/dev/null
            fi
        done
    }

    # Get all configuration files
    config_files=$(get_included_files "$nginx_conf")
    config_files="$nginx_conf $config_files"

    # Function to process each file
    process_file() {
        local file=$1
        local search=$2
        awk -v search="$search" '
        BEGIN { domain = ""; proxy = ""; port = "80"; }
        /server_name/ { 
            domain = $2; 
            gsub(/;$/, "", domain);
        }
        /listen/ { 
            port = $2; 
            gsub(/;$/, "", port);
        }
        /proxy_pass/ { 
            proxy = $2; 
            gsub(/;$/, "", proxy);
            gsub(/^http:\/\//, "", proxy);
        }
        END {
            if ((search == "" || domain ~ search || port ~ search) && domain != "") {
                if (proxy == "") proxy = "N/A";
                printf "%-35s %-7s %-20s %s\n", domain, port, proxy, FILENAME;
            }
        }' "$file"
    }

    echo -e "SERVER DOMAIN                       PORT    PROXY                CONFIGURATION FILE"
    
    if [ -z "$parameter" ]; then
        for file in $config_files; do
            process_file "$file" ""
        done
    elif [[ $parameter =~ ^[0-9]+$ ]]; then
        for file in $config_files; do
            process_file "$file" "$parameter"
        done
    else
        echo "Searching for Nginx configuration with domain $parameter..."
        for file in $config_files; do
            process_file "$file" "$parameter"
        done
    fi
}

# completed
user_details() {
    local username=$1
    is_regular_user() {
        local uid=$(id -u "$1" 2>/dev/null)
        [[ $uid -ge 1000 ]] 2>/dev/null
    }
    if [ -z "$username" ]; then
        echo -e "USERNAME\tHOME DIRECTORY\t\t\tSHELL\t\t\tLAST LOGIN\t\t  SESSION UPTIME"
        # List all users from /etc/passwd
        local users=$(cut -d: -f1,3 /etc/passwd)
        while IFS=: read -r user uid; do
            if is_regular_user "$user"; then
                # Get user details from /etc/passwd
                local user_info=$(grep "^$user:" /etc/passwd)
                local user_home=$(echo "$user_info" | cut -d: -f6)
                local user_shell=$(echo "$user_info" | cut -d: -f7)
                # Get last login time
                local last_login=$(last -F | grep "^$user " | head -1 | awk '{print $5, $6, $7, $8}')
                if [ -z "$last_login" ]; then
                    last_login="Never logged in"
                    session_uptime="N/A"
                else
                    # Get the session uptime
                    session_uptime=$(last -F | grep "^$user " | head -1 | awk '{print $9}')
                    if [ "$session_uptime" = "still" ]; then
                        session_uptime="Still logged in"
                    elif [ "$session_uptime" = "-" ]; then
                        session_uptime="N/A"
                    fi
                fi

                printf "%-15s %-30s %-24s %-25s %-18s\n" "$user" "$user_home" "$user_shell" "$last_login" "$session_uptime"
            fi
        done <<< "$users"
    else
        if ! id "$username" &> /dev/null; then
            echo "User $username does not exist."
            return 1
        fi
        echo -e "USERNAME\tHOME DIRECTORY\t\t\tSHELL\t\t\tLAST LOGIN\t\t  SESSION UPTIME"
        # Get user details from /etc/passwd
        local user_info=$(grep "^$username:" /etc/passwd)
        local user_home=$(echo "$user_info" | cut -d: -f6)
        local user_shell=$(echo "$user_info" | cut -d: -f7)
        # Get last login time
        local last_login=$(sudo lastlog -u "$username" | tail -n 1 | awk '{print $4, $5, $6, $7, $8}')
        if [ -z "$last_login" ]; then
            last_login="Never logged in"
            session_uptime="N/A"
        else
            # Get the session uptime
            session_uptime=$(last -F | grep "^$username " | head -1 | awk '{print $9}')
            if [ "$session_uptime" = "still" ]; then
                session_uptime="Still logged in"
            fi
        fi
        printf "%-15s %-30s %-24s %-25s %-18s\n" "$username" "$user_home" "$user_shell" "$last_login" "$session_uptime"
    fi
}

# completed
display_activities() {
    local start_date="$1"
    local end_date="$2"
    local log_dir="/var/log"
    local current_log="$log_dir/devopsfetch.log"

    if [ -z "$start_date" ]; then
        start_date=$(ls "$log_dir/devopsfetch-"*.log "$log_dir/devopsfetch.log" 2>/dev/null | sort | head -n 1 | sed 's/.*devopsfetch-\?\(.*\)\.log/\1/')
    fi

    if [ -z "$end_date" ]; then
        end_date="$start_date"
    fi

    start_date="${start_date}T00:00:00"
    end_date="${end_date}T23:59:59"

    start_seconds=$(date -d "$start_date" +%s)
    end_seconds=$(date -d "$end_date" +%s)

    printf "%-20s %-20s %-50s\n" "DATE" "CATEGORY" "ACTIVITY"

    # Function to process a single log file
    process_log_file() {
        local file="$1"
        while IFS= read -r line; do
            log_date=$(echo "$line" | cut -d' ' -f1,2)
            log_seconds=$(date -d "$log_date" +%s)

            if [ $log_seconds -ge $start_seconds ] && [ $log_seconds -le $end_seconds ]; then
                category=$(echo "$line" | cut -d' ' -f4-5)
                activity=$(echo "$line" | cut -d' ' -f7- | sed 's/^[[:space:]]*//')
                printf "%-20s %-20s %-50s\n" "$log_date" "$category" "$activity"
            fi
        done < "$file"
    }

    # Process rotated log files
    for log_file in $(ls "$log_dir"/devopsfetch-*.log | sort -r); do
        process_log_file "$log_file"
    done

    # Process the current log file
    if [ -f "$current_log" ]; then
        process_log_file "$current_log"
    fi
}

format_output() {
  column -t -s $'\t'
}

print_help() {
  echo "Usage: devopsfetch [OPTION]..."
  echo "Collect and display system information."
  echo ""
  echo "Options:"
  echo "  -p, --port [PORT]         Display all active ports or information about a specific port."
  echo "  -d, --docker [CONTAINER]  List Docker images/containers or detailed information about a specific container."
  echo "  -n, --nginx [DOMAIN]      Display Nginx domains/ports or detailed information about a specific domain."
  echo "  -u, --users [USERNAME]    List all users and last login times or detailed information about a specific user."
  echo "  -t, --time START END      Display activities within the specified time range (YYYY-MM-DD)."
  echo "  --continuous              Start the DevOpsFetch monitor if it's not running."
  echo "  -h, --help                Display this help and exit."
}

start_monitor() {
    if ! systemctl is-active --quiet devopsfetch_monitor.service; then
        echo "DevOpsFetch monitor is not running. Starting it now..."
        sudo systemctl start devopsfetch_monitor.service
        if systemctl is-active --quiet devopsfetch_monitor.service; then
            echo "DevOpsFetch monitor started successfully."
        else
            echo "Failed to start DevOpsFetch monitor. Please check system logs for more information."
        fi
    else
        echo "DevOpsFetch monitor is already running."
    fi
}

case "$1" in
  -p|--port)
    get_ports "$2"
    ;;
  -d|--docker)
    get_docker_info "$2"
    ;;
  -n|--nginx)
    log_nginx_information "$2"
    ;;
  -u|--users)
    user_details "$2"
    ;;
  -t|--time)
    display_activities "$2" "$3"
    ;;
  --continuous)
    start_monitor
    ;;
  -h|--help)
    print_help
    ;;
  *)
    print_help
    ;;
esac
