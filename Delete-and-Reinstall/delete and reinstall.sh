#! /bin/zsh

#
# Author: bgkf
#
# Allow standard end users to to delete and reinstall apps in /Applications.
#

# variables
dockutil=/usr/local/bin/dockutil
loggedInUser=$(stat -f%Su /dev/console)
uid=$(id -u "$loggedInUser")
plist="/Users/$loggedInUser/Library/Preferences/com.apple.dock.plist"
IBM_Path="/PATH/TO/IBM/NOTIFIER"
icon_path="/PATH/TO/YOUR/BRAND/ICON.png"

# functions
runAsUser() {  
  if [ "$loggedInUser" != "loginwindow" ]; then
    launchctl asuser "$uid" sudo -u "$loggedInUser" "$@"
  else
    echo "No user logged in."
    exitCode=1
    exit $exitCode
  fi
}

# selection popup. the dropdown selection ordinal is captured in the appSelection variable.
appSelection=$($IBM_Path \
-type popup \
-title "Delete and reinstall an application." \
-subtitle "Select the app from the dropdown menu, click \"Delete and Reinstall\" and then confirm in the following popup." \
-bar_title "Delete and reinstall an Application" \
-accessory_view_type dropdown \
-accessory_view_payload "/list Select Application\n1Password 8\n1Password 7\nAsana\nCloudBrink\nFigma\nLoom\nSlack\nZoom /selected 0" \
-main_button_label "Delete and Reinstall" \
-secondary_button_label "Quit" \
-icon_path $icon_path \
-always_on_top)

# Put the result of the button click into a variable. Ok = 0. Quit = 2.
button=$?

# the case is selected from the appSelection variable.
case $appSelection in
	1)
		appName="1Password.app"
		jamfPID=969
		appNameDock="1Password"			
	;;
	2)
		appName="1Password 7.app"
		jamfPID=641
		appNameDock="1Password 7"
	;;
	3)
		appName="Asana.app"
		jamfPID=642
		appNameDock="Asana"
	;;
	4)
		appName="BrinkAgent.app"
		jamfPID=1022
		appNameDock="BrinkAgent"
	;;
	5)
		appName="Figma.app"
		jamfPID=643
		appNameDock="Figma"
	;;
	6)
		appName="Loom.app"
		jamfPID=644
		appNameDock="Loom"
	;;
	7)
		appName="Slack.app"
		jamfPID=645
		appNameDock="Slack"
	;;
	8)
		appName="zoom.us.app"
		jamfPID=647
		appNameDock="zoom.us"
	;;
esac

# get the dock details and set them in variables.
appInDock=$(runAsUser "${dockutil}" --find ${appNameDock} ${plist} | cut -d ' ' -f 1-3)
appPosition=$(runAsUser "${dockutil}" --find ${appNameDock} ${plist} | cut -d ' ' -f 8)
appSection=$(runAsUser "${dockutil}" --find ${appNameDock} ${plist} | cut -d ' ' -f 5)
echo $appInDock
echo $appPosition
echo $appSection

# in the future -> check if app is active.

# If the main button was clicked then continue to the confirmation popup.
if [[ $button = 0 ]]; then
	# Report to the Jamf policy log: which button was clicked.
	printf '%b\n'
    echo "$loggedInUser Delete and Reinstall actions."
    echo "The OK button was clicked on the selection popup."			
	
    # If app selection is not "select". 
	if [[ $appSelection != 0 ]]; then
		
		# Set case from selection.
		$case = $appSelection
			
		# Report to the Jamf policy log: app name selected.
		echo "$appName was selected."
        echo "The Jamf policy ID is $jamfPID"
		echo "The app dock name is $appNameDock"
        
		# Check if selected app is installed.
		if [ ! -d /Applications/$appName ]; then
			$IBM_Path \
			-type popup \
			-title "$appName is not installed and can not be deleted." \
			-bar_title "Error" \
			-icon_path $icon_path \
			-always_on_top
			
            # Report to the Jamf policy log: The selected app is not installed.
            echo "$appName is not installed and can not be deleted." 
    		exit 0
		
		# Launch the confirmation popup.
		else            
            $IBM_Path \
			-type popup \
			-title "Click OK to delete and reinstall $appName" \
			-bar_title "Confirmation" \
			-main_button_label "OK" \
			-secondary_button_label "Quit" \
			-icon_path $icon_path \
			-always_on_top	
			
			# Put the result of the button click into a variable. Ok = 0. Quit = 2.
			button=$?
			
			# Delete and reinstall.
			if [ $button = 0 ]; then
				# Report to the Jamf policy log: which button was clicked.
				echo "The OK button was clicked on the confirmation popup"

                # Report to the Jamf policy log: app name and policy id.
    			echo "to delete $appName and reinstall with policy id $jamfPID."

				# Check if the the app is in the dock.
                if [ "$appInDock" = "$appNameDock was found" ]; then
                    echo "$appInDock in the dock in $appSection at position $appPosition."
				else
				    echo "$appName is NOT in the dock."
				fi

    			# delete and reinstall.
	            rm -R /Applications/$appName
    			jamf policy -id $jamfPID
                
                # Return the app to the dock.
                if [ "$appSection" = "persistent-apps" ]; then 
	                runAsUser "${dockutil}" --add /Applications/$appName --position $appPosition ${plist}
   					echo "$appName was added to the dock in $appSection at positon $appPosition."
            	elif [ "$appSection" = "recent-apps" ]; then
                	runAsUser "${dockutil}" --add /Applications/$appName --section $appSection --position $appPosition ${plist}
   					echo "$appName was added to the dock in $appSection at positon $appPosition."
                else
                	echo "$appName was NOT added to the dock."
				fi 
                
                # in the future -> if app was active re-launch it.
                
			else
				# Report to the Jamf policy log and exit.
				echo "Quit was clicked on the confirmation popup."
				exit 0
			fi
		fi 
	# No app was selected.
	else
		$IBM_Path \
		-type popup \
		-title "No app was selected." \
		-bar_title "Error." \
		-icon_path $icon_path \
		-always_on_top
		# Report to the Jamf policy log and exit.
		echo "No app selection was made."
		exit 0			
	fi
else
	# Report to the Jamf policy log and exit.
	echo "Quit was clicked on the selection popup."
	exit 0
fi
