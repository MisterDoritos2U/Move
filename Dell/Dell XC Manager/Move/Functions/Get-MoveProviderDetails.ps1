function Get-MoveProviderDetails {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$MoveVmIP,
        [Parameter(Mandatory=$true)][hashtable]$Header,
        [Parameter(Mandatory=$true)][string]$ProviderUuid
    )
    Invoke-MoveApi -Uri "https://$MoveVmIP/move/v2/providers/$ProviderUuid" -Header $Header -Method GET
}
