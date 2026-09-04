function Start-MoveMigrationPlan {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$MoveVmIP,
        [Parameter(Mandatory = $true)][hashtable]$Header,
        [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$PlanUuid
    )
    if ($PSCmdlet.ShouldProcess("Move plan $PlanUuid on $MoveVmIP", 'Start migration plan')) {
        return Invoke-MoveApi -Uri "https://$MoveVmIP/move/v2/plans/$PlanUuid/start" -Header $Header -Method POST
    }
}
