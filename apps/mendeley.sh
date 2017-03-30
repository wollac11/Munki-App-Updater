munki_name="Mendeley Desktop"
munki_path="mendeley.com"
down_url="http://www.mendeley.com/autoupdates/installer/Mac-x64/stable-incoming"

# Checks latest version of app available online
check_avail_Mendeley_Desktop() {
    # Determine latest version available to download and store version
    # string for comparison to Munki repo version
    avversion=$(wget --spider -S --max-redirect 1 "http://www.mendeley.com/autoupdates/installer/Mac-x64/stable-incoming" 2>&1 |  sed -n 's/^.*Mendeley-Desktop-\([^&]*\)-OSX-Universal.dmg/\1/p;' | head -1)
}