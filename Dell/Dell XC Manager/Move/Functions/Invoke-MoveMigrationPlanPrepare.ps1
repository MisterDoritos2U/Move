function Invoke-MoveMigrationPlanPrepare {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$MoveVmIP,
        [Parameter(Mandatory = $true)][hashtable]$Header,
        [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$PlanUuid,
        [Parameter()][hashtable]$Body
    )

    $target = "Move plan $PlanUuid on $MoveVmIP"
    if ($PSCmdlet.ShouldProcess($target, 'Prepare migration plan')) {
        if ($null -eq $Body) {
            return Invoke-MoveApi -Uri "https://$MoveVmIP/move/v2/plans/$PlanUuid/prepare" -Header $Header -Method POST
        }
        return Invoke-MoveApi -Uri "https://$MoveVmIP/move/v2/plans/$PlanUuid/prepare" -Header $Header -Method POST -Body $Body
    }
}
