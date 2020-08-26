#!/bin/zsh
#
# Created Aug 26 2020 by J Samuel Clark
# Downloads a package to install on the user's computer
########################################################################
# About this program
#
# Variables must be defined in Jamf Pro 
# "$4" Represents the URL where the package must be downloaded
# "$5" Represents what the PKG will be named after being downloaded
#
########################################################################
downloadUrl="$4"	# The URL must return a file
pkgName="$5"	# The name of the file after it's downloaded
downloadLocation="/private/tmp"		# Where the file gets downloaded
latestPkg=""$downloadLocation"/"$pkgName".pkg"	# The location and name of the downloaded file
########################################################################

/usr/bin/curl -sL "$pkgUrl" -o "$latestPackage"

/usr/sbin/installer -pkg "$latestPackage" -target /

/bin/rm -r "$latestPackage"

exit
