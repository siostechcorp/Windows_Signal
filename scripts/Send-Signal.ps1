#######################################################################################################################
# Send-Signal.ps1
# 
# Parse System event log for specifc log, sources, and ids defined in $eventsJsonFile. Should be configured to run on a 
# schedule via Task Scheduler. 
# Requires Python27 to be in the PATH environment variable.
#
# Examples:
#     PS> Send-Signal 
#     PS> Send-Signal -Pyscript ".\report_event.py" -EventsJsonFile ".\events.json" 
#
#######################################################################################################################

[CmdletBinding()]
Param(    
    [String] $pyscript       = ".\report_event.py",
    [String] $eventsJsonFile = ".\events.json"
)

function Report-Events {
    [CmdletBinding()]
    Param(
        [System.Collections.ArrayList] $EventCollection,
        [String] $Source,
        [String] $Node
    )

    foreach ( $evt in $EventCollection ) {
        # only report events from node running this script
        if ( $evt.MachineName -like "$Node" ) {
            $evtSeverity = $null
            switch($evt.CategoryNumber) {
                1 { $evtSeverity = "Info" }
                2 { $evtSeverity = "Warning" }
                3 { $evtSeverity = "Critical" }
                default { $evtSeverity = "Info" }
            }
            
            $tz = Get-TimeZone
            $tzinfo = $tz.BaseUtcOffset.Hours.ToString("00") + [Math]::abs($tz.BaseUtcOffset.Minutes).ToString("00")

            Write-Verbose ("Sending the following event details to the python script:`n" + $Source + "`n" + $evt.EventID + "`n" + $evtSeverity + "`n" + $evt.Message + "`n" + ($evt.TimeGenerated.ToString("yyyy-MM-ddTHH:mm:ss") + $tzinfo))

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
                $Source,
                $evt.EventID,
                $evtSeverity,
                $evt.Message,
                ($evt.TimeGenerated.ToString("yyyy-MM-ddTHH:mm:ss") + $tzinfo)
            )
        }
    }
}

### ENTRY POINT #######################################################################################################

# parse the current epoch time as a signed long, then create DateTime object from it
$nowUnixTime = [long] (Get-Date -Date ((Get-Date).ToUniversalTime()) -UFormat %s)
$nowUniversalDateTime = (([datetime]'1/1/1970').AddSeconds($nowUnixTime)).ToLocalTime()
Write-Verbose "time now is $nowUniversalDateTime"

# parse the events json file into a PSCustomObject hashtable
if(Test-Path -Path $eventsJsonFile) {
    $desiredLogs = Get-Content -Raw -Path $eventsJsonFile | ConvertFrom-Json
} else {
    Write-EventLog -LogName "Application" -Source "Windows_Signal" -EventID 9000 -EntryType Critical -Message "No events file found at $eventsJsonFile."
    Write-Verbose "No events file found at $eventsJsonFile."
    exit 1
}

# parse out the event logs (Application, System, etc) we need to scan containing the events we care about 
if ($desiredLogs -ne $Null) {
    $eventLogs = $desiredLogs | Get-Member | Where-Object -Property "MemberType" -eq "NoteProperty" | foreach { $_.Name }
} else {
    Write-EventLog -LogName "Application" -Source "Windows_Signal" -EventID 9001 -EntryType Critical -Message "Failed to parse events file found at $eventsJsonFile. Either no events of interest have been configured or the file is corrupt."
    Write-Verbose "Failed to parse events file found at $eventsJsonFile. Either no events of interest have been configured or the file is corrupt."
    exit 1
}

foreach ($log in $eventLogs) {
    
    # parse out the sources that issue the events we care about so that we can query the target log for just those sources    
    $eventSources = $desiredLogs.$log | Get-Member | Where-Object -Property "MemberType" -eq "NoteProperty" | foreach { $_.Name }
    
    foreach ($source in $eventSources) {

        Write-Verbose "Looking for events from $log and $source..."

        # parse the last epoch time this script succeeded then create DateTime object from it 
        $lastUnixTime = [long]$desiredLogs.$log.$source.lastReportTime
        if ($lastUnixTime -eq 0) {
            $lastUnixTime = 18000 # 1/1/1970 UTC time in case the lastReportTime value is missing (or set to 0) for this log and source
        }
        $lastUniversalDateTime = (([datetime]'1/1/1970').AddSeconds($lastUnixTime)).ToLocalTime()
        Write-Verbose "last successful run was performed at $lastUniversalDateTime"        

        $events = Get-EventLog -LogName $log -After $lastUniversalDateTime -Before $nowUniversalDateTime -Source $source | Where-Object { 
            $desiredLogs.$log.$source.Ids -Contains $_.EventId 
        }

        if ($?) {
            if (($desiredLogs.$log.$source | Get-Member -MemberType NoteProperty).Name -Contains "lastReportTime") {
                $desiredLogs.$log.$source.lastReportTime = $nowUnixTime
            } else {
                $desiredLogs.$log.$source | Add-Member -NotePropertyName lastReportTime -NotePropertyValue $nowUnixTime
            }
        }

        $eventsOfInterest = [System.Collections.ArrayList]@()
        
        if ($events -ne $Null) {
            $evt
            foreach ($evt in $events) { 
                $eventsOfInterest.Add($_) 
            }
            
            Report-Events -EventCollection $eventsOfInterest -Source $source -Node $env:COMPUTERNAME
        }
    }
}

# overwrite the events file to update the timestamps with the time we started running this script
$desiredLogs | ConvertTo-Json > $eventsJsonFile