#######################################################################################################################
# Send-Signal.ps1
# 
# Parse System event log for specifc log, sources, and ids defined in the json files located at the $eventsJsonFilePath. 
# Should be configured to run on a schedule via Task Scheduler. 
# Requires Python27 to be in the PATH environment variable.
#
# Examples:
#     PS> Send-Signal 
#     PS> Send-Signal -Pyscript ".\report_event.py" -eventsJsonFilePath ".\" 
#
#######################################################################################################################

[CmdletBinding()]
Param(    
    [String] $pyscript       = ".\report_event.py",
    [String] $eventsJsonFilePath = ".\"
)

function Report-Events {
    [CmdletBinding()]
    Param(
        [Object[]] $EventCollection,
        [String] $Source
    )

    if($EventCollection -eq $Null) {
        return 0
    }

    foreach ( $evt in $EventCollection ) {
        # only report events from node running this script
        if ( ($evt.MachineName -like "$env:COMPUTERNAME") -Or ($evt.MachineName -like "$env:COMPUTERNAME.$env:USERDNSDOMAIN") ) {
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

            return $?
        }
    }
}

### ENTRY POINT #######################################################################################################

# parse the current epoch time as a signed long, then create DateTime object from it
$nowUnixTime = [long] (Get-Date -Date ((Get-Date).ToUniversalTime()) -UFormat %s)
$nowUniversalDateTime = (([datetime]'1/1/1970').AddSeconds($nowUnixTime)).ToLocalTime()
Write-Verbose "time now is $nowUniversalDateTime"

# parse the events json file into a PSCustomObject hashtable
if(Test-Path -Path $eventsJsonFilePath) {
    $jsonFiles = Get-ChildItem -Path $eventsJsonFilePath -Filter "*.json"
    foreach ($file in $jsonFiles) {
        $desiredLogs = Get-Content -Raw -Path $file.FullName | ConvertFrom-Json

        # parse out the event logs (Application, System, etc) we need to scan containing the events we care about 
        if ($desiredLogs -ne $Null) {
            $eventLogs = $desiredLogs | Get-Member | Where-Object -Property "MemberType" -eq "NoteProperty" | foreach { $_.Name }
        } else {
            Write-EventLog -LogName "Application" -Source "Windows_Signal" -EventID 9001 -EntryType Critical -Message "Failed to parse events file found at $eventsJsonFilePath. Either no events of interest have been configured or the file is corrupt."
            Write-Verbose "Failed to parse events file found at $eventsJsonFilePath. Either no events of interest have been configured or the file is corrupt."
            exit 1
        }

        foreach ($log in $eventLogs) {
            
            # parse out the sources that issue the events we care about so that we can query the target log for just those sources    
            $eventSources = $desiredLogs.$log | Get-Member | Where-Object -Property "MemberType" -eq "NoteProperty" | foreach { $_.Name }
            
            foreach ($source in $eventSources) {

                Write-Verbose "Looking for events from $log and $source..."

                # parse the last epoch time this script succeeded then create DateTime object from it 
                $lastUnixTime = [long]$desiredLogs.$log.$source.lastReportTime
                Write-Verbose "lastUnixTime: $lastUnixTime"
                if ($lastUnixTime -eq 0) {
                    Write-Verbose "SETTING LAST UNIX TIME TO 5 MIN AGO"
                    $lastUnixTime = $nowUnixTime - 301 # if no time was recorded for last successful run, then just get last five minutes.
                } else {
                    $lastUnixTime -= 1;   # so we catch the missing second from the last time we ran Get-EventLog
                }
                Write-Verbose "lastUnixTime: $lastUnixTime"
                $lastUniversalDateTime = (([datetime]'1/1/1970').AddSeconds($lastUnixTime)).ToLocalTime()
                Write-Verbose "last successful run was performed at $lastUniversalDateTime"        

                $events = Get-EventLog -LogName $log -After $lastUniversalDateTime -Before $nowUniversalDateTime -Source $source | Where-Object { 
                    $desiredLogs.$log.$source.ids -Contains $_.EventId 
                }

                Report-Events -EventCollection $events -Source $source

                if ($?) {
                    Write-Verbose "events found"
                    if (($desiredLogs.$log.$source | Get-Member -MemberType NoteProperty).Name -Contains "lastReportTime") {
                        Write-Verbose "updating timestamp for $source"
                        $desiredLogs.$log.$source.lastReportTime = $nowUnixTime
                    } else {
                        Write-Verbose "adding lastReportTime member with value $nowUnixTime"
                        $desiredLogs.$log.$source | Add-Member -NotePropertyName lastReportTime -NotePropertyValue $nowUnixTime
                    }
                }
            }
        }

        # overwrite the events file to update the successful timestamps with the time we started running this script
        $desiredLogs | ConvertTo-Json -Depth 4 > $file.FullName
    }
} else {
    Write-EventLog -LogName "Application" -Source "Windows_Signal" -EventID 9000 -EntryType Critical -Message "No events file found at $eventsJsonFilePath."
    Write-Verbose "No events file found at $eventsJsonFilePath."
    exit 1
}
