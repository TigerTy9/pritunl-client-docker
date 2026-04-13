#!/bin/bash

# Path to store the last used profile URL for comparison
CACHE_FILE="/var/lib/pritunl-client/last_url.txt"

connect_and_wait() {
    # Always grab the first available profile ID from the list (Line 4)
    profile=$(pritunl-client list | awk 'NR==4 {print $2}')
    
    if [ -z "$profile" ]; then
        echo "Error: No profile ID found to start."
        exit 1
    fi

    if [ "$USE_WIREGUARD" = "true" ]; then
        echo "Starting pritunl profile $profile in WireGuard mode"
        pritunl-client start $profile -m wg
    else
        echo "Starting pritunl profile $profile in standard mode (OpenVPN)"
        pritunl-client start $profile
    fi

    echo "pritunl profile $profile started"
    
    # Monitor the specific profile we started
    while [ "$(pritunl-client list | grep "$profile" | awk '{print $7}')" != "Inactive" ]; do
        sleep 5
    done
    echo "pritunl profile $profile stopped"
}

sleep 5

# 1. Check for URL change
URL_CHANGED=false
if [ -f "$CACHE_FILE" ]; then
    LAST_URL=$(cat "$CACHE_FILE")
    if [ "$LAST_URL" != "$PRITUNL_PROFILE" ]; then
        echo "Detected profile URL change."
        URL_CHANGED=true
    fi
else
    URL_CHANGED=true
fi

# 2. Check for Duplicates (If line count > 5, we have more than 1 profile)
NUM_PROFILES=$(pritunl-client list | grep -c "^|" || echo 0)
# Note: pritunl-client list has 3 lines of header, so 1 profile = 4 lines total in some versions, 
# but checking for the table separator "|" is safer.

if [ "$URL_CHANGED" = "true" ] || [ "$NUM_PROFILES" -gt 1 ]; then
    echo "Cleaning up profiles (URL changed or duplicates found)..."
    # Remove every profile currently in the client
    pritunl-client list | awk 'NR>3 {print $2}' | xargs -n 1 pritunl-client remove 2>/dev/null
    
    if [ -z "$PRITUNL_PROFILE" ]; then
        echo "PRITUNL_PROFILE is empty. Nothing to add."
        exit 1
    fi

    echo "Adding fresh pritunl profile..."
    pritunl-client add "$PRITUNL_PROFILE"
    echo "$PRITUNL_PROFILE" > "$CACHE_FILE"
fi

# 3. Final safety check: If for some reason we have 0 profiles now, add it.
if [ "$(pritunl-client list | wc -l)" -lt 5 ]; then
    echo "No profile found. Adding..."
    pritunl-client add "$PRITUNL_PROFILE"
    echo "$PRITUNL_PROFILE" > "$CACHE_FILE"
fi

# 4. Connect
connect_and_wait
