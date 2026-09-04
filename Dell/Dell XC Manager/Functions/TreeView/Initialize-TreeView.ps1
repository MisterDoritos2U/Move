Function Initialize-TreeView {
    if ($null -eq $SyncHash -or $null -eq $SyncHash.TreeView) { return }

    $InventoryRoot = Join-Path $SyncHashData.RootDirectory 'Data\MoveVMs'
    $MoveInventory = @()
    if (Test-Path $InventoryRoot) {
        $MoveInventory = @(Import-MoveInventory -RootDirectory $InventoryRoot)
    }

    $SyncHash.TreeView.Items.Clear()

    $Root = New-Object System.Windows.Controls.TreeViewItem
    $Root.Header = 'Move VMs'
    $Root.Tag = 'MoveVmsRoot'
    $Root.Uid = 'MoveVmsRoot'
    $SyncHash.TreeView.Items.Add($Root) | Out-Null

    $EndpointGroups = @(
        $MoveInventory |
            Where-Object { $_.MoveIP } |
            Group-Object -Property MoveIP |
            Sort-Object Name
    )

    if ($EndpointGroups.Count -eq 0) {
        $EmptyNode = New-Object System.Windows.Controls.TreeViewItem
        $EmptyNode.Header = 'No Move VMs discovered'
        $EmptyNode.IsEnabled = $false
        $Root.Items.Add($EmptyNode) | Out-Null
    }
    else {
        foreach ($EndpointGroup in $EndpointGroups) {
            $EndpointIP = [string]$EndpointGroup.Name
            $EndpointNode = New-Object System.Windows.Controls.TreeViewItem
            $EndpointNode.Header = $EndpointIP
            $EndpointNode.Tag = "MoveEndpoint:$EndpointIP"
            $EndpointNode.Uid = $EndpointIP
            $EndpointNode.ToolTip = "Move appliance: $EndpointIP"
            $Root.Items.Add($EndpointNode) | Out-Null

            $PlanGroups = @(
                $EndpointGroup.Group |
                    Where-Object { $_.MovePlanId -and -not $_.IsDiscoveryRecord } |
                    Group-Object -Property MovePlanId |
                    Sort-Object Name
            )

            foreach ($PlanGroup in $PlanGroups) {
                $First = $PlanGroup.Group | Select-Object -First 1
                $PlanName = if ($First.MovePlanName) { [string]$First.MovePlanName } else { [string]$PlanGroup.Name }

                $PlanNode = New-Object System.Windows.Controls.TreeViewItem
                $PlanNode.Header = $PlanName
                $PlanNode.Tag = "MovePlan:$EndpointIP|$($PlanGroup.Name)"
                $PlanNode.Uid = "$EndpointIP|$($PlanGroup.Name)"
                $PlanNode.ToolTip = "Plan ID: $($PlanGroup.Name)"
                $EndpointNode.Items.Add($PlanNode) | Out-Null

                foreach ($MoveVm in @($PlanGroup.Group | Where-Object { $_.VmUuid -or $_.VmName } | Sort-Object VmName, VmUuid)) {
                    $VmName = if ($MoveVm.VmName) { [string]$MoveVm.VmName } else { [string]$MoveVm.VmUuid }
                    $VmNode = New-Object System.Windows.Controls.TreeViewItem
                    $VmNode.Header = $VmName
                    $VmNode.Tag = "MoveVm:$EndpointIP|$($PlanGroup.Name)|$($MoveVm.VmUuid)"
                    $VmNode.Uid = "$EndpointIP|$($PlanGroup.Name)|$($MoveVm.VmUuid)"
                    $VmNode.ToolTip = "VM UUID: $($MoveVm.VmUuid)"
                    $PlanNode.Items.Add($VmNode) | Out-Null
                }
            }

            if ($PlanGroups.Count -eq 0) {
                $NoPlans = New-Object System.Windows.Controls.TreeViewItem
                $NoPlans.Header = '[No migration plans found]'
                $NoPlans.IsEnabled = $false
                $EndpointNode.Items.Add($NoPlans) | Out-Null
            }
        }
    }

    $UniqueMoveVmCount = @($MoveInventory | Where-Object { $_.MoveIP } | Select-Object -ExpandProperty MoveIP -Unique).Count
    $UniquePlanCount = @($MoveInventory | Where-Object { $_.MovePlanId -and -not $_.IsDiscoveryRecord } | ForEach-Object { "$($_.MoveIP)|$($_.MovePlanId)" } | Select-Object -Unique).Count

    if ($null -ne $SyncHash.MoveVmsCount) { $SyncHash.MoveVmsCount.Text = [string]$UniqueMoveVmCount }
    if ($null -ne $SyncHash.MigrationPlansCount) { $SyncHash.MigrationPlansCount.Text = [string]$UniquePlanCount }
}
