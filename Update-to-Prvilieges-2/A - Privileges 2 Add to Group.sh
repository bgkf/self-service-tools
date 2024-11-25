#! /bin/bash

#################################################################################
#																	                                        			#
# Add computer to the privileges2 static group.									                #
#																				                                        #
# Parameters 4 and 5 are the API clientID and clientSecret.						          #
#																				                                        #
#################################################################################

# Check if a parameter was set for parameter 5 and, if so, assign it to "clientID"
if [ "$4" != "" ] && [ "$clientID" == "" ]; then
clientID=$4
fi
echo $clientID

# Check if a parameter was set for parameter 6 and, if so, assign it to "clientSecret"
if [ "$5" != "" ] && [ "$clientSecret" == "" ]; then
clientSecret=$5
fi
echo $clientSecret

# loggedInUser
loggedInUser=$(stat -f%Su /dev/console)
echo $loggedInUser

# URL.
url="https://YOUR.DOMAIN.com"

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

# get the Jamf Pro computer ID using the serial number.
#id=$(/usr/bin/curl -H "Authorization: Bearer ${bearerToken}" -S "${url}/JSSResource/computers/serialnumber/${serialNumber}" -X GET | xpath -e '/computer/general/id/text()')

# id=$(/usr/bin/curl GET "$url/JSSResource/computers/serialnumber/$serialNumber" --header "Authorization: Bearer $bearerToken" | xpath -e '/computer/general/id/text()')

#echo "Jamf computer id == $id"
#       <id>$id</id>

# create the json data
json="<computer_group>
  <computer_additions>
    <computer>
      <serial_number>$serialNumber</serial_number>
    </computer>
  </computer_additions>
</computer_group>"

echo $json

# Add computer to the privileges2 static group that removes the old config profile and addes the new config profile.
curl -d "$json" -X PUT "$url/JSSResource/computergroups/id/653" -H "Authorization: Bearer ${bearerToken}" -H 'content-type: application/xml'

invalidateToken

exit 0

