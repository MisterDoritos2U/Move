function Get-MoveMigrationPlan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$MoveVmIP,
        [Parameter(Mandatory = $true)][hashtable]$Header,
        [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$PlanUuid
    )
    Invoke-MoveApi -Uri "https://$MoveVmIP/move/v2/plans/$PlanUuid" -Header $Header -Method GET
}
