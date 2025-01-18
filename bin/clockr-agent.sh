#!/bin/bash

cleanup() {
    # Kill all child processes in our process group
    pkill -P $$
    
    # Kill ourselves
    kill -9 $$
    
    exit 0
}

# Trap all termination signals
trap cleanup SIGTERM SIGINT SIGQUIT EXIT

# Source the auth script
source "$(dirname "$0")/clockr-auth.sh"

# Flag to prevent multiple cleanup calls
CLEANUP_DONE=0

previous_state="uninitialized"

# Add error handling for required commands
for cmd in osascript curl; do
    if ! command -v "$cmd" &> /dev/null; then
        log "ERROR" "Required command '$cmd' not found"
        exit 1
    fi
done

# Configuration handling
BREW_PREFIX=$(brew --prefix)
CONFIG_FILE="$BREW_PREFIX/etc/clockr-agent/clockr-agent.cfg"
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "ERROR" "Configuration file not found at $CONFIG_FILE"
    echo "ERROR" "Please create a configuration file with required variables:"
    echo "ERROR" "TSM_TB_TOKEN=your_tinybird_token"
    echo "ERROR" "TSM_TB_API=your_tinybird_api"
    echo "ERROR" "TSM_SCREEN_USER=your_username"
    exit 1
fi

source "$(dirname "$0")/clockr-log.sh"

# Set VERBOSE based on environment variable first
export VERBOSE=${VERBOSE:-0}

# Parse command line arguments (can override environment setting)
while getopts "v" opt; do
    case $opt in
        v)
            export VERBOSE=1
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            exit 1
            ;;
    esac
done

# Source the scripts with VERBOSE setting
source "$(dirname "$0")/clockr-check-display.sh"

# At the start of the script
previous_app=""
previous_window=""
previous_status=""
previous_timestamp=""
previous_domain=""
previous_tab_url=""
HOUR_IN_SECONDS=3600
MAX_DURATION=60

# Check if config exists and is not empty
source "$CONFIG_FILE" || {
    log "ERROR" "Failed to source configuration file"
    exit 1
}

if [ -z "$TSM_SCREEN_USER" ]; then
    echo "No environment variables found. Starting authentication..."
    authenticate_agent
    if [ $? -ne 0 ]; then
        echo "Authentication failed"
        exit 1
    fi
fi

while [ "$CLEANUP_DONE" -eq 0 ]; do
    source "$CONFIG_FILE" || {
        log "ERROR" "Failed to source configuration file"
        exit 1
    }
    # start_time=$(date +%s.%N)
    current_date=$(date -u +'%Y-%m-%d %H:%M:%S')

    # Store the status and return code separately
    status_output=$(VERBOSE=$VERBOSE check_display_status)
    status_code=$?

    # Now use the return code for comparisons
    if [ $status_code -eq 0 ]; then
        # UNLOCKED
        echo "Display is unlocked, tracking activity..."
        status="unlocked"
    elif [ $status_code -eq 1 ]; then
        # LOCKED
        echo "Display is locked, pausing tracking..."
        status="locked"
    elif [ $status_code -eq 2 ]; then
        # IDLE
        echo "Display is idle, tracking as idle time..."
        status="idle"
    fi

    # Status output can be used for logging
    echo "Full status: $status_output"

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
                -X POST "$TSM_TB_API/v0/events?name=events&wait=false" \
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