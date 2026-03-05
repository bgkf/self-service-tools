### Delete-and-Reinstall - The Swift Version
A self service tool for non-admin end users to delete and reinstall a limited selection of applications on macOS. 

**This script is dependent on:**
- [IBM Notifier](https://github.com/IBM/mac-ibm-notifications) for the popups ([Swift Dialog](https://github.com/swiftDialog/swiftDialog) also works).
- [DockUtil](https://github.com/kcrawford/dockutil) to manage the dock. 
- [Installomator](https://github.com/Installomator/Installomator) to re-install the app and notify the end user about the progess.
- Jamf for self service and to deploy everything listed above.

Big thanks to all.<br><br>

**To use the Delete and Reinstall script in your environment:**
1. Change the path to the IBM Notifier.
2. Change the path to the icon.
3. Change the language in each popup.
4. Build your install policies. 
5. Edit the entries for the items in the case to match your environment.
   - appName
   - jamfPID is the ID number of the policy that does the app install.
   - appNameDock - command to find the name of an app in the dock.
<br>

**Screen Shots and description of the tool in action.**<br>
Popup with app selector.<br>
<img width="300" alt="Screenshot 2026-03-03 at 11 33 42 AM" src="https://github.com/user-attachments/assets/db04088c-37d6-42bd-8e25-4fb2adbb35c2" />
<br>
<img width="300" alt="Screenshot 2026-03-03 at 11 33 01 AM" src="https://github.com/user-attachments/assets/8021fe5d-5759-48e3-8d86-b35aa9f42bc7" />
<br>
Confirmation popup.<br>
<img width="300" alt="Screenshot 2026-03-03 at 11 33 54 AM" src="https://github.com/user-attachments/assets/47357f20-f1bc-4bc8-a596-fc06d0b39187" />


