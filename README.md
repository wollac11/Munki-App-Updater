# Munki App Updater
Checks &amp; updates Munki packaged apps for managed OSX machines

Supported apps: Firefox, Firefox ESR, Thunderbird

Changelog:

--0.1 (07/03/2017):  
	- Initial Release

--0.2 (21/03/2017):  

	- Changed online version check method to order files by
	modification date in order to fix bug where .1 releases would be ignored

--0.3 (21/03/2017):  

	- Added an app intro message which outputs release info and lists apps it is updating.

--0.4 (22/03/2017):  

	- Added blank lines between different operations to make output easier read  
	- Added script completion message

--0.5 (23/03/2017):  

	- Script now checks that a method exists for finding the latest online version 
	of each given app before attempting to run it.

--0.6 (23/03/2017):  

	Note: currently app url is hardcoded for supported apps. This will be addressed in an update.  

	- Any app which needs some edits before importing
	may now specify a method to perform such edits and script will run said
	method. If none is specified then script will proceed to import DMG as
	it is from download.  
	- Fixed some indentation errors

--0.7 (24/03/2017):  

	- Now checks online version for OSX build instead of Linux build  
	- Separted Firefox & Firefox ESR update checks  
	- Changed download path to variable which defaults to a DMG directory
	inside the current working directory (instead of hard-coded to ~/Downloads)  
	- Streamlined online update checks for Firefox and Firefox ESR  
	- Made app update method universal to support adding new apps  
	- Added support for Mozilla Thunderbird  
	- Small fixes  
	- Renamed main script to reflect added support for non-Firefox apps.

--1.0 (27/03/2017):  
	First full release!

	- Split Firefox-ESR prep method into to allow for code re-use on other apps 
	which need modifications.
	- Moved app-specific methods into external files
	- New feature: script reads external files for each app in /apps directory
	so that new apps can easily be added by writing a short app script.
