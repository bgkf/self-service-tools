# Delete-and-Reinstall
A self service tool for non-admin end users to delete and reinstall a limited selection of applications on macOS. 

### This script is dependent on:
- [IBM Notifier](https://github.com/IBM/mac-ibm-notifications) for the popups ([Swift Dialog](https://github.com/swiftDialog/swiftDialog) also works).
- [DockUtil](https://github.com/kcrawford/dockutil) to manage the dock. 
- [Installomator](https://github.com/Installomator/Installomator) to re-install the app and notify the end user about the progess.
- Jamf for self service and to deploy everything listed above.

Big thanks to all.<br><br>

### To use the Delete and Reinstall script in your environment:
1. Change the path to the IBM Notifier.
2. Change the path to the icon.
3. Change the language in each popup.
4. Build your install policies. 
5. Edit the entries for the items in the case to match your environment.
   - appName
   - jamfPID is the ID number of the policy that does the app install.
   - appNameDock - command to find the name of an app in the dock.
<br>

### Screen Shots and description of the tool in action.<br>
1. The tool is launched from self service.<br><br>
<img width="150"  alt="DandR button" src="https://github.com/bgkf/Delete-and-Reinstall/assets/108151241/c8fb77d9-e722-4f6c-9868-ca79b4136592"><br>
3. Popup with app selector.<br>
<img width="650"  alt="DandR1" src="https://github.com/bgkf/Delete-and-Reinstall/assets/108151241/d494a0fd-f423-4050-a332-bc7a0d1a82a8"><br>
<img width="650"  alt="DandR2b" src="https://github.com/bgkf/Delete-and-Reinstall/assets/108151241/7620aaa4-204f-4121-8be7-801e6b6723a3"><br>
<img width="650"  alt="DandR3" src="https://github.com/bgkf/Delete-and-Reinstall/assets/108151241/3c5f08c8-927a-4489-bccb-95af49e81a65"><br>
5. Confirmation popup.<br>
<img width="650"  alt="DandR4" src="https://github.com/bgkf/Delete-and-Reinstall/assets/108151241/21132bad-9a23-4421-bf6c-c82e6616ed5b"><br>
6. If the app is not already installed on the computer the script will notify the end user and exit.<br>
<img width="650"  alt="DandR5" src="https://github.com/bgkf/Delete-and-Reinstall/assets/108151241/0ff9f4bd-9cb7-4d48-88c0-dc34728ffb8e"><br>
    
