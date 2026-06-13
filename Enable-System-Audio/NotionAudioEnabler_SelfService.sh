#!/bin/bash
# NotionAudioEnabler_SelfService.sh
# Jamf Self Service script — launches the NotionAudioEnabler binary
# Parameters: none required (sudoers rule handles elevation)

BINARY="/Library/Management/NotionAudioEnabler/NotionAudioEnabler"

if [ ! -f "$BINARY" ]; then
    echo "Binary not found at $BINARY"
    exit 1
fi

"$BINARY"
