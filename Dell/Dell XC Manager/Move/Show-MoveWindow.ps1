Function Show-MoveWindow {
    [CmdletBinding()]
    param()

    if ($null -eq $SyncHashData) {
        throw 'SyncHashData is not initialized. Start-Setup has not run.'
    }

    if ($null -eq $SyncHashData.ScriptPath) {
        throw 'SyncHashData.ScriptPath is null. The application root path is not available.'
    }

    $AssemblyRoot = Join-Path $SyncHashData.ScriptPath 'Resources\Assemblies'
    if (Test-Path $AssemblyRoot) {
        foreach ($AssemblyFile in (Get-ChildItem -Path $AssemblyRoot -Filter '*.dll' -File)) {
            $AssemblyName = [System.IO.Path]::GetFileNameWithoutExtension($AssemblyFile.FullName)
            $IsLoaded = [System.AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.GetName().Name -eq $AssemblyName }
            if ($null -eq $IsLoaded) {
                try {
                    [System.Reflection.Assembly]::LoadFrom($AssemblyFile.FullName) | Out-Null
                }
                catch {
                    Write-Verbose "Unable to load assembly $($AssemblyFile.FullName): $($_.Exception.Message)"
                }
            }
        }
    }

    $ModulePath = Join-Path $SyncHashData.ScriptPath 'Move\MoveModule.psm1'
    if (-not (Test-Path $ModulePath)) {
        throw "Move module not found: $ModulePath"
    }

    $WindowPath = Join-Path $SyncHashData.ScriptPath 'Move\MoveWindow.xaml'
    if (-not (Test-Path $WindowPath)) {
        throw "Move window not found: $WindowPath"
    }

    [xml]$Xaml = Get-Content -LiteralPath $WindowPath
    $Reader = New-Object System.Xml.XmlNodeReader $Xaml
    $Window = [System.Windows.Markup.XamlReader]::Load($Reader)
    if ($null -eq $Window) {
        throw 'The Move XAML window failed to load.'
    }

    $RequiredControls = @(
        'MovePrismCentralCombo',
        'MovePlanListBox',
        'MoveVmJsonText',
        'MoveHeaderText',
        'MovePlanStatusText',
        'MoveSourceClusterText',
        'MoveDestinationClusterText',
        'MoveVmNameText',
        'MoveVmUuidText',
        'MoveVmStateText',
        'CreateMovePlanButton'
    )

    foreach ($ControlName in $RequiredControls) {
        $Control = $Window.FindName($ControlName)
        if ($null -eq $Control) {
            throw "Required Move window control not found: $ControlName"
        }
    }

    $Xaml.SelectNodes("//*[@*[contains(translate(name(.),'n','N'),'Name')]]") | ForEach-Object {
        $Name = $_.Name
        $Value = $Window.FindName($Name)
        if ($null -ne $Value) {
            Set-Variable -Name $Name -Value $Value -Scope Script -Force
        }
    }

    $InventoryRoot = Join-Path $SyncHashData.RootDirectory 'Data\MoveVMs'
    if (-not (Test-Path $InventoryRoot)) {
        New-Item -ItemType Directory -Force -Path $InventoryRoot | Out-Null
    }

    # Always load the cached inventory first so the Move window has data even
    # when the appliance is temporarily unavailable.
    $CachedInventory = @(Import-MoveInventory -RootDirectory $InventoryRoot)
    $MoveInventory = @($CachedInventory)

    $MoveIPs = @()
    if ($null -ne $SyncHash -and $null -ne $SyncHash.ListBoxPrismCentral) {
        $MoveIPs = @($SyncHash.ListBoxPrismCentral.Items | ForEach-Object { [string]$_ } | Where-Object { $_ })
    }

    if ($MoveIPs.Count -eq 0) {
        $MoveIPs = @(
            $CachedInventory |
                Where-Object { $_.MoveIP } |
                Select-Object -ExpandProperty MoveIP -Unique
        )
    }

    # Request Move credentials once. Saved credentials are used automatically
    # by Set-NtnxApiHeader, so opening this window does not prompt when they exist.
    $MoveHeader = $null
    if ($MoveIPs.Count -gt 0) {
        $MoveVmIP = [string]$MoveIPs[0]
        $script:MoveLoginEndpoint = "https://$MoveVmIP/move/v2/users/login"
        $MoveHeader = Set-NtnxApiHeader -EndPoint 'Move'
    }

    # Refresh each configured endpoint. A failed refresh does not destroy the
    # previously cached endpoint data.
    if ($MoveHeader) {
        foreach ($MoveIP in $MoveIPs | Select-Object -Unique) {
            if (-not $MoveIP) { continue }
            try {
                $null = Get-MoveVmInventory -MoveVmIP $MoveIP -Header $MoveHeader -RootDirectory $InventoryRoot
            }
            catch {
                Write-Verbose "Unable to refresh Move inventory for $MoveIP. Cached data will be used: $($_.Exception.Message)"
            }
        }
    }

    # Re-read all endpoint cache files after refresh so the in-memory model is
    # the authoritative combined cache.
    $MoveInventory = @(Import-MoveInventory -RootDirectory $InventoryRoot)
    if ($null -ne $SyncHashData) {
        $SyncHashData.MoveVmInventory = $MoveInventory
    }

    $MovePrismCentralCombo = $Window.FindName('MovePrismCentralCombo')
    $MovePlanListBox = $Window.FindName('MovePlanListBox')
    $MoveSearchBox = $Window.FindName('MoveSearchBox')
    $MoveVmJsonText = $Window.FindName('MoveVmJsonText')
    $MoveHeaderText = $Window.FindName('MoveHeaderText')
    $MovePlanStatusText = $Window.FindName('MovePlanStatusText')
    $MoveSourceClusterText = $Window.FindName('MoveSourceClusterText')
    $MoveDestinationClusterText = $Window.FindName('MoveDestinationClusterText')
    $MoveVmNameText = $Window.FindName('MoveVmNameText')
    $MoveVmUuidText = $Window.FindName('MoveVmUuidText')
    $MoveVmStateText = $Window.FindName('MoveVmStateText')
    $CreateMovePlanButton = $Window.FindName('CreateMovePlanButton')

    # The ComboBox is ONLY for selecting a Move appliance. The ListBox below it
    # is populated dynamically with migration plans belonging to that appliance.
    if ($null -ne $MovePrismCentralCombo) {
        $MovePrismCentralCombo.Items.Clear()
    }

    $UniqueMoveEndpoints = @(
        $MoveInventory |
            Where-Object { $_.MoveIP } |
            Select-Object -ExpandProperty MoveIP -Unique |
            Sort-Object
    )

    foreach ($MoveEndpoint in $UniqueMoveEndpoints) {
        if ($null -ne $MovePrismCentralCombo) {
            $MovePrismCentralCombo.Items.Add([string]$MoveEndpoint) | Out-Null
        }
    }

    if ($null -ne $MovePlanListBox) {
        $MovePlanListBox.Items.Clear()
    }

    # Keep the selected Move appliance in one place so the ComboBox and search
    # handler always operate against the same endpoint.
    $script:SelectedMoveEndpoint = $null
    $script:MovePlanEntries = @()

    function Clear-MovePlanDetails {
        if ($null -ne $MoveHeaderText) { $MoveHeaderText.Text = 'Select a migration plan' }
        if ($null -ne $MovePlanStatusText) { $MovePlanStatusText.Text = '' }
        if ($null -ne $MoveSourceClusterText) { $MoveSourceClusterText.Text = '' }
        if ($null -ne $MoveDestinationClusterText) { $MoveDestinationClusterText.Text = '' }
        if ($null -ne $MoveVmNameText) { $MoveVmNameText.Text = '' }
        if ($null -ne $MoveVmUuidText) { $MoveVmUuidText.Text = '' }
        if ($null -ne $MoveVmStateText) { $MoveVmStateText.Text = '' }
        if ($null -ne $MoveVmJsonText) { $MoveVmJsonText.Text = '' }
    }

    function Update-MovePlanList {
        param([string]$EndpointIP, [string]$SearchText)

        if ($null -eq $MovePlanListBox) { return }

        $MovePlanListBox.Items.Clear()

        $EndpointEntries = @(
            $MoveInventory |
                Where-Object {
                    [string]$_.MoveIP -eq [string]$EndpointIP -and
                    -not $_.IsDiscoveryRecord -and
                    $_.MovePlanId
                }
        )

        $PlanGroups = @(
            $EndpointEntries |
                Group-Object -Property MovePlanId |
                Sort-Object @{ Expression = {
                    $first = $_.Group | Select-Object -First 1
                    if ($first.MovePlanName) { [string]$first.MovePlanName } else { [string]$_.Name }
                } }
        )

        $script:MovePlanEntries = @($PlanGroups)

        $filter = [string]$SearchText
        foreach ($PlanGroup in $PlanGroups) {
            $First = $PlanGroup.Group | Select-Object -First 1
            $PlanName = if ($First.MovePlanName) { [string]$First.MovePlanName } else { [string]$PlanGroup.Name }
            $PlanStatus = [string]$First.MovePlanStatus
            $VmCount = @($PlanGroup.Group | Where-Object { $_.VmUuid -or $_.VmName }).Count

            if ($filter -and
                $PlanName.IndexOf($filter, [StringComparison]::OrdinalIgnoreCase) -lt 0 -and
                ([string]$PlanGroup.Name).IndexOf($filter, [StringComparison]::OrdinalIgnoreCase) -lt 0) {
                continue
            }

            $item = New-Object System.Windows.Controls.ListBoxItem
            $item.Tag = "MovePlan:$EndpointIP|$($PlanGroup.Name)"
            $item.Padding = [System.Windows.Thickness]::new(8,6,8,6)
            $item.ToolTip = "Plan ID: $($PlanGroup.Name) | VMs: $VmCount"

            $panel = New-Object System.Windows.Controls.StackPanel
            $panel.Orientation = 'Vertical'

            $nameText = New-Object System.Windows.Controls.TextBlock
            $nameText.Text = $PlanName
            $nameText.FontWeight = 'SemiBold'

            $detailText = New-Object System.Windows.Controls.TextBlock
            $detailText.Text = if ($PlanStatus) { "$PlanStatus  •  $VmCount VM(s)" } else { "$VmCount VM(s)" }
            $detailText.Opacity = 0.70
            $detailText.FontSize = 11
            $detailText.Margin = [System.Windows.Thickness]::new(0,2,0,0)

            $panel.Children.Add($nameText) | Out-Null
            $panel.Children.Add($detailText) | Out-Null
            $item.Content = $panel

            $MovePlanListBox.Items.Add($item) | Out-Null
        }

        if ($MovePlanListBox.Items.Count -eq 0) {
            $empty = New-Object System.Windows.Controls.ListBoxItem
            $empty.Content = if ($filter) { 'No migration plans match the search.' } else { 'No migration plans available.' }
            $empty.IsEnabled = $false
            $MovePlanListBox.Items.Add($empty) | Out-Null
            Clear-MovePlanDetails
        }
        elseif ($MovePlanListBox.SelectedIndex -lt 0) {
            $MovePlanListBox.SelectedIndex = 0
        }
    }

    function Show-MovePlanDetails {
        param([object]$SelectedItem)

        if ($null -eq $SelectedItem) { return }
        $Tag = [string]$SelectedItem.Tag
        if ($Tag -notlike 'MovePlan:*') { return }

        $parts = $Tag.Substring(9) -split '\|', 2
        if ($parts.Count -lt 2) { return }

        $EndpointIP = $parts[0]
        $PlanId = $parts[1]
        $PlanEntries = @(
            $MoveInventory |
                Where-Object {
                    [string]$_.MoveIP -eq $EndpointIP -and
                    [string]$_.MovePlanId -eq $PlanId
                }
        )
        $SelectedData = $PlanEntries | Select-Object -First 1
        if ($null -eq $SelectedData) { return }

        if ($null -ne $MoveHeaderText) { $MoveHeaderText.Text = [string]$SelectedData.MovePlanName }
        if ($null -ne $MovePlanStatusText) { $MovePlanStatusText.Text = [string]$SelectedData.MovePlanStatus }
        if ($null -ne $MoveSourceClusterText) { $MoveSourceClusterText.Text = [string]$SelectedData.MovePlanSourceCluster }
        if ($null -ne $MoveDestinationClusterText) { $MoveDestinationClusterText.Text = [string]$SelectedData.MovePlanDestinationCluster }
        if ($null -ne $MoveVmNameText) { $MoveVmNameText.Text = [string]$SelectedData.VmName }
        if ($null -ne $MoveVmUuidText) { $MoveVmUuidText.Text = [string]$SelectedData.VmUuid }
        if ($null -ne $MoveVmStateText) { $MoveVmStateText.Text = [string]$SelectedData.VmState }

        if ($null -ne $MoveVmJsonText) {
            $MoveVmJsonText.Text = [string]$SelectedData.VmConfigJson
        }
    }

    if ($null -ne $MovePrismCentralCombo) {
        $MovePrismCentralCombo.Add_SelectionChanged({
            param($sender, $e)

            if ($null -eq $sender.SelectedItem) { return }

            $script:SelectedMoveEndpoint = [string]$sender.SelectedItem
            if ($null -ne $CreateMovePlanButton) { $CreateMovePlanButton.IsEnabled = -not [string]::IsNullOrWhiteSpace($script:SelectedMoveEndpoint) }
            if ($null -ne $MoveSearchBox) {
                $MoveSearchBox.Text = ''
            }

            Update-MovePlanList -EndpointIP $script:SelectedMoveEndpoint -SearchText ''
        })
    }

    if ($null -ne $CreateMovePlanButton) {
        $CreateMovePlanButton.Add_Click({
            param($sender, $e)
            if ([string]::IsNullOrWhiteSpace($script:SelectedMoveEndpoint)) { return }
            try {
                $script:MovePlanCreated = $false
                Show-MoveCreatePlanWindow -Owner $Window -MoveVmIP $script:SelectedMoveEndpoint -Header $MoveHeader -OnCreated {
                    param($CreatedPlan)
                    $script:MovePlanCreated = $true
                }
                if ($script:MovePlanCreated) {
                    try {
                        $null = Get-MoveVmInventory -MoveVmIP $script:SelectedMoveEndpoint -Header $MoveHeader -RootDirectory $InventoryRoot
                        $MoveInventory = @(Import-MoveInventory -RootDirectory $InventoryRoot)
                        if ($null -ne $SyncHashData) { $SyncHashData.MoveVmInventory = $MoveInventory }
                        Update-MovePlanList -EndpointIP $script:SelectedMoveEndpoint -SearchText ([string]$MoveSearchBox.Text)
                    } catch {
                        Write-Verbose "Unable to refresh Move inventory after plan creation: $($_.Exception.Message)"
                    }
                }
            } catch {
                [System.Windows.MessageBox]::Show("Unable to open Create Migration Plan: $($_.Exception.Message)",'Move','OK','Error') | Out-Null
            }
        })
    }

    if ($null -ne $MovePlanListBox) {
        $MovePlanListBox.Add_SelectionChanged({
            param($sender, $e)
            Show-MovePlanDetails -SelectedItem $sender.SelectedItem
        })
    }

    if ($null -ne $MoveSearchBox) {
        $MoveSearchBox.Add_TextChanged({
            param($sender, $e)
            if ($script:SelectedMoveEndpoint) {
                Update-MovePlanList -EndpointIP $script:SelectedMoveEndpoint -SearchText ([string]$sender.Text)
            }
        })
    }

    if ($UniqueMoveEndpoints.Count -gt 0 -and $null -ne $MovePrismCentralCombo) {
        $MovePrismCentralCombo.SelectedIndex = 0
    }
    else {
        if ($null -ne $CreateMovePlanButton) { $CreateMovePlanButton.IsEnabled = $false }
        Clear-MovePlanDetails
        if ($null -ne $MovePlanListBox) {
            $MovePlanListBox.Items.Clear()
            $empty = New-Object System.Windows.Controls.ListBoxItem
            $empty.Content = 'No Move VMs discovered.'
            $empty.IsEnabled = $false
            $MovePlanListBox.Items.Add($empty) | Out-Null
        }
    }

    if ($null -ne $Window) {
        $Window.Add_MouseLeftButtonDown({
            param($sender, $e)
            try {
                if ($null -ne $e) { $e.Handled = $true }
                if ($null -ne $sender -and $sender -is [System.Windows.Window]) {
                    $sender.DragMove()
                }
            }
            catch {
                Write-Verbose "Move window drag failed: $($_.Exception.Message)"
            }
        })
    }

    $MinimizeButton = $Window.FindName('MinimizeMoveButton')
    if ($null -ne $MinimizeButton) {
        $MinimizeButton.Add_Click({
            param($sender, $e)
            if ($null -ne $Window) {
                $Window.WindowState = 'Minimized'
            }
        })
    }

    $CloseButton = $Window.FindName('CloseMoveButton')
    if ($null -ne $CloseButton) {
        $CloseButton.Add_Click({
            param($sender, $e)
            if ($null -ne $Window) {
                $Window.Close()
            }
        })
    }


    $Window.ShowDialog() | Out-Null
}
