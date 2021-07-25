<#
.SYNOPSIS
  This script will get Azure File Server details with Agent version from Tenants already logged in and sends email.

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
  Version:        1.0
  Author:         Narasimha R Duggu/ Narduggu@in.ib.com
  Creation Date:  20210315

.EXAMPLE
 Set-ExecutionPolicy -ExecutionPolicy RemoteSigned
 Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
 powershell.exe -ExecutionPolicy ByPass -File .\AzureFileServerAgentDetails.ps1'

.EXAMPLE
.\AzureFileServerAgentDetails.ps1'
#>

$Reporttime=(Get-Date).ToString('yyyy-MM-dd-hh-mm')
$todaydate=(Get-Date).ToString('yyyy-MM-dd')
$report=@()

$AzSubs = (Get-AzSubscription).Name
foreach($sub in $AzSubs){
    Select-AzSubscription -Subscription "$sub"

    $listss = Get-AzResource -ResourceType Microsoft.StorageSync/storageSyncServices | Select-Object -Property Name,ResourceGroupName,Tags
    $tag = $listss.Tags.opco | Select-Object -First 1
    foreach($line in $listss){
        echo $line
        $ss = $line.Name
        $rgName = $line.ResourceGroupName
        $regServer = Get-AzStorageSyncServer -ResourceGroupName $rgName -StorageSyncServiceName $ss

        if($regServer.Length -gt 1 -and $regServer.Length -ne 0){

            for ($fcounter=0; $fcounter -lt $regServer.Length; $fcounter++){
        
                $ServerName = $regServer.Get($fcounter).FriendlyName
                $rg = $regServer.Get($fcounter).ResourceGroupName
                $SyncService = $regServer.Get($fcounter).StorageSyncServiceName
                $AgentVersion = $regServer.Get($fcounter).AgentVersion
                $location = $regServer.Get($fcounter).ResourceLocation
                $ErrorCode = $regServer.Get($fcounter).ServerManagementErrorCode
                $HeartBeat = $regServer.Get($fcounter).LastHeartBeat
                $ProvisioningState = $regServer.Get($fcounter).ProvisioningState

                $data = New-Object PSObject
                $data | Add-Member NoteProperty opco -Value $tag
                $data | Add-Member NoteProperty ServerName -Value $ServerName
                $data | Add-Member NoteProperty Location -Value $location
                $data | Add-Member NoteProperty ResourceGroup -Value $rg
                $data | Add-Member NoteProperty StorageSyncServiceName -Value $SyncService
                $data | Add-Member NoteProperty AgentVersion -Value $AgentVersion
                $data | Add-Member NoteProperty ProvisioningState -Value $ProvisioningState
                $data | Add-Member NoteProperty LastHeartBeat -Value $HeartBeat
                $data | Add-Member NoteProperty ErrorCode -Value $ErrorCode
                $report+=$data
            }
        }
        elseif($regServer.Length -le 1 -and $regServer.Length -ne 0){

            $ServerName = $regServer.FriendlyName
            $rg = $regServer.ResourceGroupName
            $SyncService = $regServer.StorageSyncServiceName
            $AgentVersion = $regServer.AgentVersion
            $location = $regServer.ResourceLocation
            $ErrorCode = $regServer.ServerManagementErrorCode
            $HeartBeat = $regServer.LastHeartBeat
            $ProvisioningState = $regServer.ProvisioningState

            $data = New-Object PSObject
            $data | Add-Member NoteProperty opco -Value $tag
            $data | Add-Member NoteProperty ServerName -Value $ServerName
            $data | Add-Member NoteProperty Location -Value $location
            $data | Add-Member NoteProperty ResourceGroup -Value $rg
            $data | Add-Member NoteProperty StorageSyncServiceName -Value $SyncService
            $data | Add-Member NoteProperty AgentVersion -Value $AgentVersion
            $data | Add-Member NoteProperty ProvisioningState -Value $ProvisioningState
            $data | Add-Member NoteProperty LastHeartBeat -Value $HeartBeat
            $data | Add-Member NoteProperty ErrorCode -Value $ErrorCode
            $report+=$data
        }
    }
}
$report | Export-Csv -NoTypeInformation -Path C:/AFS_Inventory_AgentDetails.csv

Import-Csv C:/AFS_Inventory_AgentDetails.csv | Export-Excel -WorksheetName AzureFileServerAgentDetails "C:\AFS_Inventory_AgentDetails-$Reporttime.xlsx" -DisplayPropertySet -TableName FileServerAgentDetails


# Send email to members
$EmailSubject = "WPP AFS File Server Agent Details -$todaydate"
$EmailBody = "Dear All <br> <br>" 
$EmailBody += "Please find attached AFS File Server Agent Details; same has been uploaded into BOX location. Click <a href=https://ibm.ent.box.com/folder/129675222846>here</a> to open <br> <br>" 
$EmailBody += "Thank you <br>"
$EmailBody += "WPP IBM Azure Cloud Team <br> <br> <br>"
$EmailBody += "This is an automatic generated email, Please reachout to WPP IBM AFS Team (ibm-in-wppafsteam@wwpdl.vnet.ibm.com) for any concerns.<br>"
$params = @{
    To = 'ibm-in-wppafsteam@wwpdl.vnet.ibm.com','afs_rep.kzuz67jdh69rmznk@u.box.com'
    From = 'ibm-in-wppafsteam@wwpdl.vnet.ibm.com' 
    Subject = "$EmailSubject"
    Body = "$EmailBody"
    BodyAsHtml = $true
    SmtpServer = "d06av23.portsmouth.uk.ibm.com"
    Attachments = "C:\AFS_Inventory_AgentDetails-$Reporttime.xlsx"
}
Send-MailMessage @params

