$ModuleRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$FunctionRoot = Join-Path $ModuleRoot 'Functions'

if (Test-Path $FunctionRoot) {
    Get-ChildItem -Path $FunctionRoot -Filter '*.ps1' -Recurse | Sort-Object FullName | ForEach-Object {
        . $_.FullName
    }
}

$RootScripts = Get-ChildItem -Path $ModuleRoot -Filter '*.ps1' -File | Sort-Object FullName
foreach ($RootScript in $RootScripts) {
    . $RootScript.FullName
}

Export-ModuleMember -Function @(
    'Invoke-MoveApi',
    'Get-MovePlanInventory',
    'Get-MoveVmInventory',
    'Import-MoveInventory',
    'Get-MoveProviders',
    'Get-MoveProviderDetails',
    'Get-MoveProviderWorkloads',
    'New-MoveMigrationPlan',
    'Get-MoveMigrationPlan',
    'Invoke-MoveMigrationPlanPrepare',
    'Invoke-MoveMigrationPlanReadiness',
    'Start-MoveMigrationPlan',
    'Get-MoveWorkloadDetails',
    'Invoke-MoveWorkloadAction',
    'Invoke-MoveWorkloadRefresh',
    'Show-MoveCreatePlanWindow',
    'Show-MoveWindow'
)
