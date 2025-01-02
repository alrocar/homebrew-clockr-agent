#!/bin/bash

# Define lock file
LOCK_FILE="/tmp/tiny-screen-monitor.lock"

# Check for other instances using the process name
RUNNING_PROCESSES=$(pgrep -fl tiny-screen-monitor | grep -v $$)
if [ ! -z "$RUNNING_PROCESSES" ]; then
    echo "Other instances are running:"
    echo "$RUNNING_PROCESSES"
    echo "Terminating them..."
    pkill -f tiny-screen-monitor
    sleep 1
fi

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