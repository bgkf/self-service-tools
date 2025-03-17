#! /bin/zsh

# variables
workflowURL="https://YOUR.API.ENDPOINT/invoke"
loggedInUser=$(stat -f%Su /dev/console)
IBM_Path="/PATH/TO/THE/IBM Notifier"
icon_path="/PATH/TO/YOUR/brandingimage.png"

# selection popup. set into a variable to capture the dropdown selection ordinal. 
serialNumber=$("$IBM_Path" \
-type popup \
-subtitle "Enter a serial number and click Return to:

 1.Check the Find My Mac Enabled smart group (Computers only).
 2.Check-in the Computer/Device to YOUR_INVENTORY.
 3.Delete the Computer/Device from Jamf Pro.
 4.Delete the Computer from Jamf Protect.
 5.Report errors to #it-alerts in Slack." \
-bar_title "Computer/Device Returned" \
-accessory_view_type input \
-accessory_view_payload "/required" \
-main_button_label "Return" \
-secondary_button_label "Quit" \
-icon_path "$icon_path" \
-always_on_top)

# Put the result of the button click into a variable. Return = 0. Quit = 2.
button=$?

# If the main button was clicked then continue to the confirmation popup.
if [[ $button = 0 ]]; then
	# Report to log: which button was clicked.
	printf '%b\n'
    echo "The Return button was clicked."
    echo $serialNumber
    # json data 
    data='{"serial": "'$serialNumber'"}'
    echo $data
    # send serial number to okta workflow
    /usr/bin/curl -s -X POST $workflowURL -H "Content-Type:application/json" --data "$data"

else
	# Report to log and exit.
	echo "Quit was clicked."
	exit 0
fi

exit 0
