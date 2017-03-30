munki_name="FileZilla"
munki_path="filezilla-project.org"

# Checks latest version of app available online
check_avail_FileZilla() {
        # Determine latest version available to download and store version
        # string for comparison to Munki repo version
        avversion=$(curl -s https://filezilla-project.org/download.php?platform=osx | grep 'latest stable version' |  sed -n 's/^.*Client is \([^&]*\)</\1/p;')
		avversion="${avversion//[!0-9.]/}"	# remove non-decimal characters
}

get_downurl() {
	check_avail_FileZilla
	echo "https://download.filezilla-project.org/client/FileZilla_${avversion}_macosx-x86_setup_bundled.zip"
}

prep_FileZilla() {
	unzip "${download_path}/${1}" -d ${download_path}
	file_name="FileZilla-Installer.app"
}

down_url=$(get_downurl)