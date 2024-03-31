#!/bin/bash
#################################################################################
#                                                                               #
# Author: bgkf                                                                  #
#                                                                               #
# Upload a file to the computer inventory record in Jamf.                       #
#                                                                               #
# Inside the Script payload of the Policy:                                      #
#                                                                               #
# Parameter 4 = the file path if the file is in the user's home directory.      #
#	- Excluding /Users/$loggedInUser                                              #
#	- example: only enter /Downloads/fileName                                     #
#                                                                               #
# Parameter 5 = the file path if the file is not in the user's home directory.  #
#                                                                               #
# Parameters 6 and 7 are the API clientID and clientSecret.                     #
#                                                                               #
#################################################################################

# variables

# Check if a parameter was set for parameter 4 and, if so, assign it to "fileName". 
# Then get the logged in user and create the filepath.
if [ "$4" != "" ] && [ "$fileName" == "" ]; then
fileName=$4
# loggedInUser
loggedInUser=$(stat -f%Su /dev/console)
echo $loggedInUser
# file path
filepath="/Users/$loggedInUser$fileName"
fi
echo $fileName
echo $filepath

# Check if a parameter was set for parameter 5 and, if so, assign it to "filepath"
if [ "$5" != "" ] && [ "$path" == "" ]; then
filepath=$5
fi
echo $filepath

# Check if a parameter was set for parameter 5 and, if so, assign it to "clientID"
if [ "$6" != "" ] && [ "$clientID" == "" ]; then
clientID=$6
fi
echo $clientID

# Check if a parameter was set for parameter 6 and, if so, assign it to "clientSecret"
if [ "$7" != "" ] && [ "$clientSecret" == "" ]; then
clientSecret=$7
fi
echo $clientSecret

# URL.
url="https://<YOUR_DOMAIN>.jamfcloud.com"

# Find the device serial number.
serialNumber=$(system_profiler SPHardwareDataType | awk '/Serial/ {print $4}')
echo $serialNumber

bearerToken=""

tokenExpirationEpoch="0"

#getBearerToken() {
    response=$(curl --silent --location --request POST "$url/api/oauth/token" --header "Content-Type: application/x-www-form-urlencoded" --data-urlencode "client_id=${clientID}" --data-urlencode "grant_type=client_credentials" --data-urlencode "client_secret=${clientSecret}")
	bearerToken=$(echo "$response" | plutil -extract access_token raw -)
	tokenExpiration=$(echo "$response" | plutil -extract expires raw - | awk -F . '{print $1}')
#}

invalidateToken() {
	responseCode=$(curl -w "%{http_code}" -H "Authorization: Bearer ${bearerToken}" $url/api/v1/auth/invalidate-token -X POST -s -o /dev/null)
	if [[ ${responseCode} == 204 ]]
	then
		echo "Token successfully invalidated"
		bearerToken=""
		tokenExpirationEpoch="0"
	elif [[ ${responseCode} == 401 ]]
	then
		echo "Token already invalid"
	else
		echo "An unknown error occurred invalidating the token"
	fi
}

echo $url
echo "Authorization: Bearer $bearerToken"

# getBearerToken
# get the Jamf Pro computer ID using the serial number.
id=$(/usr/bin/curl -H "Authorization: Bearer $bearerToken" -S "$url"/JSSResource/computers/serialnumber/$serialNumber -X GET | xpath -e '/computer/general/id/text()')
echo "Jamf computer id == $id"

# Upload the file to the device inventory record.
# first curl requires username and password 
# curl -H "Authorization: Bearer $bearerToken" $url/JSSResource/fileuploads/computers/id/$id -F name=@$path -X POST

curl --request POST "$url/api/v1/computers-inventory/$id/attachments" --header "Authorization: Bearer $bearerToken" --header 'content-type: multipart/form-data' --form file=@"$filepath"

# invalidateToken

exit 0
