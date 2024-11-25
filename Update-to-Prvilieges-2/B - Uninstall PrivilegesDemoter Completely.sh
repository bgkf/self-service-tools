#! /bin/zsh

# kill the privileges processes
/usr/bin/killall Privileges

# unload the launchd plist 
/bin/launchctl bootout system/blog.mostlymac.privileges.check

# declare the files array. 
declare -a files=("/private/etc/newsyslog.d/blog.mostlymac.PrivilegesDemoter.conf" \
"/Library/LaunchDaemons/blog.mostlymac.privileges.check.plist" \
"/usr/local/mostlymac" \
"/Library/Managed Preferences/blog.mostlymac.privilegesdemoter.plist")

# remove each file in files recursively.
for file in "${files[@]}"
do
	rm -R $file
done

exit 0

