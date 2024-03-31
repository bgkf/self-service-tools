#!/bin/bash

#
# Author: bgkf
#
# Display the preferred networks and remove the selected SSIDs from the list.
# 

# Variables
loggedInUser=$(stat -f%Su /dev/console)

# Function to retrieve preferred Wi-Fi networks
getPreferredNetworks() {
    networkSetupCmd="/usr/sbin/networksetup"
    networkList="/tmp/wifi_networks.txt"
    runAsUser() {
        launchctl asuser "$loggedInUser" sudo -u "$loggedInUser" "$@"
    }

    # Retrieve the list of preferred Wi-Fi networks
    runAsUser "$networkSetupCmd" -listpreferredwirelessnetworks Wi-Fi > "$networkList"

    # Extract network names
    networkNames=$(cat "$networkList" | sed -n '2,$p')

    # Print the list of preferred Wi-Fi networks
    echo "$networkNames"

    # Clean up temporary file
    rm "$networkList"
}

# Function to remove a preferred network
removePreferredNetwork() {
    networkSetupCmd="/usr/sbin/networksetup"
    runAsUser() {
        launchctl asuser "$loggedInUser" sudo -u "$loggedInUser" "$@"
    }

    # Prompt the user to select a network from the list
    selectedNetwork=$(/Library/Management/super/IBM\ Notifier.app/Contents/MacOS/IBM\ Notifier \
        -type popup \
        -title "Remove Preferred Network" \
        -subtitle "Select a network to remove from the preferred list." \
        -bar_title "Remove Preferred Network" \
        -accessory_view_type dropdown \
        -accessory_view_payload "$(getPreferredNetworks)" \
        -main_button_label "Remove" \
        -secondary_button_label "Cancel" \
        -icon_path "/path/to/your/icon.png" \
        -always_on_top)

    # Extract the selected network from the response
    selectedNetwork=$(echo "$selectedNetwork" | awk -F ': ' '{print $2}')

    if [[ -n "$selectedNetwork" ]]; then
        # Remove the selected network from the preferred list
        runAsUser "$networkSetupCmd" -removepreferredwirelessnetwork Wi-Fi "$selectedNetwork"

        # Display a confirmation message
        osascript -e "display dialog \"The network '$selectedNetwork' has been removed from the preferred list.\" buttons {\"OK\"} default button 1 with icon note with title \"Network Removed\""
    fi
}

# Display a pop-up message to the user with the current Wi-Fi network and the list of preferred Wi-Fi networks
currentNetwork=$(/usr/sbin/networksetup -getairportnetwork en0 | awk -F ": " '{print $2}')
preferredNetworks=$(getPreferredNetworks)

# Display the pop-up message with IBM Notifier
/Library/Management/super/IBM\ Notifier.app/Contents/MacOS/IBM\ Notifier \
    -type popup \
    -title "Wi-Fi Network Information" \
    -subtitle "Current Network: $currentNetwork" \
    -bar_title "Wi-Fi Network Information" \
    -accessory_view_type label \
    -accessory_view_payload "Preferred Wi-Fi Networks:\n$preferredNetworks" \
    -main_button_label "OK" \
    -secondary_button_label "Remove Network" \
    -icon_path "/path/to/your/icon.png" \
    -always_on_top

# If the "Remove Network" button is clicked, remove the selected network
buttonClicked=$?
if [ $buttonClicked -eq 2 ]; then
    removePreferredNetwork
fi

exit 0
