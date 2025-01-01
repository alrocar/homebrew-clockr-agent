#!/bin/bash

previous_state="uninitialized"

# Add error handling for required commands
for cmd in osascript curl; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "Error: Required command '$cmd' not found"
        exit 1
    fi
done

# Configuration handling
CONFIG_FILE="${1:-./tiny-screen-monitor.cfg}"
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Error: Configuration file not found at $CONFIG_FILE"
    echo "Please create a configuration file with required variables:"
    echo "TSM_TB_TOKEN=your_tinybird_token"
    echo "TSM_SCREEN_USER=your_username"
    echo "TSM_SCREEN_SLEEP_TIME=10"
    exit 1
fi

# Setup logging
LOG_DIR="./logs"
mkdir -p "$LOG_DIR"
LOG_FILE="${LOG_DIR}/tiny-screen-monitor.log"

log() {
    local level="$1"
    local message="$2"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$level] $message" | tee -a "$LOG_FILE"
}

# Source the display status checker
source "./check_display.sh"

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

    active_app=$(osascript -e 'tell application "System Events" to get name of application processes whose frontmost is true' 2>/dev/null)
    active_tab_url=$(osascript -e 'tell application "System Events" to if (name of first application process whose frontmost is true) is "Arc" then tell application "Arc" to get URL of active tab of window 1' 2>/dev/null)
    active_domain=$(echo "$active_tab_url" | awk -F/ '{print $3}')
    echo $active_domain

    curl \
        -X POST 'https://api.tinybird.co/v0/events?name=events&wait=false' \
        -H "Authorization: Bearer $TSM_TB_TOKEN" \
        -d "{\"timestamp\":\"$current_date\",\"status\":\"$status\",\"user\":\"$TSM_SCREEN_USER\",\"duration\":$TSM_SCREEN_SLEEP_TIME,\"app\":\"$active_app\",\"domains\":[\"$active_domain\"],\"tabs\":[\"$active_tab_url\"]}" \
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