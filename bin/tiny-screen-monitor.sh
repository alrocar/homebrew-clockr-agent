#!/bin/bash

# Enable debug mode and output to both console and log file
exec 1> >(tee -a "/opt/homebrew/var/log/tiny-screen-monitor/debug.log")
exec 2>&1

echo "=== Starting tiny-screen-monitor with debug logging ==="
date

# Enable verbose bash debugging
set -x

# Define lock file
LOCK_FILE="/tmp/tiny-screen-monitor.lock"

# More specific process checking
check_running_processes() {
    echo "Checking for other instances..."
    # Get current PID and PPID (parent process ID)
    CURRENT_PID=$$
    PARENT_PID=$PPID
    
    # Find tiny-screen-monitor processes excluding:
    # - current process
    # - parent process
    # - grep process
    # - processes that are children of current process
    RUNNING_PROCESSES=$(ps -ef | 
        grep -E "tiny-screen-monitor(\.sh)?$" | 
        grep -v grep | 
        grep -v $CURRENT_PID | 
        grep -v $PARENT_PID | 
        grep -v "ppid=$CURRENT_PID")
    
    if [ ! -z "$RUNNING_PROCESSES" ]; then
        echo "Other instances are running:"
        echo "$RUNNING_PROCESSES"
        echo "Terminating them..."
        
        # Extract PIDs and kill only those specific processes
        echo "$RUNNING_PROCESSES" | awk '{print $2}' | xargs kill 2>/dev/null
        sleep 1
    else
        echo "No other instances found."
    fi
}

# Run process check at start
check_running_processes

# Check if the script is already running
if [ -f "$LOCK_FILE" ]; then
    # Check if the process is actually running
    OLD_PID=$(cat "$LOCK_FILE")
    if ps -p "$OLD_PID" > /dev/null 2>&1; then
        echo "Process is already running with PID $OLD_PID"
        exit 1
    else
        # Process not running but lock file exists - remove it
        rm -f "$LOCK_FILE"
    fi
fi

# Create lock file with current PID
echo $$ > "$LOCK_FILE"

# Cleanup lock file on script exit
trap "rm -f $LOCK_FILE" EXIT

# Trap Ctrl+C and cleanup
cleanup() {
    log "INFO" "Shutting down tiny-screen-monitor..."
    exit 0
}

trap cleanup SIGINT

previous_state="uninitialized"

# Add error handling for required commands
for cmd in osascript curl; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "ERROR" "Required command '$cmd' not found"
        exit 1
    fi
done

# Configuration handling
BREW_PREFIX=$(brew --prefix)
CONFIG_FILE="${1:-$BREW_PREFIX/etc/tiny-screen-monitor/tiny-screen-monitor.cfg}"
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "ERROR" "Configuration file not found at $CONFIG_FILE"
    echo "ERROR" "Please create a configuration file with required variables:"
    echo "ERROR" "TSM_TB_TOKEN=your_tinybird_token"
    echo "ERROR" "TSM_SCREEN_USER=your_username"
    echo "ERROR" "TSM_SCREEN_SLEEP_TIME=10"
    exit 1
fi

# Setup logging using Homebrew's var directory
LOG_DIR="$BREW_PREFIX/var/log/tiny-screen-monitor"
LOG_FILE="${LOG_DIR}/tiny-screen-monitor.log"

# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR"

log() {
    local level="$1"
    local message="$2"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$level] $message" | tee -a "$LOG_FILE"
}

# Source the display status checker from Homebrew's bin directory
source "$BREW_PREFIX/bin/check_display.sh"

check_and_request_permissions() {
    echo "Checking System Events permissions..."
    
    # Try to access System Events
    if ! osascript -e 'tell application "System Events" to get name of every process' 2>/dev/null; then
        echo "ERROR: Missing System Events permissions"
        
        # Show notification to user
        osascript -e 'display notification "Please grant Accessibility permissions to tiny-screen-monitor in System Settings → Privacy & Security → Accessibility" with title "tiny-screen-monitor needs permissions"'
        
        # Open System Settings to the right place
        open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        
        echo "Please grant permissions to:"
        echo "1. /opt/homebrew/bin/tiny-screen-monitor"
        echo "2. /opt/homebrew/opt/tiny-screen-monitor/bin/tiny-screen-monitor"
        
        # Wait for permissions
        while ! osascript -e 'tell application "System Events" to get name of every process' 2>/dev/null; do
            echo "Waiting for permissions..."
            sleep 5
        done
        
        echo "Permissions granted!"
    fi
}

# Run permission check before starting
check_and_request_permissions

echo "Starting main monitoring loop..."

while true; do
    source "$CONFIG_FILE" || {
        log "ERROR" "Failed to source configuration file"
        exit 1
    }
    start_time=$(date +%s)
    current_date=$(date -u +'%Y-%m-%d %H:%M:%S')

    # Use the imported check_display_status function
    if check_display_status; then
        log "INFO" "Display is unlocked"
        status="unlocked"
    else
        log "INFO" "Display is locked"
        status="locked"
    fi

    # Get active application and window title
    active_app_info=$(osascript -e '
        tell application "System Events"
            set frontApp to first application process whose frontmost is true
            set appName to name of frontApp
            set windowTitle to ""
            try
                set windowTitle to name of first window of frontApp
            end try
            return appName & "|" & windowTitle
        end tell
    ')

    # Split the result
    active_app=$(echo "$active_app_info" | cut -d'|' -f1)
    window_title=$(echo "$active_app_info" | cut -d'|' -f2)

    # Get URL if active app is a browser
    active_tab_url=""
    # List of known browsers
    browsers=(
        "Arc" 
        "Safari" 
        "Google Chrome" 
        # "Firefox" 
        "Opera" 
        # "DuckDuckGo" 
        "Brave Browser" 
        # "Min" 
        "Microsoft Edge" 
        "Vivaldi"
        "Chromium"
        # "Tor Browser"
    )
    
    # Check if active_app is in the browsers list (case-insensitive)
    active_app_lower=$(echo "$active_app" | tr '[:upper:]' '[:lower:]')
    for browser in "${browsers[@]}"; do
        browser_lower=$(echo "$browser" | tr '[:upper:]' '[:lower:]')
        if [ "$active_app_lower" = "$browser_lower" ]; then
            case "$browser" in
                "Arc"|"Google Chrome"|"Opera"|"Brave Browser"|"Microsoft Edge"|"Vivaldi"|"Chromium")
                    active_tab_url=$(osascript -e "tell application \"System Events\" to if (name of first application process whose frontmost is true) is \"$active_app\" then tell application \"$active_app\" to get URL of active tab of window 1" 2>/dev/null)
                    ;;
                *)
                    active_tab_url=$(osascript -e "tell application \"System Events\" to if (name of first application process whose frontmost is true) is \"$active_app\" then tell application \"$active_app\" to get URL of current tab of front window" 2>/dev/null)
                    ;;
            esac
            break
        fi
    done
    
    # Extract domain if URL exists
    active_domain=""
    if [ -n "$active_tab_url" ]; then
        active_domain=$(echo "$active_tab_url" | awk -F/ '{print $3}')
        log "INFO" "Active domain: $active_domain"
    fi
    echo $active_domain

    curl \
        -X POST 'https://api.tinybird.co/v0/events?name=events&wait=false' \
        -H "Authorization: Bearer $TSM_TB_TOKEN" \
        -d "{\"timestamp\":\"$current_date\",\"status\":\"$status\",\"user\":\"$TSM_SCREEN_USER\",\"duration\":$TSM_SCREEN_SLEEP_TIME,\"app\":\"$active_app\",\"domains\":[\"$active_domain\"],\"tabs\":[\"$active_tab_url\"],\"window_title\":\"$window_title\"}" \
        &

    end_time=$(date +%s)
    execution_time=$((end_time - start_time))
    next_start_time=$((start_time + TSM_SCREEN_SLEEP_TIME))
    sleep_time=$((next_start_time - end_time))

    if [ "$sleep_time" -gt 0 ]; then
        sleep $sleep_time
    else
        echo "Warning: Execution time exceeded sleep time"
    fi
done