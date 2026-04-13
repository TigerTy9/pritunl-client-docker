#!/bin/bash

# Path to store the last used profile URL for comparison
CACHE_FILE="/var/lib/pritunl-client/last_url.txt"

connect_and_wait() {
    profile=$(pritunl-client list | awk 'NR==4 {print $2}')
    
    if [ "$USE_WIREGUARD" = "true" ]; then
        echo "Starting pritunl profile $profile in WireGuard mode"
        pritunl-client start $profile -m wg
    else
        echo "Starting pritunl profile $profile in standard mode (OpenVPN)"
        pritunl-client start $profile
    fi

    echo "pritunl profile $profile started"
    
    while [ "$(pritunl-client list | awk 'NR==4 {print $7}')" != "Inactive" ]; do
        sleep 5
    done
    echo "pritunl profile $profile stopped"
}

sleep 5

# Check if we need to force an update because the URL changed
FORCE_UPDATE=false
if [ -f "$CACHE_FILE" ]; then
    LAST_URL=$(cat "$CACHE_FILE")
    if [ "$LAST_URL" != "$PRITUNL_PROFILE" ]; then
        echo "Detected profile URL change. Removing old profile..."
        # Get the ID of the existing profile and remove it
        OLD_ID=$(pritunl-client list | awk 'NR==4 {print $2}')
        if [ ! -z "$OLD_ID" ]; then
            pritunl-client remove $OLD_ID
        fi
        FORCE_UPDATE=true
    fi
else
    FORCE_UPDATE=true
fi

# Logic to add/start
if [ "$(pritunl-client list | wc -l)" -eq 5 ] && [ "$FORCE_UPDATE" = "false" ]; then
    echo "pritunl profile already exists and URL has not changed."
    connect_and_wait 
    exit 1
else
    if [ -z "$PRITUNL_PROFILE" ]; then
        echo "pritunl profile is not set"
        exit 1
    else
        echo "Adding/Updating pritunl profile..."
        pritunl-client add "$PRITUNL_PROFILE"
        # Save the new URL to the cache file
        echo "$PRITUNL_PROFILE" > "$CACHE_FILE"
        connect_and_wait
    fi
fi
