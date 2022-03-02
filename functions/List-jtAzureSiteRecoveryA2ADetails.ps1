Param (
    [string]$recoveryvaultname,
    [string]$recoveryvaultrg
)

Get-AzRecoveryServicesVault -Name $recoveryvaultname -ResourceGroupName $recoveryvaultrg | Tee-Object -Variable vault

# Set the context..
Set-AzRecoveryServicesAsrVaultContext -Vault $vault

# fabric details..
Get-AzRecoveryServicesAsrFabric | Tee-Object -Variable fabric

$fabric | ForEach-Object {
    "`n--> Details for Fabric {0} in region {1}." -f $_.Name, $_.FriendlyName
    $containers = Get-AzRecoveryServicesAsrProtectionContainer -Fabric $_
    "`nThere are {0} containers in this fabric." -f $containers.Count
    
    if ($containers.count -gt 0) {
        $containers | ForEach-Object {
            $items = Get-AzRecoveryServicesAsrReplicationProtectedItem -ProtectionContainer $_
            if ($items.RecoveryAzureVMName.Length -gt 0) {
                "`ncontainer {0} protects the following VMs:" -f $_.Name
                #$items.RecoveryAzureVMName
                $params = @('RecoveryAzureVMName', 'PrimaryProtectionContainerFriendlyName', 'RecoveryProtectionContainerFriendlyName', 'ActiveLocation', 'PolicyFriendlyName', 'ReplicationHealth')
                $items | Select-Object $params | Format-Table
            } else {
                "`ncontainer {0} protects no VMs" -f $_.Name
            }
        }
        # Get-AzRecoveryServicesAsrProtectionContainerMapping -ProtectionContainer $containers[0]
    }
}

$policy = Get-AzRecoveryServicesAsrPolicy
"`n{0} policies found" -f $policy.Count
$policy | ForEach-Object {
    "`nPolicy {0} has the following settings:" -f $_.Name
    $_.ReplicationProviderSettings
}