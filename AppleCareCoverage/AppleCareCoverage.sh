#! /bin/zsh
# Requires IBM Notifier and JQ.
# Unfortunately your client ID and assertion are plain text.

# function to get the AppleCare coverage data.

COVERAGE () {
# request an access token

ACCESS_TOKEN=$(
curl -X POST \
-H 'Host: account.apple.com' \
-H 'Content-Type: application/x-www-form-urlencoded' \
'https://account.apple.com/auth/oauth2/token?grant_type=client_credentials&client_id=<YOUR_CLIENT_ID>&client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer&client_assertion=<YOUR_CLIENT_ASSERTION>&scope=business.api'
)

TOKEN=$(echo $ACCESS_TOKEN | /usr/bin/jq .access_token | sed 's/\"//g')

# get AppleCare Coverage

APPLECARE_COVERAGE=$(
curl -X GET \
-H "Authorization: Bearer ${TOKEN}" \
"https://api-business.apple.com/v1/orgDevices/${SERIAL_NUMBER}/appleCareCoverage"
)

# get the coverage start date, end date, status and agreement number.

START_DATE=$(echo $APPLECARE_COVERAGE | /usr/bin/jq '.data.[1].attributes.startDateTime' | sed 's/\"//g' | cut -d"T" -f1)

STATUS=$(echo $APPLECARE_COVERAGE | /usr/bin/jq '.data.[1].attributes.status' | sed 's/\"//g')

END_DATE=$(echo $APPLECARE_COVERAGE | /usr/bin/jq '.data.[1].attributes.endDateTime' | sed 's/\"//g' | cut -d"T" -f1)

AGREEMENT_NUMBER=$(echo $APPLECARE_COVERAGE | /usr/bin/jq '.data.[1].attributes.agreementNumber' | sed 's/\"//g')

echo $START_DATE \n $STATUS \n $END_DATE \n $AGREEMENT_NUMBER

/Library/Management/super/IBM\ Notifier.app/Contents/MacOS/IBM\ Notifier \
-type popup \
-subtitle "
Status: $STATUS
Start Date: $START_DATE
End Date: $END_DATE
Agreement number: $AGREEMENT_NUMBER" \
-bar_title "AppleCare Coverage for $SERIAL_NUMBER" \
-main_button_label "Quit" \
-icon_path "/Users/$loggedInUser/Library/Application Support/com.jamfsoftware.selfservice.mac/Documents/Images/brandingimage.png" \
-always_on_top
}

# selection popup. set into a variable to capture the dropdown selection ordinal. 

SERIAL_NUMBER=$(/Library/Management/super/IBM\ Notifier.app/Contents/MacOS/IBM\ Notifier \
-type popup \
-subtitle "Enter a serial number and click Return to get the AppleCare Status." \
-bar_title "AppleCare Coverage" \
-accessory_view_type input \
-accessory_view_payload "/required" \
-main_button_label "Return" \
-secondary_button_label "Quit" \
-icon_path "/Users/$loggedInUser/Library/Application Support/com.jamfsoftware.selfservice.mac/Documents/Images/brandingimage.png" \
-always_on_top)

# Put the result of the button click into a variable. Return = 0. Quit = 2.

button=$?

echo $SERIAL_NUMBER

# If the main button was clicked then continue to the confirmation popup.
if [[ $button = 0 ]]; then
	# Report to log: which button was clicked.
	printf '%b\n'
    echo "The Return button was clicked."
    echo $SERIAL_NUMBER
    COVERAGE
else
	# Report to log and exit.
	echo "Quit was clicked."
	exit 0
fi
