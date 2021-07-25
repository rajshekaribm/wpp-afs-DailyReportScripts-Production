<#
.SYNOPSIS
  This script will check Azure Storage accounts and its File Share backup Status from Tenants already logged in and uploads file into BOX Location.

.PRE-CHECKS
  1. Install the Azure Powershell Module - https://docs.microsoft.com/en-us/powershell/azure/install-az-ps?view=azps-5.2.0
  2. Install ImportExcel Module
  3. Make sure to login Azure subscription before running script
  Example: Connect-AzAccount -Tenant 46dfce19-1520-4a06-b353-e97212f09cfa
  Connect-AzAccount -Tenant 2b755fa1-23d1-48f3-98fc-6fdc1dc48d69

.INPUTS
  NA

.OUTPUTS
  Generates output files in both CSV and HTML format at "C:\" location 

.NOTES
  Version:        1.0
  Author:         Narasimha R Duggu/ Narduggu@in.ib.com
  Creation Date:  20210615

.EXAMPLE
 Set-ExecutionPolicy -ExecutionPolicy RemoteSigned
 Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
 powershell.exe -ExecutionPolicy ByPass -File .\SAFileSharesBackupCheck.ps1'
.EXAMPLE
.\SAFileSharesBackupCheck.ps1'
#>

$todaydate=(Get-Date).ToString('yyyy-MM-dd')
$AzSubs = (Get-AzSubscription).Name #| ?{$_ -eq 'WT AUNZ'}
foreach($sub in $AzSubs){
    Select-AzSubscription -Subscription "$sub"
    $storageAccount = @()
    $resources = Get-AzResource | Where-Object ResourceType -Match "Microsoft.Storage/storageAccounts" 
    $totcountOfsa = $resources.count

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
        
        foreach($sa in $SAccounts){
            #Check FileShares count in Recovery Services Vault
            $Sharename = (Get-AzRecoveryServicesBackupItem -Container $sa -WorkloadType AzureFiles -VaultId $rvid).FriendlyName
            $NoOfFSVault = $Sharename.count

            #Check Number of File Shares in Storage Account.
            $FileShares = Get-AzRmStorageShare -ResourceGroupName $rg -StorageAccountName $sa.FriendlyName
            $storageAccount += $sa.FriendlyName
            
            $NoOfShares= ($FileShares.name).Count

            if ($NoOfFSVault -eq $NoOfShares)
                {
                    Write-Output "All File Shares in $($sa.FriendlyName) are configured in Vault for backup" #| Out-File -Append -FilePath "C:\AFS-FilesharesNOTinBackup-$todaydate.txt"
                }
            else
                {
                    Write-Output "All File Shares in $($opco),$($rg),$($sa.FriendlyName) are NOT configured for Backup" | Out-File -Append -FilePath "C:\AFS-SAFilesharesNOTinBackup-$todaydate.txt"
                }
        }
    }
    $countOfsa = $storageAccount.count
    if ($totcountOfsa -ne $countOfsa)
    {
        Write-Output "Few Storage Account in $($opco),$($sub) are missed to configure Backup" | Out-File -Append -FilePath "C:\AFS-SAFilesharesNOTinBackup-$todaydate.txt"
    }
    else
    {
        Write-output "All Storage Account in $($sub) are configured for backup"
    }
}
