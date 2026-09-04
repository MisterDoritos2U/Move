function Get-MoveProviders {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$MoveVmIP,
        [Parameter(Mandatory=$true)][hashtable]$Header,
        [switch]$RefreshInventory
    )

    $body = [ordered]@{
        EntityType = 'VM'
        RefreshInventory = [bool]$RefreshInventory
        UpdateInventoryToPlans = $true
    }

    $response = Invoke-MoveApi -Uri "https://$MoveVmIP/move/v2/providers/list" -Header $Header -Method POST -Body $body
    $entities = if ($response.PSObject.Properties.Name -contains 'Entities') { @($response.Entities) } else { @($response) }
    return @($entities)
}
