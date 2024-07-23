# DevOpsFetch

DevOpsFetch is a comprehensive system monitoring and information retrieval tool designed for DevOps engineers. It provides easy access to critical system information including active ports, Docker containers, Nginx configurations, user activities, and more.

## Table of Contents

- [DevOpsFetch](#devopsfetch)
  - [Table of Contents](#table-of-contents)
  - [Installation](#installation)
  - [Configuration](#configuration)
  - [Usage](#usage)
    - [Port Information](#port-information)
    - [Docker Information](#docker-information)
    - [Nginx Information](#nginx-information)
    - [User Information](#user-information)
    - [Activity Log](#activity-log)
    - [Continuous Monitoring](#continuous-monitoring)
  - [Logging Mechanism](#logging-mechanism)
  - [System Interaction](#system-interaction)

## Installation

To install DevOpsFetch, follow these steps:

1. Clone the repository or download the scripts (`install.sh`, `devopsfetch.sh`, and `devopsfetch_monitor.sh`) and store them in a folder.

2. Make the installation script executable:

   ```bash
   chmod +x install.sh
   ```

3. Run the installation script with root privileges:

   ```bash
   sudo ./install.sh
   ```

The installation script will:

- Install necessary dependencies (lsof, docker.io, nginx, inotify-tools, net-tools, systemd)
- Copy the DevOpsFetch script to `/usr/local/bin/devopsfetch`
- Copy the monitoring script to `/usr/local/bin/devopsfetch_monitor`
- Set up a systemd service for continuous monitoring
- Configure sudo permissions for the DevOpsFetch user

## Configuration

After installation, DevOpsFetch is ready to use. The main configuration files are:

- `/etc/systemd/system/devopsfetch_monitor.service`: Systemd service file for the monitoring service
- `/etc/sudoers.d/devopsfetch`: Sudo permissions for DevOpsFetch commands
- `/etc/sudoers.d/devopsfetch_systemd`: Sudo permissions for managing the DevOpsFetch service

You can modify these files to adjust permissions or service behavior if needed.

## Usage

DevOpsFetch can be used with various command-line flags to retrieve different types of system information.

### Port Information

To display information about active ports:

```bash
devopsfetch -p
```

```bash
devopsfetch --ports
```

To get information about a specific port:

```bash
devopsfetch -p 80
```

### Docker Information

To list all Docker images and containers:

```bash
devopsfetch -d
```

```bash
devopsfetch --docker
```

To get detailed information about a specific container:

```bash
devopsfetch -d container_name
```

### Nginx Information

To display all Nginx domains and their ports:

```bash
devopsfetch -n
```

```bash
devopsfetch --nginx
```

To get detailed configuration for a specific domain:

```bash
devopsfetch -n example.com
```

To get detailed configuration for a specific port:

```bash
devopsfetch -n 80
```

### User Information

To list all users and their last login times:

```bash
devopsfetch -u
```

```bash
devopsfetch --users
```

To get detailed information about a specific user:

```bash
devopsfetch -u username
```

### Activity Log

To display activities within a specified time range:

```bash
devopsfetch -t 2023-07-01 2023-07-31
```

If only one date is provided, it will show activities for that day:

```bash
devopsfetch -t 2023-07-01
```

### Continuous Monitoring

To start the DevOpsFetch monitor if it's not running:

```bash
devopsfetch --continuous
```

## Logging Mechanism

DevOpsFetch uses two main log files:

1. `/var/log/devopsfetch.log`: System-wide log file for the monitoring service
2. `/home/$USER/devopsfetch.log`: User-specific log file for command outputs

The monitoring service continuously logs events to `/var/log/devopsfetch.log`. This includes user activities, network port changes, Nginx configuration changes, and Docker events.

To retrieve logs, you can use standard Linux commands:

```bash
tail -f /var/log/devopsfetch.log
```

or

```bash
cat /home/$USER/devopsfetch.log | less
```

You can also use the `-t` flag with DevOpsFetch to view logs for a specific time range.

Example of a log snippet:

```plaintext
2024-07-23 15:45:23 - User Activity - User logged in: alice
2024-07-23 15:46:02 - Network Activity - Port opened: 8080 - Process: 1234/nginx
2024-07-23 15:47:15 - Docker Activity - start container 9a8b7c6d5e4f
2024-07-23 15:48:30 - Nginx Config - alice modify default in /etc/nginx/sites-enabled
2024-07-23 15:49:45 - User Activity - User switched: alice to root
2024-07-23 15:50:12 - Network Activity - Port closed: 3000 - Process: 5678/node
2024-07-23 15:51:20 - Docker Activity - stop container 1a2b3c4d5e6f
2024-07-23 15:52:05 - User Activity - User logged out: bob
2024-07-23 15:53:18 - Nginx Config - root create newsite.conf in /etc/nginx/sites-enabled
2024-07-23 15:54:30 - Network Activity - Port opened: 443 - Process: 9876/apache2
```

## System Interaction

DevOpsFetch interacts with various system components:

1. **Systemd**: Manages the DevOpsFetch monitoring service.
2. **Docker**: Retrieves container and image information.
3. **Nginx**: Monitors and retrieves configuration information.
4. **Network Stack**: Monitors active ports and services.
5. **User Management**: Retrieves user information and monitors login/logout events.

The main script (`devopsfetch.sh`) handles user interactions and information retrieval. The monitoring script (`devopsfetch_monitor.sh`) runs as a systemd service, continuously monitoring system events and logging them.

The installation script sets up necessary permissions and configurations to allow seamless interaction between these components.

DevOpsFetch uses sudo for certain operations that require elevated privileges. The sudoers configuration allows the DevOpsFetch user to run specific commands without a password prompt, balancing security with ease of use.

By leveraging these system interactions, DevOpsFetch provides a comprehensive view of your system's state and activities, making it an invaluable tool for DevOps engineers and system administrators.
