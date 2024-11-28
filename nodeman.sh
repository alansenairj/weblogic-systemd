#!/bin/bash
# Node Manager Control Script
# Stored at /home/oracle/bin/nodeman.sh

# Use absolute paths
CONFIG_FILE="/home/oracle/bin/start.cfg"

# Source the configuration
if [ -f "$CONFIG_FILE" ]; then
    . "$CONFIG_FILE"
else
    echo "$CONFIG_FILE not found, exiting"
    exit 1
fi

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE_NM")"

# Ensure lock directory exists
mkdir -p "$(dirname "$LOCK_FILE_NM")"

# Trap to handle cleanup on exit
trap 'rm -f "$LOCK_FILE_NM"; exit' INT TERM EXIT

# Function to print header message
print_header() {
    echo "********************************************************************************"
    echo "$1 on $(date)"
    echo "********************************************************************************"
}

# Function to wait for a specific message in the log
wait_for() {
    local log_file="$1"
    local message="$2"
    local initial_line="$3"
    local timeout=300  # Timeout set to 5 minutes
    local waited=0
    local interval=5
    while [ $waited -lt $timeout ]; do
        if tail -n +"$((initial_line + 1))" "$log_file" | grep -q "$message"; then
            return 0
        fi
        sleep $interval
        waited=$((waited + interval))
    done
    echo "Error: Timeout waiting for '$message' in $log_file"
    return 1
}

# Function to start Node Manager
start_nodemanager() {
    print_header "Starting Node Manager"

    if [ -f "$LOCK_FILE_NM" ]; then
        echo "Node Manager is already running."
        exit 0
    fi

    if pgrep -u "$ORACLE_OWNR" -f "weblogic.NodeManager" > /dev/null; then
        echo "Node Manager process is already running."
        touch "$LOCK_FILE_NM"
        exit 0
    fi

    # Record the initial number of lines in the log file
    local initial_line
    if [ -f "$LOG_FILE_NM" ]; then
        initial_line=$(wc -l < "$LOG_FILE_NM")
    else
        initial_line=0
    fi

    # Start Node Manager in the background, redirect output to the log file
    "$WL_SCRIPTS/startNodeManager.sh" >> "$LOG_FILE_NM" 2>&1 &

    NM_PID=$!
    echo $NM_PID > "$LOCK_DIR/nodemanager.pid"

    echo "Waiting for Node Manager to start..."

    # Wait for Node Manager to start
    if wait_for "$LOG_FILE_NM" "Secure socket listener started on port" "$initial_line"; then
        touch "$LOCK_FILE_NM"
        echo "Node Manager started successfully."
    else
        echo "Error: Node Manager failed to start."
        exit 1
    fi
}

# Function to stop Node Manager
stop_nodemanager() {
    print_header "Stopping Node Manager"

    if [ ! -f "$LOCK_FILE_NM" ]; then
        echo "Node Manager is not running."
        exit 0
    fi

    # Run the stop command and redirect output to the log file
    "$WL_SCRIPTS/stopNodeManager.sh" >> "$LOG_FILE_NM" 2>&1

    sleep 5  # Wait for Node Manager to stop

    # If still running, kill the process
    if pgrep -u "$ORACLE_OWNR" -f "weblogic.NodeManager" > /dev/null; then
        echo "Node Manager did not stop gracefully. Killing the process."
        pkill -u "$ORACLE_OWNR" -f "weblogic.NodeManager"
    fi

    rm -f "$LOCK_FILE_NM"
    rm -f "$LOCK_DIR/nodemanager.pid"
    echo "Node Manager stopped successfully."
}

# Function to check Node Manager status
status_nodemanager() {
    print_header "Node Manager Status"
    if pgrep -u "$ORACLE_OWNR" -f "weblogic.NodeManager" > /dev/null; then
        echo "Node Manager is running."
    else
        echo "Node Manager is not running."
        rm -f "$LOCK_FILE_NM"  # Remove stale lock file if necessary
    fi
}

# Function to restart Node Manager
restart_nodemanager() {
    stop_nodemanager
    start_nodemanager
}

# Main script execution
case "$1" in
    start)
        start_nodemanager
        ;;
    stop)
        stop_nodemanager
        ;;
    status)
        status_nodemanager
        ;;
    restart)
        restart_nodemanager
        ;;
    *)
        echo "Usage: $0 {start|stop|status|restart}"
        exit 1
        ;;
esac

# Cleanup trap
trap - INT TERM EXIT
exit 0
