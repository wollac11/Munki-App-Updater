# Munki App Updater
Checks &amp; updates Munki packaged apps for managed OSX machines

Supported apps: Firefox, Firefox ESR

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
	Note: currently app_url is hardcoded for supported apps. Support for specifying app_url will be added in a future update

	- Any app which needs some edits before importing
	may now specify a method to perform such edits and script will run said
	method. If none is specified then script will proceed to import DMG as
	it is from download.  
	- Fixed some indentation errors
