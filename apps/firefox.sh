munki_name="Firefox"
munki_path="apps/firefox"
down_url="https://download.mozilla.org/?product=firefox-latest&os=osx&lang=en-GB"

# Checks latest version of app available online
check_avail_Firefox() {
        # Determine latest version available to download and store version
        # string for comparison to Munki repo version
        avversion=$(wget --spider -S --max-redirect 0 "https://download.mozilla.org/?product=firefox-latest&os=osx&lang=en-GB" 2>&1 |  sed -n 's/^.*Firefox%20\([^&]*\).dmg/\1/p;' | head -1)
}


