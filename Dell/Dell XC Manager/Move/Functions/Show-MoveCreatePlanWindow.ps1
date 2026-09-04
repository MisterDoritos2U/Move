function Show-MoveCreatePlanWindow {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][System.Windows.Window]$Owner,
        [Parameter(Mandatory=$true)][string]$MoveVmIP,
        [Parameter(Mandatory=$true)][hashtable]$Header,
        [scriptblock]$OnCreated
    )

    # This function is dot-sourced from the Functions directory. Use the
    # function script's own root instead of relying on a module-scope variable
    # that may not be visible in every invocation context.
    $xamlPath = Join-Path $PSScriptRoot '..\CreateMigrationPlanWindow.xaml'
    $xamlPath = [System.IO.Path]::GetFullPath($xamlPath)
    if (-not (Test-Path $xamlPath)) { throw "Create migration plan XAML not found: $xamlPath" }

    $xaml = Get-Content -LiteralPath $xamlPath -Raw
    $reader = New-Object System.Xml.XmlNodeReader ([xml]$xaml)
    $window = [System.Windows.Markup.XamlReader]::Load($reader)
    $window.Owner = $Owner

    $nameBox = $window.FindName('CreatePlanNameTextBox')
    $sourceCombo = $window.FindName('CreatePlanSourceCombo')
    $targetCombo = $window.FindName('CreatePlanTargetCombo')
    $vmList = $window.FindName('CreatePlanVmListBox')
    $networkList = $window.FindName('CreatePlanNetworkListBox')
    $vmCount = $window.FindName('CreatePlanVmCountText')
    $status = $window.FindName('CreatePlanStatusText')
    $create = $window.FindName('CreatePlanCreateButton')
    $cancel = $window.FindName('CreatePlanCancelButton')
    $close = $window.FindName('CreatePlanCloseButton')
    $endpointText = $window.FindName('CreatePlanMoveEndpointText')

    $endpointText.Text = "Move appliance: $MoveVmIP"
    $status.Text = 'Loading Move providers...'

    function Get-NestedValue {
        param([object]$Object,[string[]]$Names)
        if ($null -eq $Object) { return $null }
        foreach ($name in $Names) {
            $prop = $Object.PSObject.Properties | Where-Object { $_.Name -ieq $name } | Select-Object -First 1
            if ($prop) { return $prop.Value }
        }
        foreach ($prop in $Object.PSObject.Properties) {
            $v = $prop.Value
            if ($null -eq $v -or $v -is [string]) { continue }
            if ($v -is [System.Collections.IEnumerable] -and -not ($v -is [System.Collections.IDictionary])) {
                foreach ($child in @($v)) {
                    $r = Get-NestedValue -Object $child -Names $Names
                    if ($null -ne $r) { return $r }
                }
            } elseif ($v -is [pscustomobject] -or $v -is [System.Management.Automation.PSObject]) {
                $r = Get-NestedValue -Object $v -Names $Names
                if ($null -ne $r) { return $r }
            }
        }
        return $null
    }

    function Get-ProviderNetworks {
        param([object]$ProviderDetails)
        $networks = @()
        $clusters = Get-NestedValue -Object $ProviderDetails -Names @('Clusters')
        foreach ($cluster in @($clusters)) {
            foreach ($net in @($cluster.Networks)) {
                $uuid = Get-NestedValue -Object $net -Names @('UUID','Uuid','Id','ID')
                $n = Get-NestedValue -Object $net -Names @('Name','name')
                if ($uuid -or $n) {
                    $networks += [pscustomobject]@{ Name=[string]$n; UUID=[string]$uuid }
                }
            }
        }
        if ($networks.Count -eq 0) {
            # Fallback for provider types that expose networks elsewhere.
            $candidate = Get-NestedValue -Object $ProviderDetails -Names @('Networks')
            foreach ($net in @($candidate)) {
                $uuid = Get-NestedValue -Object $net -Names @('UUID','Uuid','Id','ID')
                $n = Get-NestedValue -Object $net -Names @('Name','name')
                if ($uuid -or $n) { $networks += [pscustomobject]@{ Name=[string]$n; UUID=[string]$uuid } }
            }
        }
        $networks | Sort-Object Name -Unique
    }

    function Get-WorkloadRecords {
        param([object[]]$Raw)
        $out=@()
        function Invoke-WorkloadTraversal($obj) {
            if ($null -eq $obj -or $obj -is [string]) { return }
            if ($obj -is [System.Collections.IEnumerable] -and -not ($obj -is [System.Collections.IDictionary])) { foreach($x in @($obj)){ Invoke-WorkloadTraversal $x }; return }
            $uuid = Get-NestedValue -Object $obj -Names @('UUID','Uuid','vm_uuid','VmUuid')
            $name = Get-NestedValue -Object $obj -Names @('Name','name','vm_name','VmName','display_name','displayName')
            if ($uuid -and $name) {
                $id = Get-NestedValue -Object $obj -Names @('VMID','Vmid','vm_id','Id','ID')
                $network = Get-NestedValue -Object $obj -Names @('NetworkName','network_name','Network','network')
                $out += [pscustomobject]@{ UUID=[string]$uuid; VMID=[string]$id; Name=[string]$name; NetworkName=[string]$network; Raw=$obj }
                return
            }
            foreach($p in $obj.PSObject.Properties){
                if($p.Value -is [string]){continue}
                Invoke-WorkloadTraversal $p.Value
            }
        }
        foreach($r in $Raw){ Invoke-WorkloadTraversal $r }
        $out | Sort-Object UUID -Unique
    }

    function Get-TargetAttrs {
        param([object]$ProviderDetails)
        $clusters = Get-NestedValue -Object $ProviderDetails -Names @('Clusters')
        $cluster = @($clusters) | Select-Object -First 1
        if ($null -eq $cluster) { return $null }
        $clusterUuid = Get-NestedValue -Object $cluster -Names @('UUID','Uuid','Id','ID')
        $container = @($cluster.Containers) | Select-Object -First 1
        $containerUuid = if ($container) { Get-NestedValue -Object $container -Names @('UUID','Uuid','Id','ID') } else { $null }
        if (-not $clusterUuid -or -not $containerUuid) { return $null }
        [pscustomobject]@{ ClusterUUID=[string]$clusterUuid; ContainerUUID=[string]$containerUuid }
    }

    $providers = @()
    try { $providers = @(Get-MoveProviders -MoveVmIP $MoveVmIP -Header $Header) }
    catch { $status.Text = "Unable to load providers: $($_.Exception.Message)"; $create.IsEnabled=$false; $window.ShowDialog()|Out-Null; return }

    $sourceProviders = @($providers | Where-Object { $_.Type -notmatch 'AOS_AHV|AOS|AHV' })
    if ($sourceProviders.Count -eq 0) { $sourceProviders = @($providers) }
    $targetProviders = @($providers | Where-Object { $_.Type -match 'AOS_AHV|AOS|AHV' })

    foreach($p in $sourceProviders){
        $display = Get-NestedValue $p @('Name','name')
        $uuid = Get-NestedValue $p @('UUID','Uuid','id')
        $type = Get-NestedValue $p @('Type','type')
        if($uuid){ $sourceCombo.Items.Add([pscustomobject]@{Display="$display  [$type]"; UUID=[string]$uuid; Type=[string]$type})|Out-Null }
    }
    foreach($p in $targetProviders){
        $display = Get-NestedValue $p @('Name','name')
        $uuid = Get-NestedValue $p @('UUID','Uuid','id')
        $type = Get-NestedValue $p @('Type','type')
        if($uuid){ $targetCombo.Items.Add([pscustomobject]@{Display="$display  [$type]"; UUID=[string]$uuid; Type=[string]$type})|Out-Null }
    }
    $sourceCombo.DisplayMemberPath='Display'; $targetCombo.DisplayMemberPath='Display'

    $state = [hashtable]::Synchronized(@{
        SourceDetails=$null; TargetDetails=$null; Workloads=@(); SourceNetworks=@(); TargetNetworks=@(); NetworkRows=@()
    })

    function Refresh-CreatePlanState {
        if ($sourceCombo.SelectedItem -and $targetCombo.SelectedItem) {
            try {
                $status.Text='Loading source inventory and target networks...'
                $source = $sourceCombo.SelectedItem
                $target = $targetCombo.SelectedItem
                $state.SourceDetails = Get-MoveProviderDetails -MoveVmIP $MoveVmIP -Header $Header -ProviderUuid $source.UUID
                $state.TargetDetails = Get-MoveProviderDetails -MoveVmIP $MoveVmIP -Header $Header -ProviderUuid $target.UUID
                $raw = @(Get-MoveProviderWorkloads -MoveVmIP $MoveVmIP -Header $Header -ProviderUuid $source.UUID)
                $state.Workloads = @(Get-WorkloadRecords -Raw $raw)
                $state.SourceNetworks = @(Get-ProviderNetworks -ProviderDetails $state.SourceDetails)
                $state.TargetNetworks = @(Get-ProviderNetworks -ProviderDetails $state.TargetDetails)
                $vmList.Items.Clear()
                foreach($vm in $state.Workloads){
                    $item=New-Object System.Windows.Controls.ListBoxItem
                    $item.Tag=$vm
                    $item.Padding=[System.Windows.Thickness]::new(6)
                    $item.Content="$($vm.Name)  •  $($vm.UUID)"
                    $vmList.Items.Add($item)|Out-Null
                }
                $vmCount.Text="$($state.Workloads.Count) discovered"
                $networkList.Items.Clear(); $state.NetworkRows=@()
                foreach($sn in $state.SourceNetworks){
                    $row=New-Object System.Windows.Controls.Grid
                    $row.Margin=[System.Windows.Thickness]::new(0,0,0,6)
                    $row.Tag=$sn
                    $row.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition))
                    $row.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition))
                    $tb=New-Object System.Windows.Controls.TextBlock; $tb.Text=$sn.Name; $tb.VerticalAlignment='Center'; [System.Windows.Controls.Grid]::SetColumn($tb,0)
                    $cb=New-Object System.Windows.Controls.ComboBox; $cb.DisplayMemberPath='Name'; $cb.ItemsSource=$state.TargetNetworks; $cb.MinWidth=220; [System.Windows.Controls.Grid]::SetColumn($cb,1)
                    $match=$state.TargetNetworks|Where-Object {$_.Name -eq $sn.Name}|Select-Object -First 1
                    if($match){$cb.SelectedItem=$match}
                    $row.Children.Add($tb)|Out-Null; $row.Children.Add($cb)|Out-Null
                    $networkList.Items.Add($row)|Out-Null
                    $state.NetworkRows += [pscustomobject]@{Source=$sn; Combo=$cb}
                }
                if($state.SourceNetworks.Count -eq 0){ $status.Text='No provider networks were returned. The plan cannot be created until a network mapping is available.' }
                else { $status.Text='Select the VMs and verify network mappings.' }
            } catch { $status.Text="Unable to load provider inventory: $($_.Exception.Message)" }
        }
    }

    $sourceCombo.Add_SelectionChanged({ Refresh-CreatePlanState })
    $targetCombo.Add_SelectionChanged({ Refresh-CreatePlanState })
    $vmList.Add_SelectionChanged({ $vmCount.Text="$($vmList.SelectedItems.Count) selected of $($state.Workloads.Count)" })

    $doClose = { $window.Close() }
    $cancel.Add_Click($doClose); $close.Add_Click($doClose)

    $create.Add_Click({
        try {
            $source=$sourceCombo.SelectedItem; $target=$targetCombo.SelectedItem
            if(-not $source -or -not $target){ throw 'Select both a source provider and a target AHV provider.' }
            if([string]::IsNullOrWhiteSpace($nameBox.Text)){ throw 'Enter a migration plan name.' }
            $selected=@($vmList.SelectedItems | ForEach-Object {$_.Tag})
            if($selected.Count -eq 0){ throw 'Select at least one source VM.' }
            $mappings=@()
            foreach($r in $state.NetworkRows){
                if(-not $r.Combo.SelectedItem){ throw "Select a target network for '$($r.Source.Name)'." }
                $mappings += [ordered]@{ SourceNetworkID=[string]$r.Source.Name; TargetNetworkID=[string]$r.Combo.SelectedItem.UUID; TargetSecurityGroupIDs=$null; TestNetworkID=[string]$r.Combo.SelectedItem.UUID; TestSecurityGroupIDs=$null }
            }
            $attrs=Get-TargetAttrs -ProviderDetails $state.TargetDetails
            if(-not $attrs){ throw 'The selected target provider did not return an AHV cluster and container UUID.' }
            $status.Text='Creating migration plan in Move...'; $create.IsEnabled=$false
            $result=New-MoveMigrationPlan -MoveVmIP $MoveVmIP -Header $Header -PlanName ([string]$nameBox.Text).Trim() -SourceProviderUuid $source.UUID -TargetProviderUuid $target.UUID -TargetClusterUuid $attrs.ClusterUUID -TargetContainerUuid $attrs.ContainerUUID -NetworkMappings $mappings -VmEntries $selected -Confirm:$false
            $newId=Get-NestedValue $result @('UUID','Uuid')
            $status.Text="Migration plan created successfully$(if($newId){": $newId"})."
            if($OnCreated){ & $OnCreated $result }
            [System.Windows.MessageBox]::Show('Migration plan created successfully.','Move','OK','Information')|Out-Null
            $window.DialogResult=$true
            $window.Close()
        } catch {
            $create.IsEnabled=$true
            $status.Text="Create failed: $($_.Exception.Message)"
            [System.Windows.MessageBox]::Show($status.Text,'Create Migration Plan','OK','Error')|Out-Null
        }
    })

    if($sourceCombo.Items.Count -gt 0){$sourceCombo.SelectedIndex=0}
    if($targetCombo.Items.Count -gt 0){$targetCombo.SelectedIndex=0}
    $window.ShowDialog() | Out-Null
}
