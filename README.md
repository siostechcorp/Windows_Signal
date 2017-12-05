# Windows Signal
Windows Signal is a repository that contains the SIOS iQ integration with Windows Events that can be sent to SIOS iQ product for analysis and correlation.

# References
Windows Signal depends on Signal iQ SDK (https://github.com/siostechcorp/Signal_iQ).

# Prerequisites
This module depends on Python 2.7.14, and certain packages as outlined in the Signal iQ SDK. See the Signal iQ start up guide for setup instructions prior to using Windows Signal.

# Instructions
Window Signal consists of two parts: the scripts included in this repo, and local system task configuration. A recurring task must be configured to run on some time interval. This task simply needs to call the included PowerShell script.

The included PowerShell script should be edited with your iQ Environment id. This should have been obtained during the Signal iQ setup performed as a prerequisite, but it is also availble in the Properties page for your environment in the SIOS iQ web gui.

The PowerShell script relies on a json file declaring which events are of interest and should be monitored. An example file (Windows.json) can be found in the json folder, and a sample file (Sample.json) with syntax descriptions is in the base folder. Additional events can be monitored by adding to the Windows.json file or by adding another file in the json folder containing the desired events using the same format as the existing files. The basic layout for the json structure is Log > Source > ID > FilterText. The FilterText can be used to narrow down a single event from multiple different events using the same (Log,Source,ID). Use a '.' in place of the FilterText to match any(all) events with the same (Log,Source,ID).

To create a task in Windows Server first start the Task Scheduler (https://technet.microsoft.com/en-us/library/cc721931(v=ws.11).aspx)  

Next schedule a task (https://technet.microsoft.com/en-us/library/cc748993(v=ws.11).aspx) similar to the images below.  
The arguments field on the New Action panel should be given the following:  

"<path-to-Windows_Signal-repo>\scripts\Send-Signal.ps1"  

Also, the polling interval should match the value used in the "Repeat task every" field in the New Trigger dialog.  

Click the link for a video configuration walkthrough:
[Windows Signal Configuration](../blob/master/Windows_Signal_Config.webm)
