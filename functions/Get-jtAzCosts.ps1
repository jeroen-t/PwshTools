$payload = '{
    "type": "Usage",
    "timeframe": "TheLastMonth",
    "dataset": {
        "granularity": "None",
        "aggregation": {
            "totalCost": {
                "name": "PreTaxCost",
                "function": "Sum"
            }
        },
        "filter": {
            "dimensions": {
                "name": "ResourceType",
                "operator": "In",
                "values": [
                    "Microsoft.Compute/virtualMachines",
                    "Microsoft.Compute/disks"
                ]
            }
        },
        "grouping": [
            {
                "type": "Dimension",
                "name": "ResourceId"
            }
        ]
    }
}'

$apiArguments = @{
    Path = "/subscriptions/{0}/providers/Microsoft.CostManagement/query?api-version={1}" -f (get-azcontext).Subscription.Id, '2021-10-01'
    Method = 'POST'
    Payload = $payload
}
$output = Invoke-AzRestMethod @apiArguments

$output = ($output.Content | ConvertFrom-Json).properties.rows | ForEach-Object {
    $preTaxCost, $resourceId, $currency = $_
    $resourceGroup, $providerPre, $providerType, $resource = ($resourceId -split '/')[4,6,7,8]
    [PSCustomObject]@{
        Resource = $resource
        ResourceType = '{0}/{1}' -f $providerPre, $providerType
        ResourceGroup = $resourceGroup
        PreTaxCost = $preTaxCost
        Currency = $currency
        # ResourceId = $resourceId
    }
}

$output | ft
