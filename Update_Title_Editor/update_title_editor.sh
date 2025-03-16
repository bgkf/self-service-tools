#! /bin/zsh
# Update custom titles in title editor and patch management. 

# Jamf Title Editior Credentials
# Jamf Title Editior does not support clientID and client secret (yet). Create a unique user with very narrow privileges.
username="<USERNAME>"
password="<PASSWORD>"

# Okta workflow URL.
workflowURL="https://<YOURDOMAIN>.workflows.okta.com/api/flo/<CLIENT_ID>/invoke?clientToken=<CLIENT_TOKEN>"

# Jamf URL.
url="https://<YOURDOMAIN>.appcatalog.jamfcloud.com"

# Jamf authentication
bearerToken=""
response=$(curl -s -u "$username":"$password" "$url"/v2/auth/tokens -X POST)
bearerToken=$(echo "$response" | plutil -extract token raw -)

# function to get the latest version in patch management
currentVersion() {
	getTitle=$(curl -s -H "Authorization: Bearer ${bearerToken}" "$url"/v2/softwaretitles/$titleID -H 'content-type: application/json' -X GET)
  currentVersion=$(echo "$getTitle" | /usr/bin/jq '.currentVersion' | sed 's/\"//g')
	echo $name
  echo $currentVersion	
}

# function for updating patch management.
patchManagement() {
  echo "name: $name"
	echo "titleID: $titleID"
  echo "version: $releaseVersion"

  # get the ID of the most recent patch
	title=$(curl -s -H "Authorization: Bearer ${bearerToken}" "$url"/v2/softwaretitles/$titleID -X GET)
     
	# echo "title: $title"
	patchID=$(echo "$title" | /usr/bin/jq '.patches[0].patchId')
	echo "patchID: $patchID"
	echo " "
	echo "================================"
	echo " "

	# clone a patch - POST   
	clone=$(curl -s -H "Authorization: Bearer ${bearerToken}" "$url"/v2/patches/"$patchID"/clone -H 'content-type: application/json' -d '{"version":"'$releaseVersion'"}' -X POST)
	echo "clone: $clone"
	new_patchID=$(echo "$clone" | /usr/bin/jq '.patchId')
	echo "new_patchID: $new_patchID"

	# update the patch - PUT
	updatePatch=$(curl -s -H "Authorization: Bearer ${bearerToken}" "$url"/v2/patches/"$new_patchID" -H 'content-type: application/json' -d '{"enabled":true}' -X PUT)

  # update the software title - PUT
	updateTitle=$(curl -s -H "Authorization: Bearer ${bearerToken}" "$url"/v2/softwaretitles/$titleID -H 'content-type: application/json' -d '{"currentVersion":"'$releaseVersion'"}' -X PUT)

	# send JSON data to Okta Workflow to create Asana task
  data='[{"name": "'$name'", "titleID": "'$titleID'", "version": "'$releaseVersion'"}]'
  /usr/bin/curl -s -X POST $workflowURL -H "Content-Type:application/json" --data "$data"
}

# array of titles
titles=(chatGPT cloudBrink cursor DockUtil oktaVerify raycast tsh Warp)

for title in $titles; do
	case $title in
		chatGPT)
			name="ChatGPT"
	    titleID="11"
    	releaseVersion=$(curl -fs "https://persistent.oaistatic.com/sidekick/public/sparkle_public_appcast.xml" | xmllint --xpath 'string(//rss/channel/item/title[1])' -)
		;;
    cloudBrink)
			name="BrinkAgent"
	    titleID="6"
      releaseVersion=$(curl -sL "https://cloudbrink.com/brink-app-dl/release-notes.txt" | grep -i macos | awk '{print $3}')
		;;
		cursor)
			name="Cursor"
    	titleID="13"
      vers=$(curl -fsL https://www.cursor.com/changelog | grep -om 1 '[0-9]\.[0-9][0-9]\.x' | sed 's/x//')
	    releaseVersion=$(curl -fsL https://www.cursor.com/changelog | grep -o $vers'[0-9]\+' | tail -1)
		;;
    DockUtil)
			name="DockUtil"
	    titleID="7"
      releaseVersion=$(curl -fs "https://github.com/kcrawford/dockutil/releases" | grep "/kcrawford/dockutil/releases/tag" | awk 'NR==1{print $NF}' | sed 's/<.*//' )
		;;
		oktaVerify)
			name="Okta Varify"
			titleID="2"
	    releaseVersion=$(curl -sL https://help.okta.com/oie/en-us/content/topics/releasenotes/oie-ov-release-notes.htm#panel3 | grep -A 5 -i 'id="panel3"' | grep -i version | awk '{print $2}' | cut -d "<" -f 1)
		;;
		raycast)
    	name="Raycast"
			titleID="10"
	    releaseVersion=$(curl -fs https://www.raycast.com/changelog/feed.xml | grep "<guid>https://raycast.com//changelog/" | head -1 | cut -d "/" -f 6 | sed 's/-/./g' | sed 's/<//')
		;;
		tsh)
			name="Teleport TSH"
    	titleID="5"
	    releaseVersion=$(curl -fs https://github.com/gravitational/teleport/releases | grep -m 1 '<h2 class="sr-only" id="' | awk '{print $NF}' | sed 's/<.*//')
		;;
    Warp)
			name="Warp"
    	titleID="9"
	    releaseVersion=$(curl -fs "https://docs.warp.dev/getting-started/changelog" | grep -E -o "\-v[0-9.]*[.\d\d\"]" | head -1 | sed 's/^\-v//' | sed 's/\\//' )
		;;
	esac
  currentVersion
  # compare the current version in title editor to the latest release version from the developer
  echo "IF releaseVersion: $releaseVersion > currentVersion: $currentVersion"
	if [[ $releaseVersion > $currentVersion ]]; then
    # update title editor and create an Asana task
    patchManagement
  else
	  echo "No new version $name."
	fi
done
exit 0
