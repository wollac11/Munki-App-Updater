#!/bin/bash

# Munki App Updater
# Checks and updates munki packages
# Version 0.7
# Charlie Callow 2017

# Config
munkirepo="/net/mac-builder/var/www/html/munki_repo/"
download_path="./DMGs"

app_name[0]="Firefox"
app_path[0]="apps/firefox"
app_url[0]="https://download.mozilla.org/?product=firefox-latest&os=osx&lang=en-GB"
app_name[1]="Firefox-ESR"
app_path[1]="apps/firefox-esr"
app_url[1]="https://download.mozilla.org/?product=firefox-esr-latest&os=osx&lang=en-GB"
app_name[2]="Thunderbird"
app_path[2]="apps/thunderbird"
app_url[2]="https://download.mozilla.org/?product=thunderbird-latest&os=osx&lang=en-GB"

# Intro
clear
echo "-----------------------"
echo "---MUNKI APP UPDATER---"
echo "------Version 0.7------"
echo "--Charlie Callow 2017--"
echo "-----------------------"
echo ""
echo "Apps to update:"
for ((i=0; i<${#app_name[*]}; i++));
do
	echo "${app_name[i]}"
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
        for dir in $(ls -tr $1/*.pkginfo); do
                files=(`basename $dir .pkginfo`)
        done

	version="${files[@]: -1}"	# access last member of array (most recent .pkginfo)
	version="${version%__*}"	# remove Munki suffixes
	version="${version//[!0-9.]/}"	# remove non-decimal characters
	echo "${version}"		# output version 
}

# Checks latest version of app available online
check_avail_Firefox() {	
	# Determine latest version available to download and store version
	# string for comparison to Munki repo version
	avversion=$(wget --spider -S --max-redirect 0 "https://download.mozilla.org/?product=firefox-latest&os=osx&lang=en-GB" 2>&1 |  sed -n 's/^.*Firefox%20\([^&]*\).dmg/\1/p;' | head -1)
	echo "${avversion}" # output discovered version
}

# Checks latest version of Firefox ESR available online
check_avail_Firefox-ESR() {
	avversion=$(wget --spider -S --max-redirect 0 "https://download.mozilla.org/?product=firefox-esr-latest&os=osx&lang=en-GB" 2>&1 |  sed -n 's/^.*Firefox%20\([^&]*\)esr.dmg/\1/p;' | head -1)
        echo "${avversion}" # output discovered version
}

# Checks latest version of Thunderbird available online
check_avail_Thunderbird() {
	avversion=$(wget --spider -S --max-redirect 0 "https://download.mozilla.org/?product=thunderbird-latest&os=osx&lang=en-GB" 2>&1 |  sed -n 's/^.*Thunderbird%20\([^&]*\).dmg/\1/p;' | head -1)
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

# Edits Firefox ESR DMG to give make distinct from standard Firefox
# channel to avoid confusing Munki (renames app to "Firefox-ESR")
prep_Firefox-ESR() {
	echo ""
	echo "Modifying DMG to rename Firefox.app..."
        echo ""
	
	# Make & mount writable image for edits
	prep_dmg_start "${1}"

	# Rename Firefox app
	echo "Renaming Firefox.app to Firefox-ESR.app"
	mv /Volumes/Firefox/Firefox.app /Volumes/Firefox/Firefox-ESR.app
	echo ""	

	# Detach DMG and make read only
	prep_dmg_end "${1}"
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
	function_exists "check_avail_${app_name[$i]}"
	if [ "$?" != "0" ]; then
		# No update checking function, skip to next app
		echo "Error: No update check function for app!"
		echo "Skipping online update check for ${app_name[$i]}."
		continue
	fi

	echo "Checking latest online version."
	check_avail_"${app_name[$i]}"	# check latest available version online
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
