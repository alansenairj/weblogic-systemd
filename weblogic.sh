#!/bin/bash
# WebLogic Control Script
# Stored at /home/oracle/bin/weblogic.sh

# Path to the configuration file
CONFIG_FILE="/home/oracle/bin/start.cfg"

# Source the configuration
if [ -f "$CONFIG_FILE" ]; then
    . "$CONFIG_FILE"
else
    echo "$CONFIG_FILE not found, exiting"
    exit 1
fi

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE_WL")"

# Ensure lock directory exists
mkdir -p "$(dirname "$LOCK_FILE_WL")"

# Trap to handle lock file cleanup on exit
trap 'rm -f "$LOCK_FILE_WL"; exit' INT TERM EXIT

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
    local timeout=600  # 10 minutes
    local waited=0
    local interval=5
    while [ $waited -lt $timeout ]; do
        # Check only new lines added after starting the server
        if tail -n +"$((initial_line + 1))" "$log_file" | grep -q "$message"; then
            return 0
        fi
        sleep $interval
        waited=$((waited + interval))
    done
    echo "Error: Timeout waiting for '$message' in $log_file"
    return 1
}

# Function to check if Node Manager is running
check_nodemanager() {
    if ! pgrep -u "$ORACLE_OWNR" -f "weblogic.NodeManager" > /dev/null; then
        echo "Warning: Node Manager is not running. Please start Node Manager before starting WebLogic Server."
    fi
}

# Function to check if WebLogic Server is already running
is_weblogic_running() {
    if pgrep -u "$ORACLE_OWNR" -f "weblogic.Server" > /dev/null; then
        return 0  # WebLogic Server is running
    else
        return 1  # WebLogic Server is not running
    fi
}

# Function to start WebLogic Server
start_weblogic() {
    print_header "Starting WebLogic Server"

    if [ -f "$LOCK_FILE_WL" ] || is_weblogic_running; then
        echo "WebLogic Server is already running."
        touch "$LOCK_FILE_WL"
        exit 0
    fi

    check_nodemanager

    # Record the initial number of lines in the log file
    local initial_line
    if [ -f "$LOG_FILE_WL" ]; then
        initial_line=$(wc -l < "$LOG_FILE_WL")
    else
        initial_line=0
    fi

    # Start the server in the background, redirect output to the log file
    "$DOMAIN_SCRIPTS/startWebLogic.sh" >> "$LOG_FILE_WL" 2>&1 &

    SERVER_PID=$!
    echo $SERVER_PID > "$LOCK_DIR/weblogic.pid"

    echo "Waiting for WebLogic Server to start..."

    # Wait for the server to start
    if wait_for "$LOG_FILE_WL" "The server started in RUNNING mode." "$initial_line"; then
        touch "$LOCK_FILE_WL"
        echo "WebLogic Server started successfully."
    else
        echo "Error: WebLogic Server failed to start."
        exit 1
    fi
}

# Function to stop WebLogic Server
stop_weblogic() {
    print_header "Stopping WebLogic Server"

    if ! is_weblogic_running; then
        echo "WebLogic Server is not running."
        rm -f "$LOCK_FILE_WL"
        exit 0
    fi

    # Run the stop script and redirect output to the log file
    "$DOMAIN_SCRIPTS/stopWebLogic.sh" >> "$LOG_FILE_WL" 2>&1

    sleep 10  # Wait for the server to shut down

    # Check if the process is still running
    if is_weblogic_running; then
        echo "WebLogic Server did not stop gracefully. Killing the process."
        pkill -u "$ORACLE_OWNR" -f "weblogic.Server"
    fi

    rm -f "$LOCK_FILE_WL"
    rm -f "$LOCK_DIR/weblogic.pid"
    echo "WebLogic Server stopped successfully."
}

# Function to check WebLogic Server status
status_weblogic() {
    print_header "WebLogic Server Status"
    if is_weblogic_running; then
        echo "WebLogic Server is running."
    else
        echo "WebLogic Server is not running."
        rm -f "$LOCK_FILE_WL"  # Remove stale lock file if necessary
    fi
}

# Function to restart WebLogic Server
restart_weblogic() {
    stop_weblogic
    start_weblogic
}

# Main script execution
case "$1" in
    start)
        start_weblogic
        ;;
    stop)
        stop_weblogic
        ;;
    status)
        status_weblogic
        ;;
    restart)
        restart_weblogic
        ;;
    *)
        echo "Usage: $0 {start|stop|status|restart}"
        exit 1
        ;;
esac

# Cleanup trap
trap - INT TERM EXIT
exit 0
