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
