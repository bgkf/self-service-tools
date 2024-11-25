### Update the Privileges app from version 1 to version 2. ###

This is a user-initiated one-time task without IT assistance.
- I want folks to upgrade at their convenience and never not be able to use the privileges tool.

Process Overview
- Replace the old configuration profile with the new configuration profile.
- Uninstall the Privileges Demoter tool.
- Uninstall Privileges v.1
- Install Privileges v.2

Process Details
- Added a role and client in Jamf Pro with permissions limited to updating a group.
- Use the Jamf API in a shell script to add the computer executing the script to a group. 
- The group membership will remove the no longer needed Privileges Demoter configuration profile and deploy the new Privileges 2 configuration profile. 
- The second script uninstalls the Privileges Demoter tool and boots out the launchDaemon.
- The next script uninstalls the Privileges 1 app. 
- Finally the Privileges 2 app is installed and added to the dock.
<br>
<img width="1000"  alt="Privileges2-Policy_1" src="https://github.com/user-attachments/assets/67fb75c4-7c63-4bc8-be3b-25bc9a8d17f4">
