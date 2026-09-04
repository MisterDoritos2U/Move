function Invoke-MoveWorkloadRefresh {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$MoveVmIP,
        [Parameter(Mandatory = $true)][hashtable]$Header,
        [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$PlanUuid,
        [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$WorkloadUuid
    )
    if ($PSCmdlet.ShouldProcess("Workload $WorkloadUuid in plan $PlanUuid", 'Refresh workload')) {
        return Invoke-MoveApi -Uri "https://$MoveVmIP/move/v2/plans/$PlanUuid/workloads/$WorkloadUuid/refresh" -Header $Header -Method POST
    }
}
