#!/bin/bash

check_display_status() {
    if [ $VERBOSE -eq 1 ]; then
        echo "Checking lid state..."
        ioreg -r -k AppleClamshellState -d 4 | grep "AppleClamshellState"
        
        echo -e "\nChecking display power state..."
        display_active=$(osascript -e 'tell application "System Events" to return count of desktops > 0')
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
        display_active=$(osascript -e 'tell application "System Events" to return count of desktops > 0')
        screen_saver_active=$(osascript -e 'tell application "System Events" to get running of screen saver preferences')
        lock_state=$(osascript -e 'tell application "System Events" to tell process "loginwindow" to get value of UI element 1 of window 1' 2>/dev/null)
        idle_time=$(ioreg -c IOHIDSystem | awk '/HIDIdleTime/ {print $NF/1000000000; exit}')
    fi

    # Check if locked first
    if [ "$lock_state" = "missing value" ]; then
        echo "Status: LOCKED (lock screen is active)"
        return 1
    fi
    
    if [ "$screen_saver_active" = "true" ]; then
        echo "Status: LOCKED (screen saver is active)"
        return 1
    fi
    
    # Check lid state
    if ioreg -r -k AppleClamshellState -d 4 | grep -q '"AppleClamshellState" = Yes'; then
        display_count=$(system_profiler SPDisplaysDataType | grep -c Resolution)
        if [ "$display_count" -eq 0 ]; then
            echo "Status: LOCKED (laptop lid is closed, no external display)"
            return 1
        fi
    fi

    if [ "$display_active" = "false" ]; then
        echo "Status: LOCKED (display is off)"
        return 1
    fi
    
    # If not locked, check for idle
    if [ "${idle_time%.*}" -gt 30 ]; then
        echo "Status: IDLE (${idle_time%.*}s)"
        return 2
    fi
    
    # If not locked or idle, must be active
    echo "Status: UNLOCKED (display is active)"
    return 0
} 