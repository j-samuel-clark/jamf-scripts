#!/bin/zsh
#
# Created Aug 26 2020 by J Samuel Clark
# Downloads a DMG file to extract an app or PKG and install on the user's computer
########################################################################
# About this program
#
# Variables which must be defined in Jamf Pro 
#
# "$4" Represents the URL from where the DMG will be downloaded
# "$5" Represents what the DMG will be named after being downloaded
# "$6" The exact name of a .app file within the downloaded DMG
# "$7" The exact name of a .pkg within the downloaded DMG
#  
# NOTE: A parameter must be set in either "$6" OR "$7", the script will
# fail otherwise. Enjoy!
#
########################################################################
# Defining variables - DO NOT MODIFY
########################################################################
downloadUrl="$4"	# The URL must return a file
dmgName="$5"	# The name of the file after it's downloaded
appName="$6"	# Name of the .app file within the DMG
pkgName="$7"	# Name of the .pkg file within the DMG
downloadLocation="/private/tmp"		# Where the file gets downloaded
applicationDmg=""$downloadLocation"/"$dmgName""	# The location and name of the downloaded file
mountPoint="/Volumes/$dmgName"

# Preliminary checks
if [[ -n "$appName" ]] && [[ -z "$pkgName" ]]; then 	
	installApp="$6"
elif [[ -n "$pkgName" ]] && [[ -z "$appName" ]]; then
	installApp="$7"
elif [[ -z "$appName" ]] && [[ -z "$pkgName" ]]; then
	echo "Nothing found in parameters, exiting"
	exit 1
elif [[ -n "$appName" ]] && [[ -n "$pkgName" ]]; then 
	echo "Too many parameters set, exiting"
	exit 1
fi

########################################################################
# Begin program - HOLD ONTO BUTTS
########################################################################
# Download and mount DMG
/usr/bin/curl -sL "$downloadUrl" -o "$applicationDmg"
/usr/bin/hdiutil attach "$applicationDmg" -mountpoint "$mountPoint" -nobrowse

# Choose which installation to run
installType=$( echo "$installApp" | cut -d '.' -f2 )
case "$installType" in
	app )
		# Copying .app to /Applications folder
		echo "Copying "$appName" to Applications folder"
		if [[ -a "/Applications/"$appName"" ]]; then
			echo "Removing old instance of "$appName""
			/bin/rm -r "/Applications/"$appName""
		fi
		/bin/cp -pR ""$mountPoint"/"$appName"" /Applications
		;;

	pkg )
		# Installing .pkg within DMG to /
		echo "Installing "$pkgName""
		installer -pkg ""$mountPoint"/"$pkgName"" -target /
		;;
	* )
		echo "Nothing to install"
		;;
esac

# Cleanup
/usr/bin/hdiutil detach "$mountPoint"
/bin/rm -r "$applicationDmg"

exit