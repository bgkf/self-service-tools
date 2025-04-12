#!/bin/bash

# Self service tool to allow a standard user to remove SSIDs from the list of preferred networks (AKA known networks).
# Launches a pop up with a multi-select check-box, then removes the selected items.
# Will remove the active SSID. If removed and Wi-Fi is turned off the SSID will need to be re-authenticated. 
# Could be improved by adding confirmation.

# Variables
loggedInUser=$(stat -f%Su /dev/console)
uid=$(id -u "$loggedInUser")
networkSetupCmd="/usr/sbin/networksetup"
networkList="/tmp/wifi_networks.txt"
IBMNotifierPath="/Library/Management/super/IBM Notifier.app/Contents/MacOS/IBM Notifier"
logoPath="/Library/Management/super/icon-light.png"
filePath="/tmp/networks.txt"

# get hardware port for Wi-Fi
hardwarePort=$(launchctl asuser "$uid" "$networkSetupCmd" -listallhardwareports | grep -A 1 Wi-Fi | awk 'FNR==2{print $2}' )
# echo $hardwarePort

# Retrieve the list of preferred Wi-Fi networks
networks=$(launchctl asuser "$uid" "$networkSetupCmd" -listpreferredwirelessnetworks "$hardwarePort" | sed -n '2,$p' | sed 's/\t//g' | tee $filePath)
echo "networks:::$networks"
preferredNetworks=$(echo "$networks" | sed 's/$/\\n/g' | tr -d '\n')
echo "preferred networks:::$preferredNetworks"

# Function to remove a preferred network
removePreferredNetworks() {
	# this can be a multi select situation
    echo "item(s) selected from list: $Selection"
	# make the selected items an array
	selected=($Selection)
    echo "selected item(s) array: ${selected[@]}"

    # remove items from the list of preferrred networks
	for select in "${selected[@]}"; do
    	echo "item index to remove: $select"
        line=$(($select+1))
        echo "line number is $line"
        ssid=$(awk -v lineNumber="$line" 'FNR==lineNumber{print}' $filePath)
        echo "ssid to remove: $ssid"
        # remove the ssid from the preferred netowrks
        launchctl asuser "$uid" "$networkSetupCmd" -removepreferredwirelessnetwork "$hardwarePort" "$ssid"
	done
}

# Display the pop-up message with IBM Notifier
Selection=$("$IBMNotifierPath" \
    -type popup \
    -title "Wi-Fi Network Information" \
    -bar_title "Select a network(s) to remove." \
    -accessory_view_type checklist \
    -accessory_view_payload "/list $preferredNetworks" \
    -main_button_label "Remove Selected Network(s)" \
    -secondary_button_label "Cancel" \
    -icon_path "$logoPath" \
    -icon_width 35 \
    -icon_height 35 \
    -always_on_top
)

# If the "Remove Network" button is clicked, remove the selected network
buttonClicked=$?
echo "button $buttonClicked was clicked."

if [ $buttonClicked -eq 2 ]; then
	echo "Cancel was clicked."
    exit 0
else
	removePreferredNetworks
fi

exit 0
