<#
.SYNOPSIS
  This script will search AFS Agent Telemetry Eventlog for two EventIds (9102 and 9301).
  If found it will create new events in Application log if messages' content are not zero
  9301 should be "GetNextJob completed with status: 0"
  9102 should be "HResult: 0" and "PerItemErrorCount:0"

.NOTES
  Version:        0.3
  Author:         Narasimha Reddy / nardugu@in.ibm.com
  Creation Date:  20201125
  
.EXAMPLE
  powershell.exe -ExecutionPolicy ByPass -File .\EventLogCheckAFS.ps1
#>
[CmdletBinding()]
#requires -version 2

$ErrorActionPreference = "SilentlyContinue"

if ($PSCommandPath -eq $null) { function GetPSCommandPath() { return $MyInvocation.PSCommandPath; } $PSCommandPath = GetPSCommandPath; }

if(!([System.Diagnostics.EventLog]::SourceExists("AfsAgent")))
   {
     New-EventLog -LogName "Application" -Source "AFSAgent"
    }

$TimeFilter = (Get-Date) - (New-TimeSpan -Hour 1)

################################
# Process 9102 events
$Filter = @{
		LogName = 'Microsoft-FileSync-Agent/Telemetry'
		ID = 9102
		StartTime=$TimeFilter
    }
#$Result = Get-WinEvent -FilterHashtable $Filter | Sort-Object TimeCreated -Descending | select -First 1 | where {($_.Message -like "*HResult*" -And $_.Message -NotLike "*HResult: 0*")}

$Result = Get-WinEvent -FilterHashtable $Filter | Sort-Object TimeCreated -Descending | select -First 1  | where {($_.Message -like "*HResult*" -And $_.Message -NotLike "*HResult: 0*" -or $_.Message -notlike "*PerItemErrorCount: 0*")}

#Uncomment line below to trigger false positive
#$Result = Get-WinEvent -FilterHashtable $Filter | Sort-Object TimeCreated -Descending | select -First 1 | where {($_.Message -like "*HResult*")}

# Check result
if(!($Result -eq $null))
	{
		$ResultOrigEventLog = $Filter.LogName
		$ResultOrigTimestamp = $(($Result.TimeCreated).ToLocalTime()).ToString("yyyyMMdd_HHmmss")
		$ResultExtendedMessage = $Result.Message + "`nOriginal Eventlog timestamp: " + $ResultOrigTimestamp + "`nFrom '$ResultOrigEventLog'`nServername: $env:computername.$env:userdnsdomain"
		Write-EventLog -LogName "Application" -Source "AFSAgent" -EventID $Result.Id -EntryType Error -Message $ResultExtendedMessage | Out-Null
	}
# End process 9102 events
################################

# Clear $Result
$Result = $null

################################
# Process 9301 events
$Filter = @{
		LogName = 'Microsoft-FileSync-Agent/Telemetry'
		ID = 9301
		StartTime=$TimeFilter
    }
$Result = Get-WinEvent -FilterHashtable $Filter | Sort-Object TimeCreated -Descending | select -First 1 | where {($_.Message -like "GetNextJob*" -And $_.Message -NotLike "GetNextJob completed with status: 0*")}
#Uncomment line below to trigger false positive
#$Result = Get-WinEvent -FilterHashtable $Filter | Sort-Object TimeCreated -Descending | select -First 1 | where {($_.Message -like "GetNextJob*")}

# Check result
if(!($Result -eq $null))
	{
		$ResultOrigEventLog = $Filter.LogName
		$ResultOrigTimestamp = $(($Result.TimeCreated).ToLocalTime()).ToString("yyyyMMdd_HHmmss")
		$ResultExtendedMessage = $Result.Message + "`nOriginal Eventlog timestamp: " + $ResultOrigTimestamp + "`nFrom '$ResultOrigEventLog'`nServername: $env:computername.$env:userdnsdomain"
		Write-EventLog -LogName "Application" -Source "AFSAgent" -EventID $Result.Id -EntryType Error -Message $ResultExtendedMessage | Out-Null
	}
# End process 9301 events
################################

Write-EventLog -LogName "Application" -Source "AFSAgent" -EventID 100 -EntryType Information -Message "Heartbeat OK`n$PSCommandPath was executed.`nServername: $env:computername.$env:userdnsdomain" | Out-Null
