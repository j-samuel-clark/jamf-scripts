#!/bin/zsh
#
# ABOUT THIS PROGRAM
##########################################################################################
#
#  softwareUpdate.sh
#  Created by J Samuel Clark 2 Oct 2020
#  version 1.0
#
##########################################################################################
#
#  Checks for software updates on macOS and installs them. If a restart is required, it will
#  restart the mac after completing the installs. This fixes an issue with the softwareupdate
#  tool where the --restart flag does not actually trigger a restart. The user will be prompted
#  before a restart takes place. This also takes authenticated restarts into consideration
#  When using this script within Jamf, you can set the following as input parameters:
# 
#  $4 - Organization Name (must not contain spaces, ideally all lower-case one word)
#
##########################################################################################
# System variables
##########################################################################################
orgName="$4"
orgFramework="/usr/local/"$orgName""
swuIcon="/System/Library/CoreServices/Software Update.app/Contents/Resources/SoftwareUpdate.icns"

##########################################################################################
# Defining functions
##########################################################################################
function jamfHelper () {
#Runs jamfhelper and tells the user to acknowldege the actions for reissuing a filevault key
	echo "Showing the jamfHelper dialogue"
    "/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper" \
    -windowType utility \
    -lockHUD \
    -title "Restart Required" \
    -alignHeading center \
    -description \
"Your computer must be restarted to finish updating. Please save your work and click \"Restart\".

Please allow up to 30 seconds for the restart to happen automatically." \
    -alignDescription left \
    -icon "$swuIcon" \
    -button1 "Restart" \
    -defaultButton 1
}

function helperWindow () {
	buttonChoice=$(jamfHelper)
	if [[ $buttonChoice == "0" ]]; then
		echo "User acknowledged restart"
	fi
}

function checkRestart() {
#Checks which kind of restart should be taken
	updateWithRestart=$(/usr/sbin/softwareupdate --list --all | grep "Action: restart")
	if [[ -n "$updateWithRestart" ]]; then 
		echo "A restart is required for this update"
		restartRequired="Yes"
		#Check if authenticated restart is possible
		authRestart=$(`/usr/bin/fdesetup supportsauthrestart`)
		if [[ $authRestart == "true" ]]; then
			authRestart="Yes"
		fi
	fi
}

function niceRestart () {
#Restart the computer based on type
	#Displaying restart dialogue
	helperWindow

	if [[ $authRestart == "Yes" ]]; then
		echo "An authenticated restart will take place during the update"
		sleep 5
		/usr/bin/fdesetup authrestart
	else
		echo "No authenticated restart is possible on this device"
		sleep 5
		shutdown -r now
	fi
}

function inventoryUpdater () {
#Creates a daemon which will update the jamf inventory when a user performs an update or upgrade
	local daemon="/Library/LaunchDaemons/com.$orgName.softwareupdate.plist"
	local daemonLabel="com.$orgName.softwareupdate"

	#Creating $orgNameFramework if not present
	if [[ ! -d "$orgFramework" ]] || [[ ! -d ""orgFramework"/bin" ]]; then
		echo "Creating the $orgName framework filepath"
		/bin/mkdir -p "$orgFramework"/bin
	fi

	#Writing Launch Daemon
	echo "Writing the softwareupdate daemon"
/bin/cat <<EOF > $daemon
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>com.$orgName.softwareupdate</string>
	<key>RunAtLoad</key>
	<true/>
	<key>UserName</key>
	<string>root</string>
	<key>ProgramArguments</key>
	<array>
		<string>/bin/zsh</string>
		<string>$orgFramework/bin/runRecon</string>
		<string>recon</string>
	</array>
	<key>StandardErrorPath</key>
	<string>/var/tmp/run.err</string>
	<key>StandardOutPath</key>
	<string>/var/tmp/run.out</string>
</dict>
</plist>
EOF

	#Writing runRecon executable
	echo "Writing the runRecon executable"
/bin/cat <<EOF > "$orgFramework"/bin/runRecon
#!/bin/zsh
function waitForUser() {
    dockStatus=\$( /usr/bin/pgrep -x Dock )
    while [[ "\$dockStatus" == "" ]]; do
        sleep 2
        dockStatus=\$( /usr/bin/pgrep -x Dock )
    done
    finderStatus=\$(pgrep -l "Finder")
    until [ "\$finderStatus" != "" ]; do
        sleep 10
        \$finderStatus=\$(pgrep -l "Finder")
    done
}
function waitForJSS() {
	jssAvailable=\$(/usr/local/bin/jamf checkJssConnection | grep "available")
	until [[ -n \$jssAvailable ]]; do
		echo "The JSS is unavailable, waiting"
		sleep 2
		\$jssAvailable=\$(/usr/local/bin/jamf checkJssConnection | grep "available" )
	done
	echo "The JSS is available, moving on" 
}
waitForUser
waitForJSS
/usr/local/bin/jamf recon
/bin/rm -r $orgFramework/bin/runRecon
/bin/rm -r $daemon
/bin/launchctl remove $daemonLabel
EOF
	#Setting permissions for daemon and runRecon
	/bin/chmod 644 "$daemon"
	/usr/sbin/chown root:wheel "$daemon"
	/bin/chmod 755 "$orgFramework"/bin/runRecon
	/usr/sbin/chwon root:wheel "$orgFramework"/bin/runRecon

}

##########################################################################################
# Begin - HOLD ONTO BUTTS
##########################################################################################
#Warming up
checkRestart

#Requesting and installing updates
/usr/sbin/softwareupdate --install --all

#If restart is needed, determinig which type of restart should be used
if [[ $restartRequired == "Yes" ]]; then 
	
	#Creating the inventory updater daemon
	inventoryUpdater
	
	#Performing a restart
	niceRestart &!
else 
	/usr/local/bin/jamf recon
fi

exit 0

