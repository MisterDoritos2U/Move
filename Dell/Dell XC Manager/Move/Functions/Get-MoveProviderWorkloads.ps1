function Get-MoveProviderWorkloads {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$MoveVmIP,
        [Parameter(Mandatory=$true)][hashtable]$Header,
        [Parameter(Mandatory=$true)][string]$ProviderUuid
    )

    $body = [ordered]@{
        AfterOffset = 0
        BeforeOffset = 0
        Fields = @()
        Filter = @{}
    }

    $response = Invoke-MoveApi -Uri "https://$MoveVmIP/move/v2/providers/$ProviderUuid/workloads/list" -Header $Header -Method POST -Body $body
    if ($response.PSObject.Properties.Name -contains 'Entities') { return @($response.Entities) }
    if ($response.PSObject.Properties.Name -contains 'VMs') { return @($response.VMs) }
    if ($response.PSObject.Properties.Name -contains 'Workloads') { return @($response.Workloads) }
    return @($response)
}
