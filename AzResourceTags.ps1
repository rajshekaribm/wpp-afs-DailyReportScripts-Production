<#
.SYNOPSIS
  This script will get Tagging information of Azure File Sync resources from Tenants already logged in.
.PRE-CHECKS
  1. Install the Azure Powershell Module - https://docs.microsoft.com/en-us/powershell/azure/install-az-ps?view=azps-5.2.0
  2. Install ImportExcel Module
  3. Make sure to login Azure subscription before running script
  Example: Connect-AzAccount -Tenant 46dfce19-1520-4a06-b353-e97212f09cfa
  
.INPUTS
  NA
.OUTPUTS
  Generates output files in both CSV and HTML format at "C:\" location and BOX location as well
.NOTES
  Version:        1.0
  Author:         Narasimha R Duggu/ Narduggu@in.ib.com
  Creation Date:  20210603
.EXAMPLE
 Set-ExecutionPolicy -ExecutionPolicy RemoteSigned
 Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
 powershell.exe -ExecutionPolicy ByPass -File .\AzResourceTags.ps1'
.EXAMPLE
.\AzResourceTags.ps1'
#>

$report=@()
$todaydate=(Get-Date).ToString('yyyy-MM-dd')
$AzSubs = (Get-AzSubscription).Name 

foreach($sub in $AzSubs){
    Select-AzSubscription -Subscription "$sub"
    $resources = Get-AzResource | Where-Object ResourceType -Match "Microsoft.RecoveryServices/vaults|Microsoft.StorageSync/storageSyncServices|Microsoft.Storage/storageAccounts"
    foreach($azres in $resources){
        $rType = $azres.ResourceType
        $name = $azres.name
        $rg = $azres.ResourceGroupName
        $loc = $azres.Location
        $opcoTag = $azres.Tags.opco
        $ProjectCode = $azres.Tags.projectcode
        $servicerequest = $azres.Tags.servicerequest
        $dateofservice = $azres.Tags.dateofservice

        $data = New-Object PSObject
        $data | Add-Member NoteProperty opco -Value $opcoTag
        $data | Add-Member NoteProperty ResourceName -Value $name
        $data | Add-Member NoteProperty ResourceGroupName -Value $rg
        $data | Add-Member NoteProperty ResourceType -Value $rType
        $data | Add-Member NoteProperty Location -Value $loc
        $data | Add-Member NoteProperty ProjectCode -Value $ProjectCode
        $data | Add-Member NoteProperty ServiceRequest -Value $servicerequest
        $data | Add-Member NoteProperty DateOfService -Value $dateofservice
        $report+=$data
    }
}
$report | Export-Csv -NoTypeInformation -Path "C:\AFS-ResourceTaggingDetails_$todaydate.csv"

Import-Csv "C:\AFS-ResourceTaggingDetails_$todaydate.csv" | Export-Excel -WorksheetName AzResourcesTagInfo "C:\AFS-ResourceTaggingDetails_$todaydate.xlsx" -DisplayPropertySet -TableName AzResourcesTagging


# Send email to members
$EmailSubject = "WPP AFS Resources Tagging Info -$todaydate"
$EmailBody = "Dear All <br> <br>" 
$EmailBody += "Please find attached AFS Resources Tagging information.<br> <br>" 
$EmailBody += "NOTE: To achive governance, please maintain key on tags are case-sensitive and all should be lower case. <br> <br>" 
$EmailBody += "Mandatory Tags for IBM Managed AFS resources are opco, projectcode, servicerequest and dateofservice. <br> <br>" 
$EmailBody += "Thank you <br>"
$EmailBody += "WPP IBM Azure Cloud Team <br> <br> <br>"
$EmailBody += "This is an automatic generated email, Please reachout to WPP IBM AFS Team (ibm-in-wppafsteam@wwpdl.vnet.ibm.com) for any concerns.<br>"
$params = @{
    To = 'ibm-in-wppafsteam@wwpdl.vnet.ibm.com'
    From = 'ibm-in-wppafsteam@wwpdl.vnet.ibm.com' 
    Subject = "$EmailSubject"
    Body = "$EmailBody"
    BodyAsHtml = $true
    SmtpServer = "d06av24.portsmouth.uk.ibm.com"
    Attachments = "C:\AFS-ResourceTaggingDetails_$todaydate.xlsx"
}
Send-MailMessage @params
