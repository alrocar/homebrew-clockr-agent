#!/bin/bash

# Initialize VERBOSE if not set
: "${VERBOSE:=0}"

check_display_status() {
    if [ $VERBOSE -eq 1 ]; then
        echo "Checking lid state..."
        ioreg -r -k AppleClamshellState -d 4 | grep "AppleClamshellState"
        
        echo -e "\nChecking display power state..."
        display_active=$(pmset -g | grep "sleep prevented by" | wc -l)
        echo "Display active: $display_active"
        
        echo -e "\nChecking screen saver state..."
        screen_saver_active=$(osascript -e 'tell application "System Events" to get running of screen saver preferences')
        echo "Screen saver active: $screen_saver_active"
        
        echo -e "\nChecking lock screen state..."
        lock_state=$(osascript -e 'tell application "System Events" to tell process "loginwindow" to get value of UI element 1 of window 1' 2>/dev/null)
        echo "Lock screen state: $lock_state"
        
        echo -e "\nChecking idle time..."
        idle_time=$(ioreg -c IOHIDSystem | awk '/HIDIdleTime/ {print $NF/1000000000; exit}')
        echo "System idle for: ${idle_time}s"
        
        echo -e "\nStatus determination:"
    else
        display_active=$(pmset -g | grep "sleep prevented by" | wc -l)
        screen_saver_active=$(osascript -e 'tell application "System Events" to get running of screen saver preferences')
        lock_state=$(osascript -e 'tell application "System Events" to tell process "loginwindow" to get value of UI element 1 of window 1' 2>/dev/null)
        idle_time=$(ioreg -c IOHIDSystem | awk '/HIDIdleTime/ {print $NF/1000000000; exit}')
    fi

    if ioreg -r -k AppleClamshellState -d 4 | grep -q '"AppleClamshellState" = Yes'; then
        echo "Status: LOCKED (laptop lid is closed)"
        return 1
    fi
    
    if [ "$lock_state" = "missing value" ]; then
        echo "Status: LOCKED (lock screen is active)"
        return 1
    fi
    
    if [ "$screen_saver_active" = "true" ]; then
        echo "Status: LOCKED (screen saver is active)"
        return 1
    fi
    
    if [ "$display_active" -gt 0 ]; then
        echo "Status: UNLOCKED (display is on and active)"
        return 0
    else
        echo "Status: LOCKED (display is off)"
        return 1
    fi
} 