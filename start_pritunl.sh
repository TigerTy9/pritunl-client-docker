#!/bin/bash

# Path to store the last used profile URL for comparison
CACHE_FILE="/var/lib/pritunl-client/last_url.txt"

# 1. Wait for background service to fully initialize
wait_for_service() {
    echo "Waiting for Pritunl service to generate auth key..."
    for i in {1..15}; do
        if [ -f "/var/run/pritunl.auth" ]; then
            echo "Service ready."
            return 0
        fi
        sleep 2
    done
    echo "Service failed to start in time. Check if pritunl-client service is running."
    exit 1
}

connect_and_wait() {
    # Force delete existing interface to prevent 'RTNETLINK answers: File exists'
    echo "Pre-connection cleanup: Removing any existing wg0 interface..."
    ip link delete wg0 2>/dev/null || true
    
    # Wait for database synchronization
    sleep 2

    # Robustly find the 16-character hex Profile ID
    profile=$(pritunl-client list | grep -oE '[0-9a-z]{16}' | head -n 1)
    
    if [ -z "$profile" ]; then
        echo "Error: No valid profile ID found. Current list:"
        pritunl-client list
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
    
    # Keep container alive and monitor connection status
    while [ "$(pritunl-client list | grep "$profile" | awk '{print $7}')" != "Inactive" ]; do
        sleep 5
    done
    echo "pritunl profile $profile went inactive. Restarting container..."
}

# --- Execution Starts Here ---

wait_for_service

# Determine if the profile URL provided in ENV has changed
URL_CHANGED=false
if [ -f "$CACHE_FILE" ]; then
    if [ "$(cat "$CACHE_FILE")" != "$PRITUNL_PROFILE" ]; then
        URL_CHANGED=true
    fi
else
    URL_CHANGED=true
fi

# Count actual profiles (lines starting with '|')
NUM_PROFILES=$(pritunl-client list | grep -c "^|" || echo 0)

# 2. Cleanup and Update Logic
if [ "$URL_CHANGED" = "true" ] || [ "$NUM_PROFILES" -gt 1 ]; then
    echo "Syncing state: URL changed or multiple profiles detected."
    
    # Wipe all existing profiles to ensure no duplicates
    # || true prevents script crash if a profile is already half-deleted
    pritunl-client list | grep "^|" | awk '{print $2}' | xargs -r -n 1 pritunl-client remove || true
    
    if [ -n "$PRITUNL_PROFILE" ]; then
        echo "Adding fresh pritunl profile..."
        pritunl-client add "$PRITUNL_PROFILE"
        echo "$PRITUNL_PROFILE" > "$CACHE_FILE"
        # Wait for service to register the write
        sleep 5
    else
        echo "Error: PRITUNL_PROFILE environment variable is empty."
        exit 1
    fi
fi

# 3. Final verification: If profile list is empty, add it
if [ "$(pritunl-client list | grep -c "^|")" -eq 0 ]; then
    echo "No profile detected in database. Re-adding..."
    pritunl-client add "$PRITUNL_PROFILE"
    sleep 5
fi

# 4. Connect
connect_and_wait
