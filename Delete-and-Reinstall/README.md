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
<img width="150"  alt="DandR0" src="https://github.com/bgkf/self-service-tools/assets/108151241/bc0e621a-26a2-49d5-8948-c61f118d859f"><br>
3. Popup with app selector.<br>
<img width="650"  alt="DandR1" src="https://github.com/bgkf/self-service-tools/assets/108151241/22f99619-e947-4dc8-a54c-5ccd1f509169"><br>
<img width="650"  alt="DandR2b" src="https://github.com/bgkf/self-service-tools/assets/108151241/a82a61a6-4055-40da-b145-e3fc6fbe8a1f"><br>
<img width="650"  alt="DandR3" src="https://github.com/bgkf/self-service-tools/assets/108151241/0d33748f-0374-4d7a-818e-6a2e2c4f6603"><br>
5. Confirmation popup.<br>
<img width="650"  alt="DandR4" src="https://github.com/bgkf/self-service-tools/assets/108151241/3c3fcef8-4fc0-45ef-ac09-65cb8f600aed"><br>
6. If the app is not already installed on the computer the script will notify the end user and exit.<br>
<img width="650"  alt="DandR5" src="https://github.com/bgkf/self-service-tools/assets/108151241/1dbf5b71-abd7-4083-bdbf-1069149c27ec"><br>
