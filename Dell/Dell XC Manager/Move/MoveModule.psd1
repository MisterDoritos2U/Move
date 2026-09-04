@{
    RootModule = 'MoveModule.psm1'
    ModuleVersion = '1.0.0'
    GUID = 'ad0abca9-9d11-4d7a-9be9-f6a8666d4d4e'
    Author = 'Dell XC Manager'
    Description = 'Move VM inventory helpers for Nutanix Move plans and virtual machines only.'
    PowerShellVersion = '7.0'
    FunctionsToExport = @(
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
}
