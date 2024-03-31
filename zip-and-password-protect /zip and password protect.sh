#! /bin/zsh

#
# Author: bgkf
#
# enter a password or phrase
# drag and drop a file to get file path
# password protect and zip a file 
# 

# password popup
password=$(osascript -e 'set theResponse to display dialog "Enter a password." default answer "" with icon note buttons {"Cancel", "Enter"} default button "Enter"
--> {button returned:"Enter", text returned:""}')

echo $result

# variables
passButton=$(echo $password | cut -d "," -f 1 | cut -d ":" -f 2 )
pass=$(echo $password | cut -d "," -f 2 | cut -d ":" -f 2 )
echo $passwordButton
echo $pass

# Check which button was clicked. Return the file path if zip was clicked. 
if [[ $passButton = "Enter" ]]; then
	# Report to log: which button was clicked.
    echo "The Enter button was clicked."
    echo $passButton
	if [[ $pass = "" ]]; then
    	echo "The filePath is NULL."
    	# notify the end user and exit.
    	osascript -e 'set theResponse to display dialog "There was a problem with the password. Please try again." with icon note buttons {"Exit"} default button "Exit"'
		exit 0
	fi
else
	echo "The cancel button was clicked."
    echo $zipButton
    exit 0
fi

# drag and drop file popup
result=$(osascript -e 'set theResponse to display dialog "Drag and drop a file to zip and protect with a password." default answer "" with icon note buttons {"Cancel", "Zip"} default button "Zip"
--> {button returned:"Zip", text returned:""}')
    
echo $result

# variables
zipButton=$(echo $result | cut -d "," -f 1 | cut -d ":" -f 2 )
filePath=$(echo $result | cut -d "," -f 2 | cut -d ":" -f 2 )
echo $button
echo $filePath

zipPath=$(echo $filePath | sed 's/\.*$/zip' | sed 's/.*\///')

# Check which button was clicked. Return the file path if zip was clicked. 
if [[ $zipButton = "Zip" ]]; then
	# Report to log: which button was clicked.
    echo "The zip button was clicked."
    echo $zipButton
    echo $filePath
    if [[ $filePath = "" ]]; then
    	echo "The filePath is NULL."
        # notify the end user and exit.
        osascript -e 'set theResponse to display dialog "There was a problem with the file path. Please try again." with icon note buttons {"Exit"} default button "Exit"'
        exit 0
	fi
    # zip and encrypt. save to the same dir with .zip appended to file name.
    /usr/bin/zip -P "$pass" "$filePath.zip" -jr "$filePath"
else
	echo "The cancel button was clicked."
    echo $zipButton
fi

exit 0
