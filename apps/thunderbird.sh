munki_name="Thunderbird"
munki_path="apps/thunderbird"
down_url="https://download.mozilla.org/?product=thunderbird-latest&os=osx&lang=en-GB"

# Checks latest version of Thunderbird available online
check_avail_Thunderbird() {
        avversion=$(wget --spider -S --max-redirect 0 "https://download.mozilla.org/?product=thunderbird-latest&os=osx&lang=en-GB" 2>&1 |  sed -n 's/^.*Thunderbird%20\([^&]*\).dmg/\1/p;' | head -1)
}

