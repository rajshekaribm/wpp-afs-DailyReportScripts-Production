<#
.SYNOPSIS
  This script will get Azure Sync and Backup Jobs status of last 7 days from Recovery Services Vault from Tenants already logged in and uploads file into BOX Location..
.PRE-CHECKS
  1. Install the Azure Powershell Module - https://docs.microsoft.com/en-us/powershell/azure/install-az-ps?view=azps-5.2.0
  2. Install ImportExcel Module
  3. Make sure to login Azure subscription before running script
  Example: Connect-AzAccount -Tenant 86xxx1bb-2xxf-4271-b174-bd59dxxx87a3 
  Connect-AzAccount -Tenant 2b755fa1-23d1-48f3-98fc-6fdc1dc48d69
  4. Make sure you already have ran Sync script for report to generate consolidated report.
.INPUTS
  Locate and place Sync report at 'C:\' with name 'OUT-SyncReport.csv'
.OUTPUTS
  Generates output files in both CSV and EXCEL format at "C:\" location and BOX location as well
.NOTES
  Version:        2.0
  Author:         Narasimha R Duggu/ Narduggu@in.ib.com
  Creation Date:  20210129
.EXAMPLE
 powershell.exe -ExecutionPolicy ByPass -File .\AzDailyBackupJobs.ps1'
.EXAMPLE
.\AzDailyBackupJobs.ps1
#>
$report=@()
$Reporttime=(Get-Date).ToString('yyyy-MM-dd-hh-mm')
$todaydate=(Get-Date).ToString('yyyy-MM-dd')
$AzSubs = (Get-AzSubscription).Name #| ?{$_ -ne 'KT-SHARED-StorSimpleGL'}
foreach($sub in $AzSubs){
    Select-AzSubscription -Subscription "$sub"
    #Get Recovery Vault details
    $rv = Get-AzRecoveryServicesVault | Select-Object -Property Name,ResourceGroupName,ID,Location
    foreach($vault in $rv){
        $rvname = $vault.Name
        $rg = $vault.ResourceGroupName
        $rvid = $vault.ID
        $location = $vault.Location
        #Get Opco Tag value from Recovery Service Vault
        $Tags = Get-AzTag -ResourceId $rvid | Select-Object -Property Properties
        $opco = $Tags.Properties.TagsProperty.opco
        #Get Storage Account Inforamtion
        $SAccounts = Get-AzRecoveryServicesBackupContainer -ContainerType AzureStorage -Status Registered -VaultId $rvid 
        $Jobs = Get-AzRecoveryServicesBackupJob -Operation Backup -From (Get-Date).AddDays(-7).ToUniversalTime() -VaultId $rvid  | select * #Select-Object -Property WorkloadName,Operation,Status,StartTime,EndTime
        foreach($sa in $SAccounts){
            $Sharename = (Get-AzRecoveryServicesBackupItem -Container $sa -WorkloadType AzureFiles -VaultId $rvid).FriendlyName
            $saName = $sa.FriendlyName
            if ($saName -ne $preventry) {
                foreach($FileShare in $Sharename){
                    echo $FileShare
                    for ($fcounter=0; $fcounter -lt $Jobs.Length; $fcounter++){
                        $Operation = $Jobs.Get($fcounter).Operation
                        $Status = $Jobs.Get($fcounter).Status
                        $StartTime = $Jobs.Get($fcounter).StartTime
                        $EndTime = $Jobs.Get($fcounter).EndTime
                        $JobID = $Jobs.Get($fcounter).JobId
                        $WorkloadName = $Jobs.Get($fcounter).WorkloadName
                        if($FileShare -eq $WorkloadName -and $saName -ne $preventry){
                            $data = New-Object PSObject
                            $data | Add-Member NoteProperty opco -Value $opco
                            $data | Add-Member NoteProperty ResourceGroupName -Value $rg
                            $data | Add-Member NoteProperty Location -Value $location
                            $data | Add-Member NoteProperty RecoveryServicesVaultName -Value $rvname
                            $data | Add-Member NoteProperty StorageAccount -Value $saName
                            $data | Add-Member NoteProperty AzureFileShareName -Value $WorkloadName
                            $data | Add-Member NoteProperty Operation -Value $Operation
                            $data | Add-Member NoteProperty BackupJobStatus -Value $Status
                            $data | Add-Member NoteProperty BackupJobStartTime -Value $StartTime
                            $data | Add-Member NoteProperty BackupJobEndTime -Value $EndTime
                            $report+=$data | Sort-Object -Property BackupJobStartTime -Descending
                        }
                    }
                }
            $preventry = $saName
            }
        }
    }
}
$report | Export-Csv -NoTypeInformation -Path C:\DUP-OUT-DailyBackupJobsReport.csv
#Getting the Path of CSV file
$inputCSVPath = 'C:\DUP-OUT-DailyBackupJobsReport.csv'
#The Import-Csv cmdlet creates table-like custom objects from the items in CSV files
$inputCsv = Import-Csv $inputCSVPath | Sort-Object -Property StorageAccount,AzureFileShareName,BackupJobStartTime -Unique
#The Export-CSV cmdlet creates a CSV file of the objects that you submit. 
#Each object is a row that includes a comma-separated list of the object's property values.
$inputCsv | Export-Csv "C:\UNQ-OUT-DailyBackupJobsReport.csv"  -NoTypeInformation
<#
#To create consolidated report of Daily Backup and Sync with required details
#>
$conreport=@()
$BackupReport = Import-Csv -Path 'C:\UNQ-OUT-DailyBackupJobsReport.csv'
$SyncReport = Import-Csv -Path 'C:\OUT-SyncReport.csv'
$StorageAccountInBoth = Compare-Object -ReferenceObject $SyncReport.StorageAccount -DifferenceObject $BackupReport.StorageAccount -IncludeEqual |
Where-Object {$_.SideIndicator -eq "=="} |
Select-Object -ExpandProperty InputObject -Unique
ForEach($asa in $StorageAccountInBoth) {
    $b = $BackupReport | Where-Object {$_.StorageAccount -eq $asa}
    [Array]$s = $SyncReport | Where-Object {$_.StorageAccount -eq $asa} 
    for ($scounter=0; $scounter -lt $s.Length; $scounter++){
        for ($counter=0; $counter -lt $b.Length; $counter++){
            if($b.Get($counter).AzureFileShareName -eq $s.Get($scounter).AzureFileShareName -and $b.Get($counter).StorageAccount -eq $s.Get($scounter).StorageAccount){
                        $stat = New-Object PSObject
                        $stat | Add-Member NoteProperty opco -Value $b.Get($counter).opco
                        $stat | Add-Member NoteProperty FileServerName -Value $s.Get($scounter).FileServerName
                        $stat | Add-Member NoteProperty ResourceGroupName -Value $b.Get($counter).ResourceGroupName
                        $stat | Add-Member NoteProperty Location -Value $b.Get($counter).Location
                        $stat | Add-Member NoteProperty RecoveryServicesVaultName -Value $b.Get($counter).RecoveryServicesVaultName
                        $stat | Add-Member NoteProperty StorageAccount -Value $b.Get($counter).StorageAccount
                        $stat | Add-Member NoteProperty AzureFileShareName -Value $b.Get($counter).AzureFileShareName
                        $stat | Add-Member NoteProperty Operation -Value $b.Get($counter).Operation
                        $stat | Add-Member NoteProperty BackupJobStatus -Value $b.Get($counter).BackupJobStatus
                        $stat | Add-Member NoteProperty SyncHealth -Value $s.Get($scounter).SyncHealth
                        $stat | Add-Member NoteProperty PerItemErrCount_Upload -Value $s.Get($scounter).PerItemErrCount_Upload
                        $stat | Add-Member NoteProperty PerItemErrCount_Download -Value $s.Get($scounter).PerItemErrCount_Download
                        $stat | Add-Member NoteProperty FileServerLocalPath -Value $s.Get($scounter).ServerLocalPath
                        $stat | Add-Member NoteProperty SyncActivity -Value $s.Get($scounter).SyncActivity
                        $stat | Add-Member NoteProperty LastSyncTimestamp -Value $s.Get($scounter).LastSyncTimestamp
                        $stat | Add-Member NoteProperty BackupJobStartTime -Value $b.Get($counter).BackupJobStartTime
                        $stat | Add-Member NoteProperty BackupJobEndTime -Value $b.Get($counter).BackupJobEndTime
                        $conreport+=$stat | Sort-Object -Property BackupJobStartTime -Descending
            }
        }
    }
}
$conreport | Export-Csv -NoTypeInformation -Path C:\AFS-DailyBackupJobsReport.csv
## Prepare Pivot Table
Import-Csv C:\AFS-DailyBackupJobsReport.csv | Export-Excel -WorksheetName DailyBackupJobsReport "C:\AFS-DailyBackupJobsReport-$Reporttime.xlsx" -DisplayPropertySet -TableName ServiceTable `
    -IncludePivotTable `
    -PivotRows 'opco','StorageAccount','AzureFileShareName' `
    -PivotColumns 'BackupJobStatus' `
    -PivotData @{BackupJobStatus='count'}
# Send email to members and upload file to BOX Location.
$EmailSubject = "AFS Daily Sync and BackUp Report - $todaydate"
$EmailBody = "Dear All <br> <br>" 
$EmailBody += "Please find attached AFS Sync and Backup Report; same has been uploaded into BOX location. Click <a href=https://ibm.ent.box.com/folder/129675222846>here</a> to open <br> <br>" 
$EmailBody += "Thank you <br>"
$EmailBody += "WPP IBM Azure Cloud Team <br> <br> <br>"
$EmailBody += "This is an automatic generated email, Please reachout to WPP IBM AFS Team (ibm-in-wppafsteam@wwpdl.vnet.ibm.com) for any concerns.<br>"
$params = @{
    To = 'ibm-in-wppafsteam@wwpdl.vnet.ibm.com','afs_rep.kzuz67jdh69rmznk@u.box.com'
    From = 'ibm-in-wppafsteam@wwpdl.vnet.ibm.com' 
    Subject = "$EmailSubject"
    Body = "$EmailBody"
    BodyAsHtml = $true
    SmtpServer = 'd06av23.portsmouth.uk.ibm.com' 
    Attachments = "C:\AFS-DailyBackupJobsReport-$Reporttime.xlsx"
}
Send-MailMessage @params
