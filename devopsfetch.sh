#!/bin/bash

# create log file
USER=$(logname)
LOGFILE="/home/$USER/devopsfetch.log"
[ -f "$LOGFILE" ] || touch "$LOGFILE"

get_ports() {
  if [ -z "$1" ]; then
    sudo lsof -i -P | format_output
  else
    sudo lsof -i -P | grep ":$1" | format_output
  fi
}

get_docker_info() {
  if ! command -v docker &> /dev/null; then
    echo "Docker is not installed. Please install it and try again."
    return 1
  fi
  if [ -z "$1" ]; then
    sudo docker ps -a | format_output
    sudo docker images | format_output
  else
    sudo docker inspect "$1" | format_output
  fi
}

log_nginx_information() {
    local parameter=$1

    if ! command -v nginx &> /dev/null; then
        echo "Nginx is not installed."
        return 1
    fi

    if [ -z "$parameter" ]; then
      echo "Nginx Domains and Ports:"
      # Resolve symbolic links and search for domain and port info
      find /etc/nginx/sites-enabled -type l -exec readlink -f {} \; | while read -r file; do
        echo "Configuration file: $file"
        grep -E "server_name|listen" "$file" | grep -v '^\s*#' | awk '
            /listen/ { 
                port = $2 
            } 
            /server_name/ { 
                domain = $2 
                gsub(/;$/, "", domain) 
                if (port) {
                    printf "domain: %s; port: %s;\n", domain, port
                    port = ""
                }
            }'
      done

      return 0
    fi

    if [[ $parameter =~ ^[0-9]+$ ]]; then
        echo "Searching for Nginx configuration with port $parameter..."
        local files=$(grep -l -E "listen\s*$parameter" /etc/nginx/sites-enabled/*)

        if [ -z "$files" ]; then
            echo "No Nginx configuration found for port $parameter."
        else
            for file in $files; do
                echo ""
                echo "Configuration file: $file"
                grep -E -v '^\s*#' "$file" | grep -E "server_name|listen|root|index|ssl_certificate|ssl_certificate_key|error_log|access_log|location" | awk '
                /listen/ { 
                    printf "Port: %s\n", $2 
                }
                /root/ { 
                    printf "Root Directory: %s\n", $2 
                }
                /index/ { 
                    printf "Index Files: %s\n", $2 
                }
                /server_name/ { 
                    printf "Server Name: %s\n", $2 
                }
                /ssl_certificate / { 
                    printf "SSL Certificate: %s\n", $2 
                }
                /ssl_certificate_key/ { 
                    printf "SSL Certificate Key: %s\n", $2 
                }
                /error_log/ { 
                    printf "Error Log: %s\n", $2 
                }
                /access_log/ { 
                    printf "Access Log: %s\n", $2 
                }
                /location/ { 
                    location = $0
                    gsub(/[{};]/, "", location)
                    printf "Location Block: %s\n", location
                }'
            done
        fi
    else
        echo "Searching for Nginx configuration with domain $parameter..."
        local file=$(grep -l "server_name\s*$parameter;" /etc/nginx/sites-enabled/*)

        if [ -z "$file" ]; then
            echo "No Nginx configuration found for domain $parameter."
        else
            echo "Configuration file: $file"
            grep -E -v '^\s*#' "$file" | grep -E "server_name|listen|root|index|ssl_certificate|ssl_certificate_key|error_log|access_log|location" | awk '
        /listen/ { 
            printf "Port: %s\n", $2 
        }
        /root/ { 
            printf "Root Directory: %s\n", $2 
        }
        /index/ { 
            printf "Index Files: %s\n", $2 
        }
        /server_name/ { 
            printf "Server Name: %s\n", $2 
        }
        /ssl_certificate / { 
            printf "SSL Certificate: %s\n", $2 
        }
        /ssl_certificate_key/ { 
            printf "SSL Certificate Key: %s\n", $2 
        }
        /error_log/ { 
            printf "Error Log: %s\n", $2 
        }
        /access_log/ { 
            printf "Access Log: %s\n", $2 
        }
        /location/ { 
            location = $0
            gsub(/[{};]/, "", location)
            printf "Location Block: %s\n", location
        }'
        fi
    fi
}

user_details() {
    local username=$1

    if [ -z "$username" ]; then
echo -e "USERNAME\t\tHOME DIRECTORY\t\t\t\t\tSHELL\t\t\t\tLAST LOGIN\t\t\tSESSION UPTIME"
        echo "---------------------------------------------------------------------------------------------------------------------------------------"

        # List all users from /etc/passwd
        local users=$(cut -d: -f1 /etc/passwd)

        for user in $users; do
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
                if [ "$session_uptime" = "-" ]; then
                    session_uptime="Still logged in"
                fi
            fi

            printf "%-15s %-40s %-30s %-25s %-20s\n" "$user" "$user_home" "$user_shell" "$last_login" "$session_uptime"
        done
    else
        if ! id "$username" &> /dev/null; then
            echo "User $username does not exist."
            return 1
        fi

        echo "Details for user $username:"

        # Get user details from /etc/passwd
        local user_info=$(grep "^$username:" /etc/passwd)
        local user_home=$(echo "$user_info" | cut -d: -f6)
        local user_shell=$(echo "$user_info" | cut -d: -f7)

        # Get last login time
        local last_login=$(last -F | grep "^$username " | head -1 | awk '{print $5, $6, $7, $8}')

        if [ -z "$last_login" ]; then
            last_login="Never logged in"
            session_uptime="N/A"
        else
            # Get the session uptime
            session_uptime=$(last -F | grep "^$username " | head -1 | awk '{print $9}')
            if [ "$session_uptime" = "-" ]; then
                session_uptime="Still logged in"
            fi
        fi

        echo "Username: $username"
        echo "Home Directory: $user_home"
        echo "Shell: $user_shell"
        echo "Last Login: $last_login"
        echo "Session Uptime: $session_uptime"
    fi
}


display_activities() {
    local start_date="$1"
    local end_date="$2"
    local log_file="/var/log/devopsfetch.log"

    if [ -z "$start_date" ]; then
        start_date=$(head -n 1 "$log_file" | cut -d' ' -f1,2)
        start_date=$(date -d "$start_date" +"%Y-%m-%d")
    fi

    if [ -z "$end_date" ]; then
        end_date="$start_date"
    fi

    start_date="${start_date}T00:00:00"
    end_date="${end_date}T23:59:59"

    start_seconds=$(date -d "$start_date" +%s)
    end_seconds=$(date -d "$end_date" +%s)

    echo "Activities from $start_date to $end_date:"
    echo "----------------------------------------"

    while IFS= read -r line; do
        # Extract the timestamp from the log entry
        log_date=$(echo "$line" | cut -d' ' -f1,2)
        log_seconds=$(date -d "$log_date" +%s)

        # Check if the log entry is within the specified time range
        if [ $log_seconds -gt $start_seconds ] && [ $log_seconds -lt $end_seconds ]; then
            echo "$line"
        fi
    done < "$log_file"
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
