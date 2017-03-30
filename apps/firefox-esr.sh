munki_name="Firefox-ESR"
munki_path="apps/firefox-esr"
down_url="https://download.mozilla.org/?product=firefox-esr-latest&os=osx&lang=en-GB"

# Checks latest version of Firefox ESR available online
check_avail_Firefox-ESR() {
        avversion=$(wget --spider -S --max-redirect 0 "https://download.mozilla.org/?product=firefox-esr-latest&os=osx&lang=en-GB" 2>&1 |  sed -n 's/^.*Firefox%20\([^&]*\)esr.dmg/\1/p;' | head -1)
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

