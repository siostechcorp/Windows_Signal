#######################################################################################################################
# Send-Signal.ps1
# 
# Parse System event log for specifc log, sources, and ids defined in $eventsJsonFile. Should be configured to run on a 
# schedule via Task Scheduler. 
# Requires Python27 to be in the PATH environment variable.
#
# Examples:
#     PS> Send-Signal 
#     PS> Send-Signal -Pyscript ".\report_event.py" -TimeStampFile ".\UniversalTimeStamp.log" -EventsJsonFile ".\events.json" 
#
#######################################################################################################################

[CmdletBinding()]
Param(    
    [String] $pyscript       = ".\report_event.py",
    [String] $timeStampFile  = ".\UniversalTimeStamp.log",
    [String] $eventsJsonFile = ".\events.json"
)

$node = $env:COMPUTERNAME

$xMinutesAgo = (Get-Date).Subtract((New-TimeSpan -Minutes $MinutesPrevious))

$events = Get-EventLog -LogName $EventLog -After $xMinutesAgo -Source $EventSource

foreach ( $evt in $events ) {
    # only report events from node running this script
    if ( $evt.MachineName -like "$node*" ) {
        $evtSeverity = $null
        switch($evt.CategoryNumber) {
            1 { $evtSeverity = "Info" }
            2 { $evtSeverity = "Warning" }
            3 { $evtSeverity = "Critical" }
            default { $evtSeverity = "Info" }
        }
        
        $tz = Get-TimeZone
        $tzinfo = $tz.BaseUtcOffset.Hours.ToString("00") + [Math]::abs($tz.BaseUtcOffset.Minutes).ToString("00")

        Write-Verbose ("Sending the following event details to the python script:`n" + $EventSource + "`n" + $evt.EventID + "`n" + $evtSeverity + "`n" + $evt.Message + "`n" + ($evt.TimeGenerated.ToString("yyyy-MM-ddTHH:mm:ss") + $tzinfo))

        Invoke-Command -ScriptBlock { 
            Param(
                [string] $a1, 
                [string] $a2, 
                [string] $a3, 
                [string] $a4, 
                [string] $a5
            ) 

            &'python' $pyscript $a1 $a2 $a3 $a4 $a5 

        } -ArgumentList @(
            $EventSource,
            $evt.EventID,
            $evtSeverity,
            $evt.Message,
            ($evt.TimeGenerated.ToString("yyyy-MM-ddTHH:mm:ss") + $tzinfo)
        )
    }
}