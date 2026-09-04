function Invoke-MoveWorkloadAction {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$MoveVmIP,
        [Parameter(Mandatory = $true)][hashtable]$Header,
        [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$PlanUuid,
        [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$WorkloadUuid,
        [Parameter(Mandatory = $true)][ValidateSet('cutover','test','retest','undotest','retry','discard','abort','suspend','resume','sync','complete')][string]$Action
    )
    if ($PSCmdlet.ShouldProcess("Workload $WorkloadUuid in plan $PlanUuid", "Perform '$Action'")) {
        $body = [ordered]@{ Spec = [ordered]@{ Action = $Action } }
        return Invoke-MoveApi -Uri "https://$MoveVmIP/move/v2/plans/$PlanUuid/workloads/$WorkloadUuid/action" -Header $Header -Method POST -Body $body
    }
}
