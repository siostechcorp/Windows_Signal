#######################################################################################################################
# Send-Signal.ps1
# 
# Parse System event log for specifc log, sources, and ids defined in the json files located at the 
# $eventsJsonFilePath. Should be configured to run on a schedule via Task Scheduler. 
#
# Requires Python27 to be in the PATH environment variable.
#
# Examples:
#     PS> Send-Signal 
#     PS> Send-Signal -Pyscript ".\report_event.py" -EventsJsonFilePath ".\" 
#
#######################################################################################################################

[CmdletBinding()]
Param(    
    [String] $pyscript       = ".\report_event.py",
    [String] $eventsJsonFilePath = ".\"
)

function Send-Events {
    [CmdletBinding()]
    Param(
        [Object[]] $EventCollection,
        [String] $Source,
        [PSCustomObject] $FiltersPSCustomObject
    )

    if($EventCollection -eq $Null) {
        Write-Verbose "eventcollection passed to Report-Events was null"
        return 0   
    } 
    if($FiltersPSCustomObject -eq $Null) {
        Write-Verbose "no filters found in FiltersPSCustomObject"
        return 1
    }

    # Create a proper hashtable out of the PSCustomObject created from the ids json field down. The keys below 
    # correspond to the different ids, and the filters are an array of the filter text for each id. So filterTable
    # is a hashtable with elements of type <string, string[]>
    $filterTable = [System.Collections.Hashtable]@{}
    $keys = ($FiltersPSCustomObject | Get-Member | Where-Object -Property "MemberType" -eq "NoteProperty").Name
    foreach ($key in $keys) {
        $filters = ($FiltersPSCustomObject.$key | Get-Member | Where-Object -Property "MemberType" -eq "NoteProperty").Name
        $filterTable.Add($key, $filters) > $Null
    }

    foreach ( $evt in $EventCollection ) {
        # only report events from node running this script
        if ( ($evt.MachineName -like "$env:COMPUTERNAME") -Or ($evt.MachineName -like "$env:COMPUTERNAME.$env:USERDNSDOMAIN") ) {

            $evt_summary = $evt_type = $evt_severity = $evt_category = $evt_layers = $Null
            # check if event message matches one of the filters for this event's id
            foreach ($filter in $filterTable.($evt.EventID.ToString())) {

                # Try to match a filter from this event id in the hashtable to the event message (-Not $Null is a pattern match)
                if (-Not (($evt.Message | Select-String -Pattern $filter) -eq $Null)) {

                    $evt_summary  = $FiltersPSCustomObject.($evt.EventID.ToString()).$filter[0]
                    $evt_type     = $FiltersPSCustomObject.($evt.EventID.ToString()).$filter[1]
                    $evt_severity = $FiltersPSCustomObject.($evt.EventID.ToString()).$filter[2]
                    $evt_category = $FiltersPSCustomObject.($evt.EventID.ToString()).$filter[3]
                    
                    $evt_layers = [System.Collections.ArrayList]@()

                    $i = 4
                    while(-Not $FiltersPSCustomObject.($evt.EventID.ToString()).$filter[$i] -eq 0) {
                        $evt_layers.Add($FiltersPSCustomObject.($evt.EventID.ToString()).$filter[$i])
                        $i++
                    }
                }
            }

            # don't report this event if no filter matched the message
            if ($evt_summary -eq $Null) {
                Write-Verbose ("No filter found in " + $evt.Message + ". Skipping event.")
                Continue
            }
            
            $tz = Get-TimeZone
            $tzinfo = $tz.BaseUtcOffset.Hours.ToString("00") + [Math]::abs($tz.BaseUtcOffset.Minutes).ToString("00")

            foreach ($layer in $evt_layers) {
                Write-Verbose ("Sending the following event details to the python script:`n" + $Source + "`n" + $evt.EventID + "`n" + $evt_severity + "`n" + $evt.Message + "`n" + ($evt.TimeGenerated.ToString("yyyy-MM-ddTHH:mm:ss") + $tzinfo) + "`n" + $evt_summary + "`n" + $evt_type + "`n" + $evt_category + "`n" + $layer)

                Invoke-Command -ScriptBlock { 
                    Param(
                        [string] $a1, 
                        [string] $a2, 
                        [string] $a3, 
                        [string] $a4, 
                        [string] $a5,
                        [string] $a6,
                        [string] $a7,
                        [string] $a8,
                        [string] $a9
                    ) 

                    &'python' $pyscript $a1 $a2 $a3 $a4 $a5 $a6 $a7 $a8 $a9

                } -ArgumentList @(
                    $Source,
                    $evt.EventID,
                    $evt_severity,
                    $evt.Message,
                    ($evt.TimeGenerated.ToString("yyyy-MM-ddTHH:mm:ss") + $tzinfo),
                    $evt_summary,
                    $evt_type,
                    $evt_category,
                    $layer
                )
            }
        }
    }

    return 0
}

### ENTRY POINT #######################################################################################################

# parse the current epoch time as a signed long, then create DateTime object from it
$nowUnixTime = [long] (Get-Date -Date ((Get-Date).ToUniversalTime()) -UFormat %s)
$nowUniversalDateTime = (([datetime]'1/1/1970').AddSeconds($nowUnixTime)).ToLocalTime()
Write-Verbose "time now is $nowUniversalDateTime"

if(Test-Path -Path $eventsJsonFilePath) {

    $jsonFiles = Get-ChildItem -Path $eventsJsonFilePath -Filter "*.json"
    foreach ($file in $jsonFiles) {

        # parse the events json file(s) into a PSCustomObject
        $desiredLogs = Get-Content -Raw -Path $file.FullName | ConvertFrom-Json

        # parse out the event logs (Application, System, etc) we need to scan containing the events we care about from the json file(s)
        if ($desiredLogs -ne $Null) {
            $eventLogs = $desiredLogs | Get-Member | Where-Object -Property "MemberType" -eq "NoteProperty" | foreach { $_.Name }
        } else {
            Write-EventLog -LogName "Application" -Source "Windows_Signal" -EventID 9001 -EntryType Critical -Message "Failed to parse events file found at $eventsJsonFilePath. Either no events of interest have been configured or the file is corrupt."
            Write-Verbose "Failed to parse events file " + $file.FullName + ". Either no events of interest have been configured or the file is corrupt."
        }

        foreach ($log in $eventLogs) {
            
            # parse out the sources that issue the events we care about so that we can query the target log for just those sources    
            $eventSources = $desiredLogs.$log | Get-Member | Where-Object -Property "MemberType" -eq "NoteProperty" | foreach { $_.Name }
            
            foreach ($source in $eventSources) {

                Write-Verbose "Looking for events from $log and $source..."

                # parse the last epoch time this script succeeded then create DateTime object from it 
                $lastUnixTime = [long]$desiredLogs.$log.$source.lastReportTime
                if ($lastUnixTime -eq 0) {
                    Write-Verbose "SETTING LAST UNIX TIME TO 5 MIN AGO"
                    $lastUnixTime = $nowUnixTime - 301 # if no time was recorded for last successful run, then just get last five minutes.
                } else {
                    $lastUnixTime -= 1;   # so we catch the missing second from the last time we ran Get-EventLog
                }

                $lastUniversalDateTime = (([datetime]'1/1/1970').AddSeconds($lastUnixTime)).ToLocalTime()
                Write-Verbose "lastUnixTime: $lastUnixTime"
                Write-Verbose "last successful run was performed at $lastUniversalDateTime"        

                # Get events from the specified $log and $source between the last run and the start of this one, but only those with ids 
                # as specified in the json file for this log and source.
                $events = Get-EventLog -LogName $log -After $lastUniversalDateTime -Before $nowUniversalDateTime -Source $source | Where-Object { 
                    ($desiredLogs.$log.$source.ids | Get-Member -MemberType NoteProperty).Name -Contains $_.EventId.ToString()
                } 
                
                # Package and send these events to the iQ appliance if they match the events specified in this json file (passed in via -FilersPSCustomObject)
                Send-Events -EventCollection $events -Source $source -FiltersPSCustomObject ($desiredLogs.$log.$source.ids)

                # update the timestamps for this $log,$source if Report-Events succeeded
                if ($?) {
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
        $desiredLogs | ConvertTo-Json -Depth 5 > $file.FullName
    }
} else { # fail this run as the path containing the events json file(s) is not reachable
    Write-EventLog -LogName "Application" -Source "Windows_Signal" -EventID 9000 -EntryType Critical -Message "No events file found at $eventsJsonFilePath."
    Write-Verbose "No events file found at $eventsJsonFilePath."
    exit 1
}
