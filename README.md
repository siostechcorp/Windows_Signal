# Windows Signal
Windows Signal is a repository that contains the SIOS iQ integration with Windows Events that can be sent to SIOS iQ product for analysis and correlation.

# References
Windows Signal depends on Signal iQ SDK (https://github.com/siostechcorp/Signal_iQ).

# Prerequisites
This module depends on Python 2.7.14, and certain packages as outlined in the Signal iQ SDK. See the Signal iQ start up guide for setup instructions prior to using Windows Signal.

# Instructions
Window Signal consists of two parts: the scripts included in this repo, and local system task configuration. A recurring task must be configured to run on some time interval. This task simply needs to call the included PowerShell script.
The included python script should be edited with your iQ Environment id and the host server's Virtual Machine UUID. These should have been obtained during the Signal iQ setup performed as a prerequisite. 
To create a task in Windows Server first start the Task Scheduler (https://technet.microsoft.com/en-us/library/cc721931(v=ws.11).aspx)

Next schedule a task (https://technet.microsoft.com/en-us/library/cc748993(v=ws.11).aspx) similar to the images below. 
The arguments field on the New Action panel should be given the following:
"<path-to-Windows_Signal-repo>\scripts\Send-Signal.ps1" <Source> <polling interval in minutes>
Also, the polling interval should match the value used in the "Repeat task every" field in the New Trigger dialog.
![Create Task Dialog](https://sites.google.com/a/steeleye.com/stc/_/rsrc/1507905561406/programs/nextgen/nextgenhome/r-d/datakeeper-signal/WindowsSignalTask01.png "Create Task")
![New Trigger Dialog](https://sites.google.com/a/steeleye.com/stc/_/rsrc/1507905805000/programs/nextgen/nextgenhome/r-d/datakeeper-signal/WindowsSignalTask02.png "New Trigger")
![New Action Dialog](https://sites.google.com/a/steeleye.com/stc/_/rsrc/1507906007484/programs/nextgen/nextgenhome/r-d/datakeeper-signal/WindowsSignalTask03.png "New Action")
