function Get-MoveWorkloadDetails {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$MoveVmIP,
        [Parameter(Mandatory = $true)][hashtable]$Header,
        [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$PlanUuid,
        [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$WorkloadUuid
    )
    Invoke-MoveApi -Uri "https://$MoveVmIP/move/v2/plans/$PlanUuid/workloads/$WorkloadUuid" -Header $Header -Method GET
}
