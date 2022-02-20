function Set-jtAzCliSubscription {
<#
.SYNOPSIS
    Wrapper function for the Azure CLI account commands to easily switch between subscriptions using consolegridview GUI.
#>
    #Requires -Modules Microsoft.PowerShell.ConsoleGuiTools
    #Requires -Version 7
    # AzureCli (+ resource-graph extension) | az extension add --name resource-graph
    $subscriptions = (az graph query -q "resourcecontainers | where type == 'microsoft.resources/subscriptions' | project name, subscriptionId, tags" | ConvertFrom-Json).data
    if ($LASTEXITCODE) {
        $_; EXIT 1
    }
    $subscriptionId = (($subscriptions | ForEach-Object {
                $description = $_.tags.description ? $_.tags.description : 'N.A.'
                $environment = $_.tags.Environment ? $_.tags.Environment : '---'
                [PSCustomObject]@{
                    name           = $_.Name
                    description    = $description
                    environment    = $environment
                    subscriptionId = $_.subscriptionId
                }
            }) | Out-ConsoleGridView -OutputMode Single).subscriptionId
    $subscriptionId ? (az account set -s $subscriptionId) : "Exited. The current active subscription is:"
    az account show
}