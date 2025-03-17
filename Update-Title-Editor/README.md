### Update Title Editor ###

Title editor is Jamf's tool for maintaing custom software titles in patch management.<br>
This is my method for automating the steps to update Title Editor and patch management.<br> 
Computers are added to smart groups that trigger notifications and self service updates for these software titles.<br> 
The smart group process is detailed by ScriptingOSX [here](https://scriptingosx.com/2020/06/using-installomator-with-jamf-pro/).<br>
<br>
PROCESS<br>
1. Triggered manually through self service.<br>
  a. Currently there is separate script that runs daily that notifies me when a new software version is available.<br>
  b. The scripts are very similar and, in the future, will be merged.<br> 
3. Get the latest version number from the software developer's release notes.<br>
4. Compare the latest release version to the current version in Title Editor.<br>
5. If there is a new version update Title Editor.<br>
6. Create a task to review the change in Title Editor and patch management and test the update.<br>
<br>
OKTA WORKFLOW<br>
<img width="1000"  alt="UPM.pdf" src="https://github.com/user-attachments/files/19274300/UPM.pdf"><br>
