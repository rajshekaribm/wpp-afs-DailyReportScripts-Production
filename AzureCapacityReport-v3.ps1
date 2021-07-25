<#
.SYNOPSIS
  This script will get Storage Capacity details of Azure Storage accounts and its File Shares details from Tenants already logged in and sends email.

.PRE-CHECKS
  1. Install the Azure Powershell Module - https://docs.microsoft.com/en-us/powershell/azure/install-az-ps?view=azps-5.2.0
  2. Install ImportExcel Module
  3. Make sure to login Azure subscription before running script
  Example: Connect-AzAccount -Tenant 2b755fa1-23d1-48f3-98fc-6fdc1dc48d69

.INPUTS
  NA

.OUTPUTS
  Generates output files in both CSV and Excel format at "C:\" location and BOX location as well

.NOTES
  Version:        3.0
  Author:         Narasimha R Duggu/ Narduggu@in.ib.com
  Creation Date:  20210316

.EXAMPLE
 Set-ExecutionPolicy -ExecutionPolicy RemoteSigned
 Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
 powershell.exe -ExecutionPolicy ByPass -File .\AzureCapacityReport.ps1'

.EXAMPLE
.\AzureCapacityReport-v3.ps1'
#>


$todaydate=(Get-Date).ToString('yyyy-MM-dd')
$report=@()
$Countreport=@()

$AzSubs = (Get-AzSubscription).Name #| ?{$_ -ne 'KT-SHARED-StorSimpleGL'}

foreach($sub in $AzSubs){
    Select-AzSubscription -Subscription "$sub"

    $RGs = Get-AzResourceGroup | select ResourceGroupName
        foreach($CurrentRGs in $RGs){
            $CurrentRG = $CurrentRGs.ResourceGroupName

            $StorageAccounts = Get-AzStorageAccount -ResourceGroupName $CurrentRG #| select StorageAccountName,PrimaryLocation
            foreach($StorageAccount in $StorageAccounts){
                $SA = $StorageAccount.StorageAccountName
                $Location = $StorageAccount.PrimaryLocation

                $SAAccessTier = $StorageAccount.AccessTier
                $LargeFileShares = $StorageAccount.LargeFileShares
                $skuName = $StorageAccount.SkuName
                        
                $FileSVCID = (Get-AzStorageFileServiceProperty -ResourceGroupName $CurrentRG -StorageAccountName $SA).Id
                $FileCount = (Get-AzMetric  -ResourceId $FileSVCID -MetricName "FileCount").Data
                $AvgFileCount = $FileCount.Average

                ## Get Tagging Details
                $opcoTag = (Get-AzResource -Name $SA | select Tags).Tags.opco

                $FileShares = Get-AzRmStorageShare -ResourceGroupName $CurrentRG -StorageAccountName $SA #| Select-Object Name

                $NoOfShares= ($FileShares.name).Count

                ## Get Total Storage Account UsedCapacity in GiB
                $CurrentSAID = (Get-AzStorageAccount -ResourceGroupName $CurrentRG -AccountName $SA).Id 
                echo "$CurrentSAID"

                $usedCapacity = (Get-AzMetric  -ResourceId $CurrentSAID -TimeGrain 01:00:00 -MetricName "UsedCapacity").Data.Average
                echo "$usedCapacity"

                $usedCapacityInGiB = ([math]::Round($usedCapacity / 1024 / 1024 / 1024,2))
                echo "$SA : $usedCapacityInGiB"
            
                ## Get File Shares UsedCapacity in GiB
                $FileShares = Get-AzRmStorageShare -ResourceGroupName $CurrentRG -StorageAccountName $SA  #| Select-Object Name
                foreach($FS in $FileShares){
                    $FileShareName = $FS.Name
                    $FileShareTier = $FS.AccessTier
                    $ShareUsedCapacity = (Get-AzRmStorageShare -ResourceGroupName $CurrentRG -StorageAccountName $SA -Name $FileShareName -GetShareUsage | Select-Object ShareUsageBytes)
                    $ShareUsedCapacityInGiB = [math]::Round($ShareUsedCapacity.ShareUsageBytes / 1024 / 1024 / 1024,2)
            
                    #Generate Storage UsageCapacity Report
                    $data = New-Object PSObject
                    $data | Add-Member NoteProperty opco -Value $opcoTag
                    $data | Add-Member NoteProperty ResourceGroupName -Value $CurrentRG
                    $data | Add-Member NoteProperty StorageAccount -Value $SA
                    $data | Add-Member NoteProperty Location -Value $Location
                    $data | Add-Member NoteProperty AzureFileShareName -Value $FileShareName
                    $data | Add-Member NoteProperty FileShareTier -Value $FileShareTier
                    $data | Add-Member NoteProperty AFSUsedCapacityInGiB -Value $ShareUsedCapacityInGiB
                    $report+=$data
                }

                # Generate FileCount Report
                $Count = New-Object PSObject
                $Count | Add-Member NoteProperty opco -Value $opcoTag
                $Count | Add-Member NoteProperty ResourceGroupName -Value $CurrentRG
                $Count | Add-Member NoteProperty StorageAccount -Value $SA
                $Count | Add-Member NoteProperty SAUsedCapacityInGiB -Value $usedCapacityInGiB
                $Count | Add-Member NoteProperty AvgFileCount -Value $AvgFileCount
                $Count | Add-Member NoteProperty NoOfShares -Value $NoOfShares
                $Count | Add-Member NoteProperty SAAccessTier -Value $SAAccessTier
                $Count | Add-Member NoteProperty LargeFileShares -Value $LargeFileShares
                $Countreport+=$Count



            }
        }
}

$Countreport | Export-Csv -NoTypeInformation -Path "C:\AFS-CapacityReportFileCount-$todaydate.csv"
$report | Export-Csv -NoTypeInformation -Path "C:\AFS-CapacityReport-$todaydate.csv"

# Convert it to Excel in Table format
Import-Csv "C:\AFS-CapacityReportFileCount-$todaydate.csv" | Export-Excel -WorksheetName CapacityReport "C:\AFS-CapacityReport-$todaydate.xlsx" -DisplayPropertySet -TableName CapacityTable
Import-Csv "C:\AFS-CapacityReport-$todaydate.csv" | Export-Excel -WorksheetName AvgFileCountReport "C:\AFS-CapacityReport-$todaydate.xlsx" -DisplayPropertySet -TableName AvgFileCountTable


# Send email to members
$EmailSubject = "WPP AFS Capacity Report -$todaydate"
$EmailBody = "Dear All <br> <br>" 
$EmailBody += "Please find attached AFS Capacity Report; same has been uploaded into BOX location. Click <a href=https://ibm.ent.box.com/folder/129675222846>here</a> to open <br> <br>" 
$EmailBody += "Thank you <br>"
$EmailBody += "WPP IBM Azure Cloud Team <br> <br> <br>"
$EmailBody += "This is an automatic generated email, Please reachout to WPP IBM AFS Team (ibm-in-wppafsteam@wwpdl.vnet.ibm.com) for any concerns.<br>"
$params = @{
    To = 'ibm-in-wppafsteam@wwpdl.vnet.ibm.com','afs_rep.kzuz67jdh69rmznk@u.box.com'
    From = 'ibm-in-wppafsteam@wwpdl.vnet.ibm.com' 
    Subject = "$EmailSubject"
    Body = "$EmailBody"
    BodyAsHtml = $true
    SmtpServer = "d06av24.portsmouth.uk.ibm.com"
    Attachments = "C:\AFS-CapacityReport-$todaydate.xlsx"
}
Send-MailMessage @params
