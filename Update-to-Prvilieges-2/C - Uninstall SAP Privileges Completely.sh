#! /bin/zsh

# kill the privileges processes
/usr/bin/killall Privileges

# get the logged in user
loggedInUser=$(stat -f%Su /dev/console)

# unload the launchd plist 
/bin/launchctl bootout system/corp.sap.privileges.helper

# declare the files array. 
declare -a files=("/Applications/Privileges.app" \
"/Library/LaunchDaemons/corp.sap.privileges.helper.plist" \
"/Library/PrivilegedHelperTools/corp.sap.privileges.helper" \
"/private/etc/paths.d/PrivilegesCLI" \
"/Users/$loggedInUser/Library/Containers/Privileges" \
"/Users/$loggedInUser/Library/Containers/corp.sap.privileges.*")

# remove each file in files recursively.
for file in "${files[@]}"
do
	rm -R $file
done

exit 0

