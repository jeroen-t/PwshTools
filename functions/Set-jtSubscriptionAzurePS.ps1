function Set-jtSubscriptionAzurePS {
<#
.SYNOPSIS
    Wrapper function for the Az Accounts module commands to easily switch between subscriptions using consolegridview GUI.
#>
    #Requires -Modules Microsoft.PowerShell.ConsoleGuiTools, Az.Accounts
    #Requires -Version 7
    $subscriptions = Get-AzSubscription | Foreach-Object {
        $description = $environment = $null
        foreach ($tag in $_.Tags.GetEnumerator()) {
            if ($tag.Key -eq "description") {
                $description = $tag.Value
            } elseif ($tag.Key -eq "environment") {
                $environment = $tag.Value
            } else { continue }
        }
        [PSCustomObject]@{
            name           = $_.Name
            description    = ($description ? $description : 'N.A.')
            environment    = ($environment ? $environment : '---')
            subscriptionId = $_.subscriptionId
        }
    }
    $subscriptionId = ($subscriptions | Out-ConsoleGridView -OutputMode Single).subscriptionId
    Set-AzContext -SubscriptionId $subscriptionId
}
