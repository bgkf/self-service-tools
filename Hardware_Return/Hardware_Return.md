### When a computer or device is returned to IT, this self-service tool will remove it from Jamf Pro and Jamf Protect and update the status in Snipe.<br>

All the work is done in the [Hardware_Return workflows](https://github.com/bgkf/Okta_Workflows/blob/e517922a887823c65a4f79fba8428fc62103f311/Hardware_Return.md).<br>

1. The API endpoint is triggered by entering a serial number into a pop-up, which is launched from self-service.<br>
2. Check if Find-My-Mac is enabled (Computers only).<br>
3. Check-in the Computer/Device in Snipe.<br>
4. Delete the Computer/Device from Jamf Pro.<br>
5. Delete the Computer from Jamf Protect.<br>
6. Send a message to Slack to report errors.<br><br>
<img width="150"  alt="returnted_0.1" src="https://github.com/user-attachments/assets/b509db39-197e-4565-89cd-871025472b4b"><br>
<img width="600"  alt="returnted_0.2" src="https://github.com/user-attachments/assets/f0c786c4-64cd-464e-9511-b6e348ef971e"><br>
