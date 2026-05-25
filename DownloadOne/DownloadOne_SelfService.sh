#!/bin/bash
# DownloadOne_SelfService.sh
# Jamf Self Service script — launches the DownloadOne tool.
# Deploy this as a Jamf script attached to a Self Service policy.
# Parameter 4: OAuth2 client_id
# Parameter 5: OAuth2 client_secret
# (Parameters 1-3 are Jamf predefined: mount point, computer name, username)

BINARY="/Library/Management/DownloadOne/DownloadOne"

if [ ! -f "$BINARY" ]; then
    echo "Binary not found at $BINARY"
    exit 1
fi

export DOWNLOADONE_CLIENT_ID="$4"
export DOWNLOADONE_CLIENT_SECRET="$5"
"$BINARY"
