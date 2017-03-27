#!/bin/bash

# Munki App Updater
# Checks and updates munki packages
# Version 0.4
# Charlie Callow 2017

# Config
munkirepo="/net/mac-builder/var/www/html/munki_repo/"
app_name[0]="Firefox"
app_path[0]="apps/firefox"
app_name[1]="Firefox-ESR"
app_path[1]="apps/firefox-esr"

# Intro
clear
echo "-----------------------"
echo "---MUNKI APP UPDATER---"
echo "------Version 0.4------"
echo "--Charlie Callow 2017--"
echo "-----------------------"
echo ""
echo "Apps to update:"
for ((i=0; i<${#app_name[*]}; i++));
do
	echo "${app_name[i]}"
done
echo ""


# Checks version of app in Munki repo
check_version() {
	# Create an array of .pkginfo files in app directory
        # (ordered by ascending modification time)
        for dir in $(ls -tr $1/*.pkginfo); do
                files=(`basename $dir .pkginfo`)
        done

	version="${files[@]: -1}"	# access last member of array (most recent .pkginfo)
	version="${version%__*}"		# remove Munki suffixes
	version="${version//[!0-9.]/}"	# remove non-decimal characters
	echo "${version}"		# output version 
}

# Checks latest version of app available online
check_avail_version() {
	# Set correct firefox channel for lookup
	if [ "$1" == "Firefox" ]
	then
		ffchannel="latest"
	else
		ffchannel="esr-latest"
	fi
	
	# Determine latest version available to download and store version
	# string for comparison to Munki repo version
	avversion=$(wget --spider -S --max-redirect 0 "https://download.mozilla.org/?product=firefox-${ffchannel}&os=linux&lang=en-GB" 2>&1 | sed -n '/Location: /{s|.*/firefox-\(.*\)\.tar.*|\1|p;q;}')
	avversion="${avversion//[!0-9.]/}"	# remove non-decimal characters
	echo "${avversion}" # output discovered version
}

# Compares two version strings, returns 10 if they are equal, 9 if
# the 1st < 2nd and 11 if 2nd < 1st.
version_compare() {

   [ "$1" == "$2" ] && return 10

   ver1front=`echo $1 | cut -d "." -f -1`
   ver1back=`echo $1 | cut -d "." -f 2-`

   ver2front=`echo $2 | cut -d "." -f -1`
   ver2back=`echo $2 | cut -d "." -f 2-`

   if [ "$ver1front" != "$1" ] || [ "$ver2front" != "$2" ]; then
       [ "$ver1front" -gt "$ver2front" ] && return 11
       [ "$ver1front" -lt "$ver2front" ] && return 9

       [ "$ver1front" == "$1" ] || [ -z "$ver1back" ] && ver1back=0
       [ "$ver2front" == "$2" ] || [ -z "$ver2back" ] && ver2back=0
       version_compare "$ver1back" "$ver2back"
       return $?
   else
           [ "$1" -gt "$2" ] && return 11 || return 9
   fi
}    

# Edits Firefox ESR DMG to give make distinct from standard Firefox
# channel to avoid confusing Munki (renames app to "Firefox-ESR")
rename_esr() {
	# Make writable copy of DMG
	echo "Making writeable image"
	hdiutil convert ~/Downloads/"${1}"-ro.dmg -format UDRW -o ~/Downloads/"${1}"-rw.dmg
	echo ""	

	# Increase size of image to allow for app rename
	echo "Calculating image size..."
	local imgsize=`hdiutil resize -limits ~/Downloads/"${1}"-rw.dmg | tail -n1 | awk '{print $2}'`;
	echo "Image size is: ${imgsize}" 
	echo "Growing writable image..."
	imgsize=$((imgsize + 100)) # Add 100 to DMG size
	echo "Resizing to: ${imgsize}" 
	hdiutil resize -sectors ${imgsize} ~/Downloads/"${1}"-rw.dmg
	local imgsize=`hdiutil resize -limits ~/Downloads/"${1}"-rw.dmg | tail -n1 | awk '{print $2}'`;
	echo "New image size is: ${imgsize}" 
	echo ""	

	# Mount writable DMG to perform edit
	echo "Mounting image to edit..."
	hdiutil attach ~/Downloads/"${1}"-rw.dmg
	echo ""

	# Rename Firefox app
	echo "Renaming Firefox.app to Firefox-ESR.app"
	mv /Volumes/Firefox/Firefox.app /Volumes/Firefox/Firefox-ESR.app
	echo ""	

	#  Unmount DMG 
	echo "Detaching image..."
	hdiutil detach /Volumes/Firefox
	echo ""	

	# Compact image to previous size
	echo "Compacting image..."
	hdiutil resize -sectors min ~/Downloads/"${1}"-rw.dmg
	echo ""	

	# Remove original downloaded image
	echo "Removing old Read-only image..."
	rm -f ~/Downloads/"${1}"-ro.dmg
	echo ""	

	# Make new read only image from modified rw DMG
	echo "Make new read-only image..."
	hdiutil convert -format UDZO -o ~/Downloads/"${1}"-ro.dmg ~/Downloads/"${1}"-rw.dmg
	echo ""	

	# Clear up writeable DMG
	echo "Removing unneeded writable-image..."
	rm -f ~/Downloads/"${1}"-rw.dmg
	echo "Firefox ESR DMG preparation finished!"
	echo ""
}

# Downloads latest version of app and imports to Munki repo
update_app() {
	# Clear previous downloads
	echo "Deleting old downloads..."
	rm -f ~/Downloads/"${1}"-rw.dmg
	rm -f ~/Downloads/"${1}"-ro.dmg
	echo ""	

	# Download latest release of app
	echo "Downloading newer release image..."
	wget "https://download.mozilla.org/?product=firefox-${ffchannel}&os=osx&lang=en-GB" -O ~/Downloads/"${1}"-ro.dmg
	echo "${1} downloaded."
	echo ""

	# Check if Firefox ESR we are updating, if so modify DMG to rename
	# Firefox.app within to Firefox-ESR.app
	if [ "${1}" == "Firefox-ESR" ]; then
		echo "Firefox ESR DMG needs modification!"
		echo "Modifying DMG to rename Firefox.app..."
		echo ""
		rename_esr $1
	fi
	
	# Rename DMG to remove permissions suffix
	echo "Renaming DMG to ${1}.dmg..."
	mv ~/Downloads/"${1}"-ro.dmg ~/Downloads/"${1}".dmg
	echo ""

	# Import app to Munki repo
	echo "Starting Munki import..."
	/usr/local/munki/munkiimport --subdirectory="${2}" ~/Downloads/"${1}".dmg
}

# Checks existing versions of all apps in Munki repo and compare
# to the latest available release. Updates the apps when online
# version is newer than that in the repo
for ((i=0; i<${#app_name[*]}; i++));
do
	# Check version of app in Munki repo
	echo "Checking existing ${app_name[$i]} version in repo..."
	check_version "${munkirepo}pkgsinfo/${app_path[$i]}"
	echo ""

	# Check latest available version online
	echo "Checking latest online version..."
	check_avail_version "${app_name[$i]}"
	echo ""
	
	# Compare versions in Munki repo with the latest available online
	version_compare "${version}" "${avversion}"
	case "$?" in
 	"9") echo "Newer release available!"
		update_app "${app_name[$i]}" "${app_path[$i]}"	;;	# Run update process for the app
        "10") echo "Munki repo matches online. Nothing to do." ;;
        "11") echo "Munki repo has newer release. Nothing to do." ;;
  	*   ) echo "Something went wrong!";;
  	esac
	echo "${app_name[$i]} is up to date!"
	echo ""
done
echo "All apps up to date! Exiting..."
