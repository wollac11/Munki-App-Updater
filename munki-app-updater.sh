#!/bin/bash

# Munki App Updater
# Checks and updates munki packages
# Version 1.0
# Charlie Callow 2017

# Config
munkirepo="/net/mac-builder/var/www/html/munki_repo/"
download_path="./DMGs"
apps=(./apps/*.sh) # Build array of app updaters

# Intro
clear
echo "-----------------------"
echo "---MUNKI APP UPDATER---"
echo "------Version 1.0------"
echo "--Charlie Callow 2017--"
echo "-----------------------"
echo ""
echo "Apps to update:"

# Iterate through apps array using a counter
for ((i=0; i<${#apps[@]}; i++)); do
	# Include current app updater script
        source "${apps[$i]}"
	
	# Output app name
        echo "${munki_name}"

	# Build arrays of app properties
        app_name[i]="${munki_name}"
        app_path[i]="${munki_path}"
        app_url[i]="${down_url}"
done

# Checks if a given function exists
function_exists() {
    declare -f -F $1 > /dev/null
    return $?
}

# Checks version of app in Munki repo
check_version() {
	# Create an array of .pkginfo files in app directory
        # (ordered by ascending modification time)
        for dir in $(ls -tr $1/*.p*); do
                files=($dir)
        done

	version="${files[@]: -1}"	# access last member of array (most recent .pkginfo)
	version="${version%__*}"	# remove Munki suffixes
	version="${version//[!0-9.]/}"	# remove non-decimal characters
	echo "${version}"		# output version 
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

# Makes enlarged writable DMG image and mounts it so edits
# can be made to the app
prep_dmg_start() {
	# Make writable copy of DMG
	echo "Making writeable image"
	hdiutil convert "${download_path}"/"${1}"-ro.dmg -format UDRW -o "${download_path}"/"${1}"-rw.dmg
	echo ""

        # Increase size of image to allow for app rename
        echo "Calculating image size..."
        local imgsize=`hdiutil resize -limits "${download_path}"/"${1}"-rw.dmg | tail -n1 | awk '{print $2}'`;
        echo "Image size is: ${imgsize}"
        echo "Growing writable image..."
        imgsize=$((imgsize + 100)) # Add 100 to DMG size
        echo "Resizing to: ${imgsize}"
        hdiutil resize -sectors ${imgsize} "${download_path}"/"${1}"-rw.dmg
        local imgsize=`hdiutil resize -limits "${download_path}"/"${1}"-rw.dmg | tail -n1 | awk '{print $2}'`;
        echo "New image size is: ${imgsize}"
        echo ""

        # Mount writable DMG to perform edit
        echo "Mounting image to edit..."
        hdiutil attach "${download_path}"/"${1}"-rw.dmg
        echo ""
}

# Detaches DMG, compacts it and makes it read only
prep_dmg_end() {
        #  Unmount DMG 
        echo "Detaching image..."
        hdiutil detach /Volumes/Firefox
        echo ""

        # Compact image to previous size
        echo "Compacting image..."
        hdiutil resize -sectors min "${download_path}"/"${1}"-rw.dmg
        echo ""

        # Remove original downloaded image
        echo "Removing old Read-only image..."
        rm -f "${download_path}"/"${1}"-ro.dmg
        echo ""

        # Make new read only image from modified rw DMG
        echo "Make new read-only image..."
        hdiutil convert -format UDZO -o "${download_path}"/"${1}"-ro.dmg "${download_path}"/"${1}"-rw.dmg
        echo ""

        # Clear up writeable DMG
        echo "Removing unneeded writable-image..."
        rm -f "${download_path}"/"${1}"-rw.dmg
        echo "Firefox ESR DMG preparation finished!"
        echo ""
}

# Downloads latest version of app and imports to Munki repo
# Requires app_name (1), app_url (2) and app_path (3) as arguments
update_app() {	
	# Make download directory (if it doesn't exist)
	mkdir -p "${download_path}";
	
	# Clear previous downloads
	echo "Deleting old downloads..."
	rm -f "${download_path}"/"${1}"-rw.dmg
	rm -f "${download_path}"/"${1}"-ro.dmg
	rm -f "${download_path}"/"${1}".dmg
	echo ""	

	# Download latest release of app
	echo "Downloading newer release image..."
	wget "${2}" -O "${download_path}"/"${1}"-ro.dmg
	echo "${1} downloaded."
	echo ""

	function_exists "prep_${1}"
    	if [ "$?" = "0" ]; then
		echo "${1} DMG needs modification!"
		prep_"${1}" "${1}"
	else
                # No prep funcion, skip to import
                echo "No prep function for app. Importing as is..."
		echo ""
	fi
	
	# Rename DMG to remove permissions suffix
	echo "Renaming DMG to ${1}.dmg..."
	mv "${download_path}"/"${1}"-ro.dmg "${download_path}"/"${1}".dmg
	echo ""

	# Import app to Munki repo
	echo "Starting Munki import..."
	/usr/local/munki/munkiimport --subdirectory="${3}" "${download_path}"/"${1}".dmg
}

# Checks existing versions of all apps in Munki repo and compare
# to the latest available release. Updates the apps when online
# version is newer than that in the repo
for ((i=0; i<${#app_name[*]}; i++));
do
	echo ""

	# Check version of app in Munki repo
	echo "Checking existing ${app_name[$i]} version in repo..."
	check_version "${munkirepo}pkgsinfo/${app_path[$i]}"
	echo ""

	# Verify update check function exists for app
	function_exists "check_avail_${app_name[$i]// /_}"
	if [ "$?" != "0" ]; then
		# No update checking function, skip to next app
		echo "Error: No update check function for app!"
		echo "Skipping online update check for ${app_name[$i]}."
		continue
	fi

	echo "Checking latest online version."
	check_avail_"${app_name[$i]// /_}"	# check latest available version online
	echo ""
	
	# Compare versions in Munki repo with the latest available online
	version_compare "${version}" "${avversion}"
	case "$?" in
 	"9") echo "Newer release available!"
		update_app "${app_name[$i]}" "${app_url[$i]}" "${app_path[$i]}"	;;	# Run update process for the app
        "10") echo "Munki repo matches online. Nothing to do." ;;
        "11") echo "Munki repo has newer release. Nothing to do." ;;
  	*   ) echo "Something went wrong!";;
  	esac
	echo "${app_name[$i]} is up to date!"
done
echo ""
echo "All apps up to date! Exiting..."
