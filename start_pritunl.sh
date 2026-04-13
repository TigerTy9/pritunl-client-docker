#!/bin/bash

CACHE_FILE="/var/lib/pritunl-client/last_url.txt"

# Function to wait for the Pritunl background service to be ready
wait_for_service() {
    echo "Waiting for Pritunl service to generate auth key..."
    for i in {1..10}; do
        if [ -f "/var/run/pritunl.auth" ]; then
            echo "Service ready."
            return 0
        fi
        sleep 2
    done
    echo "Service failed to start in time."
    exit 1
}

connect_and_wait() {
    echo "Pre-connection cleanup: Removing any existing wg0 interface..."
    ip link delete wg0 2>/dev/null || true
    
    # Grab the first profile ID from the list
    profile=$(pritunl-client list | grep "^|" | awk 'NR==1 {print $2}')
    
    if [ -z "$profile" ]; then
        echo "Error: No profile ID found."
        exit 1
    fi

    if [ "$USE_WIREGUARD" = "true" ]; then
        echo "Starting pritunl profile $profile in WireGuard mode"
        pritunl-client start "$profile" -m wg
    else
        echo "Starting pritunl profile $profile in standard mode (OpenVPN)"
        pritunl-client start "$profile"
    fi

    echo "pritunl profile $profile started"
    
    while [ "$(pritunl-client list | grep "$profile" | awk '{print $7}')" != "Inactive" ]; do
        sleep 5
    done
}

# Start background service manually if not managed by systemd/supervisor
# (Skip this line if your Dockerfile already handles the service start)
# pritunl-client service & 

wait_for_service

# 1. More aggressive profile cleanup
# Use grep to count actual profile lines (starting with '|')
NUM_PROFILES=$(pritunl-client list | grep -c "^|" || echo 0)

URL_CHANGED=false
if [ -f "$CACHE_FILE" ]; then
    if [ "$(cat "$CACHE_FILE")" != "$PRITUNL_PROFILE" ]; then
        URL_CHANGED=true
    fi
else
    URL_CHANGED=true
fi

if [ "$URL_CHANGED" = "true" ] || [ "$NUM_PROFILES" -gt 1 ]; then
    echo "Cleaning up profiles (URL change or duplicates)..."
    pritunl-client list | grep "^|" | awk '{print $2}' | xargs -n 1 pritunl-client remove 2>/dev/null
    
    echo "Adding fresh profile..."
    pritunl-client add "$PRITUNL_PROFILE"
    echo "$PRITUNL_PROFILE" > "$CACHE_FILE"
fi

# 2. Final safety check
NUM_PROFILES=$(pritunl-client list | grep -c "^|" || echo 0)
if [ "$NUM_PROFILES" -eq 0 ]; then
    pritunl-client add "$PRITUNL_PROFILE"
fi

connect_and_wait
