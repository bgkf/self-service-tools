#!/bin/bash
# SplitPDF_SelfService.sh
# Jamf Self Service script — launches the Split PDF UI for the logged-in user.
# Deploy this as a Jamf script attached to a Self Service policy.

# ── Logged-in user context ────────────────────────────────────────────────────
loggedInUser=$(stat -f%Su /dev/console)
uid=$(id -u "$loggedInUser")

runAsUser() {
    if [ "$loggedInUser" != "loginwindow" ]; then
        launchctl asuser "$uid" sudo -u "$loggedInUser" "$@"
    else
        echo "No user logged in."
        exit 1
    fi
}

# ── Preflight checks ──────────────────────────────────────────────────────────
BINARY="/usr/local/bin/splitpdf"
UI_BINARY="/Library/Management/SplitPDF/splitpdfui"

if [ ! -f "$BINARY" ]; then
    runAsUser osascript -e 'display alert "Split PDF" message "The splitpdf binary is missing. Please contact IT." as critical'
    exit 1
fi

if [ ! -f "$UI_BINARY" ]; then
    runAsUser osascript -e 'display alert "Split PDF" message "The Split PDF UI is missing. Please contact IT." as critical'
    exit 1
fi

# ── Launch UI ─────────────────────────────────────────────────────────────────
runAsUser "$UI_BINARY"