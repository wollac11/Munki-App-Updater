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
	echo "https://downloads.sourceforge.net/project/filezilla/FileZilla_Client/${avversion}/FileZilla_${avversion}_macosx-x86.app.tar.bz2"
}

prep_FileZilla() {
	tar xjf "${download_path}/${1}" -C ${download_path}
	file_name="FileZilla.app"
}

down_url=$(get_downurl)