#!/bin/bash

connect_and_wait() {
    profile=$(pritunl-client list | awk 'NR==4 {print $2}')
    
    # Check if the WireGuard toggle is set to true
    if [ "$USE_WIREGUARD" = "true" ]; then
        echo "Starting pritunl profile $profile in WireGuard mode"
        # The -wg flag forces WireGuard mode in the official client
        pritunl-client start $profile -wg
    else
        echo "Starting pritunl profile $profile in standard mode (OpenVPN)"
        pritunl-client start $profile
    fi

    echo "pritunl profile $profile started"
    
    # Wait for it to stop
    while [ "$(pritunl-client list | awk 'NR==4 {print $7}')" != "Inactive" ]; do
        sleep 5
    done
    echo "pritunl profile $profile stopped"
}

sleep 5

if [ "$(pritunl-client list | wc -l)" -eq 5 ]; then
    echo "pritunl profile already exists"

    connect_and_wait 
    exit 1

elif [ "$(pritunl-client list | wc -l)" -eq 4 ]; then
    if [ -z "$PRITUNL_PROFILE" ]; then
        echo "pritunl profile is not set"
        exit 1
    else
        pritunl-client add $PRITUNL_PROFILE
        connect_and_wait
    fi
else
    echo "pritunl has more than one profile / or cli changed"
    exit 1
fi
