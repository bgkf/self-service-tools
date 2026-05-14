#!/bin/bash
# DeleteReinstall_SelfService.sh
# Jamf Self Service script — launches the Delete & Reinstall tool.
# Deploy this as a Jamf script attached to a Self Service policy.
# Runs as root; the binary handles user-context commands internally.

BINARY="/Library/Management/DeleteReinstall/delete-reinstall"

if [ ! -f "$BINARY" ]; then
    echo "Binary not found at $BINARY"
    exit 1
fi

"$BINARY"
