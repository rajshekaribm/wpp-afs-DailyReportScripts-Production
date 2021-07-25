# Script to get latest timestamp of Event ID 100 generated.

$lastevent = Get-EventLog -LogName Application -InstanceId 100 -Newest 1
Write-Host "Latest Event ID $($lastevent.InstanceId) on $(hostname) is $($lastevent.TimeGenerated)"
