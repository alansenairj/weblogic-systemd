# weblogic-systemd
Weblogic Cluster SystemD auto start - nodemanager and console Admin startup with OS

# WebLogic Systemd Scripts

This repository provides scripts and configuration files to manage Oracle WebLogic Server and Node Manager using `systemd` on Oracle Linux 9. The scripts allow you to start, stop, and check the status of WebLogic Server and Node Manager both at system startup and manually as the `oracle` user.

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
  - [Clone the Repository](#clone-the-repository)
  - [Create Necessary Directories](#create-necessary-directories)
  - [Copy Scripts and Configuration Files](#copy-scripts-and-configuration-files)
  - [Set Permissions](#set-permissions)
- [Configuration](#configuration)
  - [Edit `start.cfg`](#edit-startcfg)
  - [Environment Variables](#environment-variables)
- [Systemd Service Files](#systemd-service-files)
  - [Create Service Files](#create-service-files)
  - [Reload Systemd Daemon](#reload-systemd-daemon)
  - [Enable Services at Boot](#enable-services-at-boot)
- [Usage](#usage)
  - [Starting Services](#starting-services)
  - [Stopping Services](#stopping-services)
  - [Checking Status](#checking-status)
  - [Restarting Services](#restarting-services)
- [Granting Permissions to Oracle User](#granting-permissions-to-oracle-user)
- [Logs](#logs)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [License](#license)

---

## Overview

These scripts facilitate the management of WebLogic Server and Node Manager by:

- Automating startup and shutdown processes.
- Allowing the `oracle` user to control services without root privileges.
- Ensuring services start at system boot.
- Providing unified logs for easier monitoring.

---

## Prerequisites

- Oracle Linux 9
- Oracle WebLogic Server installed - fmw_12.2.1.4.0_infrastructure_Disk1_1of1
- `oracle` user with appropriate permissions
- Java Development Kit (JDK) installed
- `systemd` (default in Oracle Linux 9)

---

## Installation

### Clone the Repository

```bash
cd /home/oracle
git clone https://github.com/yourusername/weblogic-systemd-scripts.git
```

### Create Necessary Directories

```bash
# As root or using sudo
mkdir -p /var/log/weblogic
mkdir -p /var/log/nodemanager
mkdir -p /home/oracle/locks
chown -R oracle:oinstall /var/log/weblogic
chown -R oracle:oinstall /var/log/nodemanager
chown -R oracle:oinstall /home/oracle/locks
```

### Copy Scripts and Configuration Files

```bash
cp weblogic-systemd-scripts/bin/* /home/oracle/bin/
```

### Set Permissions

```bash
chmod +x /home/oracle/bin/weblogic.sh
chmod +x /home/oracle/bin/nodeman.sh
chown oracle:oinstall /home/oracle/bin/weblogic.sh
chown oracle:oinstall /home/oracle/bin/nodeman.sh
```

---

## Configuration

### Edit `start.cfg`

Update `/home/oracle/bin/start.cfg` with your specific environment settings:

```bash
# Deployment root directory
ORACLE_FMW="/u01/app/oracle/product/12.2.1.4.0"

# Domain name
DOMAIN="your_domain_name"

# Oracle user
ORACLE_OWNR="oracle"

# Lock directory
LOCK_DIR="/home/oracle/locks"

# Unified log files
LOG_FILE_NM="/var/log/nodemanager/nm.out"
LOG_FILE_WL="/var/log/weblogic/console-admin.out"

# WebLogic variables
OWL_USER="weblogic"             # WebLogic administrator username
OWL_PASSWD="your_password"      # WebLogic administrator password
OWL_DOMAIN="your_domain_name"   # Domain name

OWL_MANAGER_URL="localhost:7001"  # Admin server URL (hostname:port)
ADMIN_URL="t3://localhost:7001"

# Paths
WL_SCRIPTS="$ORACLE_FMW/wlserver/server/bin"
DOMAIN_SCRIPTS="$ORACLE_FMW/user_projects/domains/$OWL_DOMAIN/bin"
```

### Environment Variables

Ensure that the `oracle` user's environment variables are correctly set in `/home/oracle/.bash_profile`:

```bash
export ORACLE_BASE=/u01/app/oracle
export ORACLE_HOME=$ORACLE_BASE/product/12.2.1.4.0
export MW_HOME=$ORACLE_HOME
export WL_HOME=$MW_HOME/wlserver
export DOMAIN_HOME=$MW_HOME/user_projects/domains/$DOMAIN
export JAVA_HOME=/opt/java  # Update with your JDK path
export PATH=$JAVA_HOME/bin:$ORACLE_HOME/bin:$PATH
```

---

## Systemd Service Files

### Create Service Files

Create the following service files as root or using `sudo`:

#### **Node Manager Service**

Create `/etc/systemd/system/nodemanager.service`:

```ini
[Unit]
Description=WebLogic Node Manager Service
After=network.target sshd.service

[Service]
Type=simple
User=oracle
Group=oinstall
WorkingDirectory=/home/oracle/bin
ExecStart=/u01/app/oracle/product/12.2.1.4.0/user_projects/domains/satehmldomain/bin/startNodeManager.sh
ExecStop=/u01/app/oracle/product/12.2.1.4.0/user_projects/domains/satehmldomain/bin/stopNodeManager.sh

Restart=no
TimeoutStartSec=600
KillMode=process

[Install]
WantedBy=multi-user.target
```

#### **WebLogic Server Service**

Create `/etc/systemd/system/weblogic.service`:

```ini
[Unit]
Description=WebLogic Server Service
After=network.target nodemanager.service
Requires=nodemanager.service

[Service]
Type=simple
User=oracle
Group=oinstall
WorkingDirectory=/home/oracle/bin
ExecStart=/u01/app/oracle/product/12.2.1.4.0/user_projects/domains/satehmldomain/bin/startWebLogic.sh
ExecStop=/u01/app/oracle/product/12.2.1.4.0/user_projects/domains/satehmldomain/bin/stopWebLogic.sh

Restart=no
TimeoutStartSec=1200
KillMode=process

[Install]
WantedBy=multi-user.target
```

### Reload Systemd Daemon

```bash
sudo systemctl daemon-reload
```

### Enable Services at Boot

```bash
sudo systemctl enable --now nodemanager.service
sudo systemctl enable --now weblogic.service
```

---

## Usage

### Starting|Stopping NodeManager and Admin Console

Start Node Manager and WebLogic Server:

```bash
# Start Node Manager
Do not use systemD to manage start and stop on yet initialized system
Use custom scripts to do that.
Assuming you added bin/ to you PATH in bash_profile
nodemanager.sh stop|start

# Start WebLogic Server
Same thing to Admin console. Use custom script
weblogic.sh stop|start
```

### Checking Status

Check the status of the services:

```bash
sudo systemctl status weblogic.service
sudo systemctl status nodemanager.service
```

---

## Granting Permissions to Oracle User

To allow the `oracle` user to manage the services without `sudo`, you can modify the `sudoers` file.

Edit the `sudoers` file:

```bash
sudo visudo
```

Add the following lines:

```ini
oracle ALL=NOPASSWD: /bin/systemctl start nodemanager.service
oracle ALL=NOPASSWD: /bin/systemctl stop nodemanager.service
oracle ALL=NOPASSWD: /bin/systemctl status nodemanager.service
oracle ALL=NOPASSWD: /bin/systemctl restart nodemanager.service
oracle ALL=NOPASSWD: /bin/systemctl start weblogic.service
oracle ALL=NOPASSWD: /bin/systemctl stop weblogic.service
oracle ALL=NOPASSWD: /bin/systemctl status weblogic.service
oracle ALL=NOPASSWD: /bin/systemctl restart weblogic.service

or
oracle ALL=NOPASSWD: ALL

```

Now, the `oracle` user can manage the services without a password:

```bash
sudo systemctl start weblogic.service
```

---

## Logs

- **WebLogic Server Log**: `/var/log/weblogic/console-admin.out`
- **Node Manager Log**: `/var/log/nodemanager/nm.out`

Monitor logs in real-time:

```bash
tail -f /var/log/weblogic/console-admin.out
tail -f /var/log/nodemanager/nm.out
```

---

## Troubleshooting

- **Service Fails to Start**: Check the logs for error messages.
- **Permissions Issues**: Ensure all scripts and directories have the correct ownership (`oracle:oinstall`) and permissions.
- **Environment Variables**: Verify that environment variables are correctly set in `start.cfg` and `.bash_profile`.
- **Systemd Not Starting Services at Boot**: Ensure services are enabled with `systemctl enable`.

---

## Contributing

Contributions are welcome! Please submit a pull request or open an issue to discuss changes.

---

## License

This project is licensed under the MIT License.

---

## Acknowledgements

- Inspired by scripts from [wls-systemd-scripts](https://github.com/republique-et-canton-de-geneve/wls-systemd-scripts).
- Thanks to the Oracle community for support and guidance.

---

**Note**: Replace placeholder values like `your_domain_name`, `your_password`, and `yourusername` with actual values specific to your environment.
