#!/bin/bash

authenticate_agent() {
    BREW_PREFIX=$(brew --prefix)
    config_file="$BREW_PREFIX/etc/clockr-agent/clockr-agent.cfg"

    echo "Initializing clockr-agent..."

    # Request device code
    response=$(curl -s -X POST "http://localhost:3000/api/agent/auth")
    echo "Response: $response"

    # Parse JSON using grep and sed
    device_code=$(echo $response | grep -o '"device_code":"[^"]*"' | sed 's/"device_code":"\([^"]*\)"/\1/')
    verification_uri=$(echo $response | grep -o '"verification_uri":"[^"]*"' | sed 's/"verification_uri":"\([^"]*\)"/\1/')

    if [ -z "$device_code" ]; then
        echo "Error getting device code"
        return 1
    fi

    # Open browser for authentication
    echo "Opening browser for authentication..."
    open "$verification_uri"

    # Poll for completion with timeout
    echo "Waiting for authentication..."
    attempts=0
    max_attempts=150  # 5 minutes (150 * 2 seconds)

    while [ $attempts -lt $max_attempts ]; do
        echo "Polling attempt $attempts..."
        response=$(curl -s "http://localhost:3000/api/agent/auth?code=$device_code")
        echo "Poll response: $response"
        
        status=$(echo $response | grep -o '"status":"[^"]*"' | sed 's/"status":"\([^"]*\)"/\1/')
        echo "Status: $status"
        
        if [ "$status" = "complete" ]; then
            # Parse credentials
            user_id=$(echo $response | grep -o '"user_id":"[^"]*"' | sed 's/"user_id":"\([^"]*\)"/\1/')
            token=$(echo $response | grep -o '"token":"[^"]*"' | sed 's/"token":"\([^"]*\)"/\1/')

            echo "TSM_SCREEN_USER=$user_id" > "$config_file"
            echo "TSM_TB_TOKEN=$token" >> "$config_file"
            
            # Confirm delivery
            curl -s -X POST "http://localhost:3000/api/agent/auth/$device_code/delivered"
            
            echo "Setup complete!"
            return 0
        elif [ "$status" = "expired" ]; then
            echo "Authentication expired. Please try again."
            return 1
        fi
        
        attempts=$((attempts + 1))
        if [ $attempts -eq $max_attempts ]; then
            echo "Authentication timed out. Please try again."
            return 1
        fi
        
        sleep 2
    done
} 