#!/bin/bash

# Enable job control and process group management
set -m

# Flag to prevent multiple cleanup calls
CLEANUP_DONE=0

# Store PID in a file for service management
PID_FILE="/opt/homebrew/var/run/tiny-screen-monitor.pid"
echo $$ > "$PID_FILE"

cleanup() {
    # Only run cleanup once
    if [ "$CLEANUP_DONE" -eq 0 ]; then
        CLEANUP_DONE=1
        log "INFO" "Shutting down tiny-screen-monitor..."
        
        # Send final event if we have previous state
        if [[ -n "$previous_timestamp" ]]; then
            current_timestamp=$(date +%s)
            duration=$((current_timestamp - previous_timestamp))
            
            # Send the final event with current duration
            curl \
                -X POST 'https://api.tinybird.co/v0/events?name=events&wait=false' \
                -H "Authorization: Bearer $TSM_TB_TOKEN" \
                -d "{\"timestamp\":\"$current_date\",\"status\":\"$previous_status\",\"user\":\"$TSM_SCREEN_USER\",\"duration\":$duration,\"app\":\"$previous_app\",\"window_title\":\"$previous_window\",\"domains\":[\"$previous_domain\"],\"tabs\":[\"$previous_tab_url\"]}" \
                -w "\n"
        fi
        
        # Kill all child processes first
        pkill -P $$ 2>/dev/null
        
        # Remove lock file
        rm -f "$LOCK_FILE"
        
        # Kill ourselves with SIGTERM first
        kill -TERM $$ 2>/dev/null || true
        
        # If we're still here after 1 second, force quit
        sleep 1
        kill -9 $$ 2>/dev/null
    fi
}

trap cleanup SIGINT SIGTERM EXIT

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

# At the start of the script
previous_app=""
previous_window=""
previous_status=""
previous_timestamp=""
previous_domain=""
previous_tab_url=""
HOUR_IN_SECONDS=3600
MAX_DURATION=60

while true; do
    source "$CONFIG_FILE" || {
        log "ERROR" "Failed to source configuration file"
        exit 1
    }
    # start_time=$(date +%s.%N)
    current_date=$(date -u +'%Y-%m-%d %H:%M:%S')

    # Use the imported check_display_status function
    if check_display_status; then
        log "INFO" "Display is unlocked"
        status="unlocked"
    else
        log "INFO" "Display is locked"
        status="locked"
    fi

    # Get active app
    active_app=$(osascript -e '
        tell application "System Events"
            # First check if there are any active screens
            set displayCount to do shell script "system_profiler SPDisplaysDataType | grep -c Resolution"
            
            if displayCount > "0" then
                # If displays are active, get the frontmost app and window title
                set frontApp to first application process whose frontmost is true
                set appName to name of frontApp
                set windowTitle to ""
                try
                    set windowTitle to name of first window of frontApp
                end try
                return appName & "|" & windowTitle
            else
                # If no displays are active, consider it locked
                return ""
            end if
        end tell
    ' 2>/dev/null)

    # Split the result into app and window title
    active_app_name=$(echo "$active_app" | cut -d'|' -f1)
    window_title=$(echo "$active_app" | cut -d'|' -f2)

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
    active_app_lower=$(echo "$active_app_name" | tr '[:upper:]' '[:lower:]')
    for browser in "${browsers[@]}"; do
        browser_lower=$(echo "$browser" | tr '[:upper:]' '[:lower:]')
        if [ "$active_app_lower" = "$browser_lower" ]; then
            case "$browser" in
                "Arc"|"Google Chrome"|"Opera"|"Brave Browser"|"Microsoft Edge"|"Vivaldi"|"Chromium")
                    active_tab_url=$(osascript -e "tell application \"System Events\" to if (name of first application process whose frontmost is true) is \"$active_app_name\" then tell application \"$active_app_name\" to get URL of active tab of window 1" 2>/dev/null)
                    ;;
                *)
                    active_tab_url=$(osascript -e "tell application \"System Events\" to if (name of first application process whose frontmost is true) is \"$active_app_name\" then tell application \"$active_app_name\" to get URL of current tab of front window" 2>/dev/null)
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

    # Calculate current duration
    current_timestamp=$(date +%s)
    if [[ -n "$previous_timestamp" ]]; then
        duration=$((current_timestamp - previous_timestamp))
    else
        duration=0
        previous_timestamp="$current_timestamp"
    fi
    
    # Send event if state changed or hourly update
    if [[ "$previous_app" != "$active_app_name" || 
          "$previous_window" != "$window_title" || 
          "$previous_status" != "$status" || 
          "$previous_domain" != "$active_domain" ||
          "$previous_tab_url" != "$active_tab_url" ||
          $duration -ge $MAX_DURATION ]]; then
        
        if [[ -n "$previous_timestamp" && $duration -gt 0 ]]; then
            # Send the previous state with its duration
            curl \
                -X POST 'https://api.tinybird.co/v0/events?name=events&wait=false' \
                -H "Authorization: Bearer $TSM_TB_TOKEN" \
                -d "{\"timestamp\":\"$current_date\",\"status\":\"$previous_status\",\"user\":\"$TSM_SCREEN_USER\",\"duration\":$duration,\"app\":\"$previous_app\",\"window_title\":\"$previous_window\",\"domains\":[\"$previous_domain\"],\"tabs\":[\"$previous_tab_url\"]}" \
                &
        fi
            
        # Reset timestamp and update all previous state
        previous_timestamp="$current_timestamp"
        previous_app="$active_app_name"
        previous_window="$window_title"
        previous_status="$status"
        previous_domain="$active_domain"
        previous_tab_url="$active_tab_url"
    fi
    
    # end_time=$(date +%s.%N)
    # execution_time=$(echo "$end_time - $start_time" | bc)
    # target_interval=2.0
    # sleep_time=$(echo "$target_interval - $execution_time" | bc)

    # echo "Sleep time: $sleep_time"
    # echo "Next start time: $next_start_time"
    # echo "End time: $end_time"
    # echo "Start time: $start_time"
    # echo "Execution time: $execution_time"
    
    # if (( $(echo "$sleep_time > 0" | bc -l) )); then
    #     sleep $sleep_time
    # else
    #     log "WARNING" "Execution time ($execution_time seconds) exceeded target interval ($target_interval seconds)"
    # fi
done