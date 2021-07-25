<#
.SYNOPSIS
This script will get Azure Storage accounts File Share Sync Status from Tenants already logged in and uploads file into BOX Location.

.PRE-CHECKS
1. Install the Azure Powershell Module - https://docs.microsoft.com/en-us/powershell/azure/install-az-ps?view=azps-5.2.0
2. Install ImportExcel Module
3. Make sure to login Azure subscription before running script
Example: Connect-AzAccount -Tenant 46dfce19-1520-4a06-b353-e97212f09cfa

Connect-AzAccount -Tenant 2b755fa1-23d1-48f3-98fc-6fdc1dc48d69

.INPUTS
NA

.OUTPUTS
Generates output files in both CSV and HTML format at "C:\" location and BOX location as well

.NOTES
Version:        2.0
Author:         Narasimha R Duggu/ Narduggu@in.ib.com
Creation Date:  20210129

.EXAMPLE
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
powershell.exe -ExecutionPolicy ByPass -File .\AzureSyncStatus.ps1'

.EXAMPLE
.\AzureSyncStatus.ps1'
#>

$Reporttime = (Get-Date).ToString('yyyy-MM-dd-hh-mm')
$todaydate = (Get-Date).ToString('yyyy-MM-dd')
$report = @()

$AzSubs = (Get-AzSubscription).Name #| ?{ $_ -eq 'VMLYR_Internal_AP' }
foreach ($sub in $AzSubs) {
    Select-AzSubscription -Subscription "$sub"
    $listss = Get-AzResource -ResourceType Microsoft.StorageSync/storageSyncServices | Select-Object -Property Name, ResourceGroupName
    foreach ($line in $listss) {
        echo $line
        $ss = $line.Name
        $rgName = $line.ResourceGroupName
        $ssg = Get-AzStorageSyncGroup -ResourceGroupName $rgName -StorageSyncServiceName $ss | Select-Object -Property SyncGroupName
        foreach ($isg in $ssg) {
            $sg = $isg.SyncGroupName
            
            # Get Storage account and Azure File Share details
            $StorageDetails = Get-AzStorageSyncCloudEndpoint -ResourceGroupName $rgName -StorageSyncServiceName $ss -SyncGroupName $sg
            $FileShare = $StorageDetails.AzureFileShareName
            $StorageAccount = $StorageDetails.StorageAccountResourceId.Split("/")[8]

            ## Get Tagging Details
            $Tags = Get-AzTag -ResourceId $StorageDetails.StorageAccountResourceId | Select-Object -Property Properties
            $opco = $Tags.Properties.TagsProperty.opco
            
            if ($Tags.Properties.TagsProperty.opco -eq $null) {
                $opco = $Tags.Properties.TagsProperty.OpCo
            }

            if (($Tags.Properties.TagsProperty.opco -eq $null) -and ($Tags.Properties.TagsProperty.OpCo -eq $null)) {
                $opco = $Tags.Properties.TagsProperty.Opco
            }

            # Get Registered Server End point with LocalPath Details
            [array]$SyncData = Get-AzStorageSyncServerEndpoint -ResourceGroupName $rgName -StorageSyncServiceName $ss -SyncGroupName $sg

            if ($SyncData.Length -ge 1) {

                for ($fcounter = 0; $fcounter -lt $SyncData.Length; $fcounter++) {

                    $ServerName = $SyncData.Get($fcounter).FriendlyName
                    $path = $SyncData.Get($fcounter).ServerLocalPath
                    $provisionStatus = $SyncData.Get($fcounter).ProvisioningState
                    $CloudTiering = $SyncData.Get($fcounter).CloudTiering
                    $VolumeFreeSpacePercent = $SyncData.Get($fcounter).VolumeFreeSpacePercent

                    #Get Sync Status with details
                    $SStatus = $SyncData.Get($fcounter).SyncStatus

                    $PerItemErrCount_Upload = $SStatus.UploadStatus.LastSyncPerItemErrorCount
                    $PerItemErrCount_Download = $SStatus.DownloadStatus.LastSyncPerItemErrorCount
                    $Health = $SStatus.CombinedHealth
                    $TotalUploadActivity = [math]::Round($SStatus.UploadActivity.TotalBytes / 1GB, 2)
                    $AppliedUploadActivity = [math]::Round($SStatus.UploadActivity.AppliedBytes / 1GB, 2)
                    $SyncActivity = $SStatus.SyncActivity
                    if ($SyncActivity -eq $null) {
                        $SyncActivity = 'Completed'        
                    }
                    elseif (($SyncActivity -eq 'Upload' -or $SyncActivity -eq 'UploadAndDownload') -and $TotalUploadActivity -ne 0 ) {
                        $SyncActivity = 'Upload In Progress'
                    }
                    elseif (($SyncActivity -eq 'Upload' -or $SyncActivity -eq 'UploadAndDownload') -and $TotalUploadActivity -eq 0 ) {
                        $SyncActivity = 'Download In Progress'
                    }
                    $PendingUploadActivity = $TotalUploadActivity - $AppliedUploadActivity
                    $LastSync = $SStatus.LastUpdatedTimestamp
                    
                    $data = New-Object PSObject
                    $data | Add-Member NoteProperty opco -Value $opco
                    $data | Add-Member NoteProperty FileServerName -Value $ServerName
                    $data | Add-Member NoteProperty StorageAccount -Value $StorageAccount
                    $data | Add-Member NoteProperty ResourceGroupName -Value $rgName
                    $data | Add-Member NoteProperty StorageSyncServiceName -Value $ss
                    $data | Add-Member NoteProperty StorageSyncGroupName -Value $sg
                    $data | Add-Member NoteProperty ServerLocalPath -Value $path
                    $data | Add-Member NoteProperty AzureFileShareName -Value $FileShare
                    $data | Add-Member NoteProperty SyncHealth -Value $Health
                    $data | Add-Member NoteProperty PerItemErrCount_Upload -Value $PerItemErrCount_Upload
                    $data | Add-Member NoteProperty PerItemErrCount_Download -Value $PerItemErrCount_Download
                    $data | Add-Member NoteProperty SyncActivity -Value $SyncActivity
                    $data | Add-Member NoteProperty LastSyncTimestamp -Value $LastSync.ToString()
                    $data | Add-Member NoteProperty TotalUploadActivity -Value $TotalUploadActivity
                    $data | Add-Member NoteProperty AppliedUploadActivity -Value $AppliedUploadActivity
                    $data | Add-Member NoteProperty PendingUploadActivity -Value $PendingUploadActivity
                    $data | Add-Member NoteProperty CloudTiering -Value $CloudTiering
                    $data | Add-Member NoteProperty VolumeFreeSpacePercent -Value $VolumeFreeSpacePercent
                    $report += $data
                }
            }
        }
    }
}
$report | Export-Csv -NoTypeInformation -Path C:/OUT-SyncReport.csv

# Prepare Pivot Table
Import-Csv C:\OUT-SyncReport.csv | Export-Excel -WorksheetName SyncReport "C:\AFS-SyncReport-$Reporttime.xlsx" -DisplayPropertySet -TableName ServiceTable `
    -IncludePivotTable `
    -PivotRows 'OpCo', 'FileServerName' `
    -PivotColumns 'SyncActivity' `
    -PivotData @{SyncActivity = 'count' }

# Send email to members and upload file to BOX Location.
$EmailSubject = "AFS Daily Sync Report -$todaydate"
$EmailBody = "Dear All <br> <br>" 
$EmailBody += "Please find attached AFS Sync Report; same has been uploaded into BOX Location. Click <a href=https://ibm.ent.box.com/folder/129675222846>here</a> to open <br> <br>" 
$EmailBody += "Thank you <br>"
$EmailBody += "WPP IBM Azure Cloud Team <br> <br> <br>"
$EmailBody += "This is an automatic generated email, Please reachout to WPP IBM AFS Team (ibm-in-wppafsteam@wwpdl.vnet.ibm.com) for any concerns.<br>"
$params = @{
    To          = 'ibm-in-wppafsteam@wwpdl.vnet.ibm.com', 'afs_rep.kzuz67jdh69rmznk@u.box.com'
    From        = 'ibm-in-wppafsteam@wwpdl.vnet.ibm.com' 
    Subject     = "$EmailSubject"
    Body        = "$EmailBody"
    BodyAsHtml  = $true
    SmtpServer  = 'd06av23.portsmouth.uk.ibm.com' 
    Attachments = "C:\AFS-SyncReport-$Reporttime.xlsx"
}
Send-MailMessage @params
