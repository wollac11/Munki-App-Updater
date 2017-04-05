#!/bin/bash

# Munki App Updater
# Checks and updates munki packages
# Version 1.1
# Charlie Callow 2017

# Config
munkirepo="/net/mac-builder/var/www/html/munki_repo/"
apps=(./apps/*.sh) # Build array of app updaters
supported_ext=('dmg' 'pkg' 'app') # array of supported file extensions
testing=false # default testing value

# Proccess input arguments
while [[ $# -gt 0 ]]
do
    key="$1"

    case $key in
        -e|--exclude)
            app_exclude+=("$2")
            shift # past argument
        ;;
        -a|--app)
            app_only+=("$2")
            shift # past argument
        ;;
        -t|--test)
            testing=true
        ;;
        *)
                # unknown option
        ;;
    esac
    shift # past argument or value
done

# Intro
clear
echo "-----------------------"
echo "---MUNKI APP UPDATER---"
echo "------Version 1.1------"
echo "--Charlie Callow 2017--"
echo "-----------------------"
echo

if [ $testing = true ]; then
    echo "RUNNING IN TESTING MODE" && echo
fi

echo "Apps to update:"

# Iterate through apps array and proccess them
# for inclusion/exclusion in updates
for app in "${apps[@]}"; do
    # Get app munki name
    c_app_name=$(grep "munki_name" "${app}" | sed -e 's/munki_name="\(.*\)"/\1/')

    # Disable case matching
    shopt -s nocasematch

    # Check if current app exists in excluded array
    if [[ " ${app_exclude[@]} " =~ " ${c_app_name} " ]]; then
        skipped_apps+=("${c_app_name}") # Record app skipped with 'clean' name
        continue # skip to next app
    fi

    # Check if single app mode is specified
    if [ $app_only ]; then
        # Check if current app is not the specified app
        if [[ ! " ${app_only[@]} " =~ " ${c_app_name} " ]]; then
            skipped_apps+=("${c_app_name}") # Record app skipped with 'clean' name
            continue # skip to next app
        fi
    fi

    # Re-enable case matching
    shopt -u nocasematch 

    # Include current app updater script
    source "${app}"

    # Output app name
    echo "${munki_name}"

    # Build arrays of app properties
    app_name+=("${munki_name}")
    app_path+=("${munki_path}")
    app_url+=("${down_url}")
done

if [ $skipped_apps ]; then
    echo && echo "Excluded apps:"
    printf '%s\n' "${skipped_apps[@]}"
fi

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

    version="${files[@]: -1}"   # access last member of array (most recent .pkginfo)
    version="${version%__*}"    # remove Munki suffixes
    version="${version//[!0-9.]/}"  # remove non-decimal characters
    version="${version#.}" # remove preceding "."
    version="${version%.}" # remove following "."
    echo "${version}"       # output version 
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
    hdiutil convert "${download_path}"/"${1}" -format UDRW -o "${download_path}"/rw-"${1}"
    echo

    # Increase size of image to allow for app rename
    echo "Calculating image size..."
    local imgsize=`hdiutil resize -limits "${download_path}"/rw-"${1}" | tail -n1 | awk '{print $2}'`;
    echo "Image size is: ${imgsize}"
    echo "Growing writable image..."
    imgsize=$((imgsize + 100)) # Add 100 to DMG size
    echo "Resizing to: ${imgsize}"
    hdiutil resize -sectors ${imgsize} "${download_path}"/rw-"${1}"
    local imgsize=`hdiutil resize -limits "${download_path}"/rw-"${1}" | tail -n1 | awk '{print $2}'`;
    echo "New image size is: ${imgsize}"
    echo

    # Mount writable DMG to perform edit
    echo "Mounting image to edit..."
    hdiutil attach "${download_path}"/rw-"${1}"
    echo
}

# Detaches DMG, compacts it and makes it read only
prep_dmg_end() {
    #  Unmount DMG 
    echo "Detaching image..."
    sleep 2
    hdiutil detach /Volumes/Firefox
    echo

    # Compact image to previous size
    echo "Compacting image..."
    sleep 2
    hdiutil resize -sectors min "${download_path}"/rw-"${1}"
    echo

    # Remove original downloaded image
    echo "Removing old Read-only image..."
    rm -f "${download_path}"/"${1}"
    echo

    # Make new read only image from modified rw DMG
    echo "Make new read-only image..."
    hdiutil convert -format UDZO -o "${download_path}"/"${1}" "${download_path}"/rw-"${1}"
    echo

    # Clear up writeable DMG
    echo "Removing unneeded writable-image..."
    rm -f "${download_path}"/rw-"${1}"
    echo "Firefox ESR DMG preparation finished!"
    echo
}

# Downloads latest version of app and imports to Munki repo
# Requires app_name (1), app_url (2) and app_path (3) as arguments
update_app() {
    # Create temporary download directory and store path
    echo "Creating temporary download directory..."
    download_path=$(mktemp -d)

    # Download latest release of app
    echo "Downloading latest release..."
    wget --trust-server-names "${2}" -P "${download_path}"
    echo "${1} downloaded."
    echo

    # Get name of downloaded file
    file_name=$(echo "${download_path}"/*) 
    file_name=$(basename "${file_name}") # Remove path

    # Extract file extension from path
    extension="${file_name##*.}"    

    # Check if prep function in app provider
    function_exists "prep_${1}"
    if [ "$?" = "0" ]; then
        # Prep function found
        echo "${1} needs modification!"
        prep_"${1}" "${file_name}" # run app prep function
    else
        # No prep function found
        # Check if file extension supported by import
        if [[ " ${supported_ext[@]} " =~ " ${extension} " ]]; then
            # File extension supported
            echo "Found supported file extension '.${extension}'"
            # Skip to import
            echo "No prep function for app. Importing as is..." && echo
        else
            # Unsupported file extension and no prep function to alter file
            # included in the app provider
            echo "File extension '.${extension}' not supported!"
            echo -n "Supported extensions are: "
            printf "'.%s' " "${supported_ext[@]}" && echo
            echo && echo "Cannot import app. Missing required prep function."
            return # Cancel app update
        fi
    fi

    # Make friendly filename ([appname].[ext])
    extension="${file_name##*.}" # recheck extension (in case of changes by prep)
    if [ ! "${file_name}" == "${1}.${extension}" ]; then # check for incorrect name
        echo "Renaming ${file_name} to ${1}.${extension}..."
        mv "${download_path}/${file_name}" "${download_path}/${1}.${extension}" # rename file
    fi
    file_name="${1}.${extension}" # update stored file name

    # Check testing mode is off
    if [ $testing = false ]; then
        # Import app to Munki repo
        echo "Starting Munki import of ${file_name}..."
        /usr/local/munki/munkiimport --subdirectory="${3}" "${download_path}"/"${file_name}"

        # Report success
        echo "The munki package for "${1}" has been updated successfully!" && echo
    else 
        # Testing mode on, skip import
        echo "Testing mode active! Skipping import..."
    fi

    # Report success
    echo "The munki package for "${1}" has been updated successfully!" && echo

    # Delete temporary directory
    echo "Removing temporary download directory..."
    rm -rf "${download_path}"
    echo "Done!" && echo
}

# Checks existing versions of all apps in Munki repo and compare
# to the latest available release. Updates the apps when online
# version is newer than that in the repo
for ((i=0; i<${#app_name[*]}; i++));
do
    echo

    # Check version of app in Munki repo
    echo "Checking existing ${app_name[$i]} version in repo..."
    check_version "${munkirepo}pkgsinfo/${app_path[$i]}"
    echo

    # Verify update check function exists for app
    function_exists "check_avail_${app_name[$i]// /_}"
    if [ "$?" != "0" ]; then
        # No update checking function, skip to next app
        echo "Error: No update check function for app!"
        echo "Skipping online update check for ${app_name[$i]}."
        continue
    fi

    echo "Checking latest online version."
    check_avail_"${app_name[$i]// /_}"  # check latest available version online
    echo "${avversion}" # output discovered version
    echo
    
    # Compare versions in Munki repo with the latest available online
    version_compare "${version}" "${avversion}"
    case "$?" in
    "9") 
        echo "Newer release available!"
        update_app "${app_name[$i]}" "${app_url[$i]}" "${app_path[$i]}"  # Run update process for the app
    ;;
    "10") echo "Munki repo matches online. Nothing to do." ;;
    "11") echo "Munki repo has newer release. Nothing to do." ;;
    *   ) echo "Something went wrong!";;
    esac
done
echo "All apps up to date! Exiting..."