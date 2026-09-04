using namespace MaterialDesignColors
using namespace MaterialDesignThemes.Wpf
using namespace System.Windows.Media

#Load required libraries
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase | Out-Null  

# .Net methods for hiding/showing the console in the background
Add-Type -Name Window -Namespace Console -MemberDefinition '
[DllImport("Kernel32.dll")]
public static extern IntPtr GetConsoleWindow();

[DllImport("user32.dll")]
public static extern bool ShowWindow(IntPtr hWnd, Int32 nCmdShow);
'

# Create synchronized hashtable to share variables across runspaces.
$SyncHash = [hashtable]::Synchronized(@{})
$SyncHashData = [hashtable]::Synchronized(@{})
$SyncHashData.RunspaceInstances = @()

# Get current working directory.
#$SyncHashData.ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$SyncHashData.ScriptPath = Split-Path $PSScriptRoot

# Get list of all dependent functions.
$Functions = Get-ChildItem "$($SyncHashData.ScriptPath)\.\Functions" -Recurse | 
Where-Object { $_.Extension -eq ".ps1" } | 
Select-Object -ExpandProperty FullName

# Load each function.
Foreach ($Function in $Functions) {
    . $Function
}

# Also load Move-specific helper scripts that live outside the core Functions folder.
$MoveScripts = Get-ChildItem (Join-Path $SyncHashData.ScriptPath 'Move') -Filter '*.ps1' -File -Recurse | Select-Object -ExpandProperty FullName
Foreach ($MoveScript in $MoveScripts) {
    . $MoveScript
}

# Load the dedicated Move module and window helpers.
Import-Module (Join-Path $SyncHashData.ScriptPath 'Move\MoveModule.psm1') -Force

# Load dll files
$AssemblyLocation = Join-Path -Path "$($SyncHashData.ScriptPath)\.\Resources" -ChildPath .\Assemblies
Foreach ($Assembly in (Get-ChildItem $AssemblyLocation -Filter *.dll)) {
    Unblock-File -Path "$($Assembly.FullName)" -Confirm:$false
    [System.Reflection.Assembly]::LoadFrom($Assembly.FullName) | Out-Null
}


# Run initial setup.
Start-Setup
$SyncHashData.DebugEnabled = $false
$SyncHashData.DebugTranscriptPath = $null
$script:DebugTranscriptActive = $false




$Refresh = @{
    'Reload' = $false;
}


Do { 
    $Refresh.Reload = $false

    # Import the xaml file.
    [xml]$Xaml = Get-Content -Path "$($SyncHashData.ScriptPath)\.\XAML\MainWindow.xaml" 

    # Read the form
    $Reader = (New-Object System.Xml.XmlNodeReader $Xaml)

    Try {
        # Load the Xaml reader.
        $SyncHash.MainWindow = [Windows.Markup.XamlReader]::Load($Reader) 

        # AutoFind all controls and add them to the SyncHash
        $Xaml.SelectNodes("//*[@*[contains(translate(name(.),'n','N'),'Name')]]")  | ForEach-Object { 
            (New-Variable -Name $_.Name -Value $SyncHash.MainWindow.FindName($_.Name) -Force)
            $SyncHash.($_.Name) = Get-Variable -Name $_.Name | Select-Object -ExpandProperty Value
            Remove-Variable -Name $_.Name -Force
        }
    }
    Catch {
        Write-Host "Unable to load Windows.Markup.XamlReader.";
        Exit
    }


    # Load saved theme and colors.
    If (Test-RegistryValue -Path $SyncHashData.RegistryPath -Value Theme) {
        $Theme = Get-ItemPropertyValue -Path $SyncHashData.RegistryPath -Name "Theme"
        Set-Theme -Window $SyncHash.MainWindow -ThemeMode $Theme
        $PrimaryColor = Get-PrimaryColor
        $AccentColor = Get-AccentColor

    }
    Else {
        $Theme = Get-SystemTheme 
        Set-Theme -Window $SyncHash.MainWindow -ThemeMode $Theme

    }
    

    #region Main Window #############################################################################


    $SyncHash.MainWindow.Icon = "$($SyncHashData.ScriptPath)\Resources\Images\DellLogo.ico"
    if ($null -ne $SyncHash.MainWindow) {
        $SyncHash.MainWindow.Add_KeyDown({
                If ($_.Key -eq 'F5') {
                    $Refresh.Reload = $true
                    $this.Close()
                }
            })
    }
    if ($null -ne $SyncHash.MainWindow) {
        $SyncHash.MainWindow.Add_MouseLeftButtonDown({
                # Allow clicking and dragging of window from anywhere.
                $_.handled = $true
                $this.DragMove()
            }) 

        $SyncHash.MainWindow.Add_Loaded({
                Hide-Console
            })

        $SyncHash.MainWindow.Add_Closed({
                Close-MainWindow
            })
    }

    if ($null -ne $SyncHash.MinimizeButton) { $SyncHash.MinimizeButton.Add_Click({ $SyncHash.MainWindow.WindowState = "Minimized" }) }
    if ($null -ne $SyncHash.CloseAppButton) { $SyncHash.CloseAppButton.Add_Click({ $SyncHash.MainWindow.Close() }) }

    # Open Treeview button
    $SyncHash.OpenTreeViewButton.Add_Click({ 
            $SyncHash.DrawerHost0.IsLeftDrawerOpen = $true
            $SyncHash.CloseTreeViewButton.IsChecked = $true
            $SyncHash.OpenTreeViewButton.Visibility = "Hidden"
        })

    if ($null -ne $SyncHash.DrawerHost3) {
        $SyncHash.DrawerHost3.Add_PreviewMouseLeftButtonDown({

                # Get mouse position and close drawer if outside of drawer.
                $Position = [System.Windows.Input.Mouse]::GetPosition($this)
                If ($Position.X -lt 685) {
                    $this.IsRightDrawerOpen = $false
                }
            })
    }


    # Info button
    $SyncHash.OpenInfoButton.Add_MouseEnter({        
            $AccentColor = Get-AccentColor
            $SyncHash.InfoIcon.Foreground = $AccentColor
        })
    $SyncHash.OpenInfoButton.Add_MouseLeave({ 
            $PrimaryColor = Get-PrimaryColor
            $SyncHash.InfoIcon.Foreground = $PrimaryColor 
        })        
    $SyncHash.OpenInfoButton.Add_Click({ Set-MoveLaunchIp; $SyncHash.DrawerHost1.IsTopDrawerOpen = $true })

    # Discover button
    $SyncHash.OpenDiscoverButton.Add_MouseEnter({ 
            $AccentColor = Get-AccentColor
            $SyncHash.DiscoverIcon.Foreground = $AccentColor 
        })
    $SyncHash.OpenDiscoverButton.Add_MouseLeave({ 
            $PrimaryColor = Get-PrimaryColor
            $SyncHash.DiscoverIcon.Foreground = $PrimaryColor 
        })
    $SyncHash.OpenDiscoverButton.Add_Click({ $SyncHash.DrawerHost1.IsBottomDrawerOpen = $true })

    # Tasks button
    $SyncHash.OpenTasksButton.Add_MouseEnter({ 
            $AccentColor = Get-AccentColor
            $SyncHash.TasksIcon.Foreground = $AccentColor 
        })
    $SyncHash.OpenTasksButton.Add_MouseLeave({ $PrimaryColor = Get-PrimaryColor
            $SyncHash.TasksIcon.Foreground = $PrimaryColor 
        })
    $SyncHash.OpenTasksButton.Add_Click({ $SyncHash.DrawerHost2.IsTopDrawerOpen = $true })

    # Reports button
    $SyncHash.OpenReportsButton.Add_MouseEnter({ 
            $AccentColor = Get-AccentColor
            $SyncHash.ReportsIcon.Foreground = $AccentColor 
        })
    $SyncHash.OpenReportsButton.Add_MouseLeave({ 
            $PrimaryColor = Get-PrimaryColor
            $SyncHash.ReportsIcon.Foreground = $PrimaryColor 
        })
    $SyncHash.OpenReportsButton.Add_Click({ If (Test-Path -Path $SyncHashData.RootDirectory) { Invoke-Item $SyncHashData.RootDirectory } })

    $SyncHash.OpenMoveButton.Add_Click({
            try {
                Show-MoveWindow
            }
            catch {
                $SyncHash.Snackbar.MessageQueue.Enqueue("Move inventory window could not be opened: $($_.Exception.Message)")
            }
        })

    if ($null -ne $SyncHash.ExportPrismReportButton) {
        $SyncHash.ExportPrismReportButton.Add_Click({
                $selectedMoveIPs = @($SyncHash.ListBoxPrismCentral.SelectedItems | ForEach-Object { [string]$_ })
                If ($selectedMoveIPs.Count -eq 0) {
                    $SyncHash.Snackbar.MessageQueue.Enqueue("Select at least one Move VM first.")
                    return
                }
            })
    }

    # Options button
    $SyncHash.OpenOptionsButton.Add_MouseEnter({ 
            $AccentColor = Get-AccentColor
            $SyncHash.OptionsIcon.Foreground = $AccentColor 
        })
    $SyncHash.OpenOptionsButton.Add_MouseLeave({ 
            $PrimaryColor = Get-PrimaryColor
            $SyncHash.OptionsIcon.Foreground = $PrimaryColor 
        })
    $SyncHash.OpenOptionsButton.Add_Click({ $SyncHash.DrawerHost1.IsRightDrawerOpen = $true })

    # Theme button
    $SyncHash.OpenThemeButton.Add_MouseEnter({ 
            $AccentColor = Get-AccentColor
            $SyncHash.ThemeIcon.Foreground = $AccentColor 
        })
    $SyncHash.OpenThemeButton.Add_MouseLeave({ 
            $PrimaryColor = Get-PrimaryColor
            $SyncHash.ThemeIcon.Foreground = $PrimaryColor 
        })
    $SyncHash.OpenThemeButton.Add_Click({ $SyncHash.DrawerHost2.IsBottomDrawerOpen = $true })

    $SyncHash.OpenDebugButton.Add_Click({ $SyncHash.DrawerHost3.IsRightDrawerOpen = $true })

    $SyncHash.DebugToggleButton.Add_Checked({
            $DebugDirectory = Join-Path $SyncHashData.RootDirectory 'Debug'
            New-Item -ItemType Directory -Force -Path $DebugDirectory | Out-Null
            $DebugPath = Join-Path $DebugDirectory ("XC-Manager-{0}.log" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))

            try {
                Start-Transcript -Path $DebugPath -IncludeInvocationHeader -ErrorAction Stop | Out-Null
                $SyncHashData.DebugEnabled = $true
                $SyncHashData.DebugTranscriptPath = $DebugPath
                $script:DebugTranscriptActive = $true
                $SyncHash.DebugStatusText.Text = 'Debugging is on'
                $SyncHash.DebugLogPathText.Text = $DebugPath
            }
            catch {
                $SyncHashData.DebugEnabled = $false
                $SyncHash.DebugToggleButton.IsChecked = $false
                $SyncHash.DebugStatusText.Text = "Unable to start debugging: $($_.Exception.Message)"
            }
        })

    $SyncHash.DebugToggleButton.Add_Unchecked({
            if ($script:DebugTranscriptActive) {
                Stop-Transcript | Out-Null
                $script:DebugTranscriptActive = $false
            }
            $SyncHashData.DebugEnabled = $false
            $SyncHash.DebugStatusText.Text = 'Debugging is off'
        })

    $SyncHash.OpenDebugLogButton.Add_Click({
            $DebugDirectory = Join-Path $SyncHashData.RootDirectory 'Debug'
            New-Item -ItemType Directory -Force -Path $DebugDirectory | Out-Null
            Invoke-Item $DebugDirectory
        })

    $SyncHash.ClearDebugLogButton.Add_Click({
            if ($script:DebugTranscriptActive) {
                Stop-Transcript | Out-Null
                $script:DebugTranscriptActive = $false
            }
            if ($SyncHashData.DebugTranscriptPath -and (Test-Path $SyncHashData.DebugTranscriptPath)) {
                Remove-Item -LiteralPath $SyncHashData.DebugTranscriptPath -Force
            }
            $SyncHashData.DebugEnabled = $false
            $SyncHashData.DebugTranscriptPath = $null
            $SyncHash.DebugToggleButton.IsChecked = $false
            $SyncHash.DebugLogPathText.Text = ''
            $SyncHash.DebugStatusText.Text = 'Debug log cleared'
        })

    $SyncHash.CheckBoxTriggerSyncTreeView.Add_Checked({

            # If for any reason the checkbox becomes visible, hide it.
            If ($Synchash.CheckBoxTriggerSyncTreeView.Visibility -eq "Visible") {
                $Synchash.CheckBoxTriggerSyncTreeView.Visibility = "Hidden"
            }

            If ($Synchash.CheckBoxTriggerSyncTreeView.IsChecked -eq $true) {
                        
                $SyncHash.CheckBoxTriggerSyncTreeView.IsChecked = $false

                Start-MarshallingEvents "SyncTreeView"

            }

        })

    $SyncHash.CheckBoxTriggerUpdatePEListBox.Add_Checked({

            # If for any reason the checkbox becomes visible, hide it.
            If ($Synchash.CheckBoxTriggerUpdatePEListBox.Visibility -eq "Visible") {
                $Synchash.CheckBoxTriggerUpdatePEListBox.Visibility = "Hidden"
            }

            If ($Synchash.CheckBoxTriggerUpdatePEListBox.IsChecked -eq $true) {
                        
                $SyncHash.CheckBoxTriggerUpdatePEListBox.IsChecked = $false

                Start-MarshallingEvents "UpdateMoveListBox"

            }

        })

    #endregion Main Window #############################################################################

            

    #region TreeView Drawer #############################################################################


    $SyncHash.TreeView.Add_Loaded({ 
            $this.Dispatcher.BeginInvoke([System.Windows.Threading.DispatcherPriority]::Background, [Action] {
                Initialize-TreeView

                # Import saved Prism Element and Prism Central lists.
                Import-SavedLists
            }) | Out-Null
        })
    $SyncHash.TreeView.Add_SelectedItemChanged({ Get-SelectedInfo; Set-MoveLaunchIp })
    
    # TreeView sort ascending order by header property.
    $SyncHash.TreeView.Items.SortDescriptions.Add([System.ComponentModel.SortDescription]@{PropertyName = "Header"; Direction = "Ascending" })

    # Close TreeView button
    $SyncHash.CloseTreeViewButton.Add_Click({ 
            $this.IsChecked = $false
            $SyncHash.OpenTreeViewButton.Visibility = "Visible"
            $SyncHash.OpenTreeViewButton.IsChecked = $false
        })

    $SyncHash.DrawerHost0.Add_PreviewMouseLeftButtonDown({

            # Get mouse position and close drawer if outside of drawer.
            $Position = [System.Windows.Input.Mouse]::GetPosition($this)
            If ($Position.X -gt 360) {
                $this.IsLeftDrawerOpen = $false
            }
        })

    $SyncHash.DrawerHost0.Add_DrawerClosing({
            $this.IsLeftDrawerOpen = $false
            $SyncHash.CloseTreeViewButton.IsChecked = $false
            $SyncHash.OpenTreeViewButton.Visibility = "Visible"
            $SyncHash.OpenTreeViewButton.IsChecked = $false
        })

    $SyncHash.SearchBox.Add_KeyDown({
            If ($_.Key -eq 'Return') {
                $FoundItem = Find-Host ($SyncHash.SearchBox.Text).Trim()
                $this.Clear()
                If ($FoundItem -ne $null) {
                    $FoundItem.IsSelected = $true
                    $FoundItem.Parent.ExpandSubtree()
                    $FoundItem.BringIntoView()
                    $FoundItem.Focus()
                }
            }

        })


    ### Right-Click Context Menu Items


    $SyncHash.MenuInventoryCluster.Add_Click({
            $SyncHash.Snackbar.MessageQueue.Enqueue('Cluster and host inventory has been disabled for the Move-only build.')
        })
    $SyncHash.MenuRemoveFromInventory.Add_Click({ 

            # Delete files from disk.


            $SyncHash.ListMove.Items | Where-Object { $_.Content -match $Script:AosClusterIP } | Foreach-Object {

                If ($_.IsSelected -eq $true) {
                    $AccentColor = Get-AccentColor
                    $_.Background = $AccentColor
                    $_.Background.Opacity = 1
                }
                Else {
                    $_.Background = "#00FFFFFF"
                    $_.Background.Opacity = 1
                }
            }
            
            # Remove from TreeView.
            $SyncHash.TreeView.SelectedItem.Parent.Items.Remove($SyncHash.TreeView.SelectedItem) 

            # If server sync is enabled do this.
            If ($SyncHashData.SyncData -eq $true) {
                If ($SelectedTag) {
                    Remove-MenuTreeViewItem $SelectedCluster $SelectedTag
                }
                Else {
                    Remove-MenuTreeViewItem $SelectedCluster
                }
            }
            
        })


    # Select item in treeview on right-click before context menu appears
    $SyncHash.TreeView.Add_PreviewMouseRightButtonDown({

            $Script:RightClickedItem = $this.InputHitTest($args[1].GetPosition($this))
            $Script:Parent = [System.Windows.Media.VisualTreeHelper]::GetParent($RightClickedItem)
            $Parent.TemplatedParent.IsSelected = $true
            $Parent.TemplatedParent.Focus()
        })




    #endregion TreeView #############################################################################

    

    #region Theme Drawer #############################################################################
    

    $SyncHash.DrawerHost2.Add_PreviewMouseLeftButtonDown({

            # Get mouse position and close drawer if outside of drawer.
            $Position = [System.Windows.Input.Mouse]::GetPosition($this)
            If (($Position.Y -lt 586) -and ($SyncHash.PrimaryColorPicker.IsVisible -eq $false) -and ($Synchash.AccentColorPicker.IsVisible -eq $false)) {
                $this.IsBottomDrawerOpen = $false           
            }
        })

    $SyncHash.ThemeToggleButton.Add_Loaded({

            # Load saved theme and colors.
            If (Test-RegistryValue -Path $SyncHashData.RegistryPath -Value Theme) {
                $Theme = Get-ItemPropertyValue -Path $SyncHashData.RegistryPath -Name "Theme"
            }
            Else {
                $Theme = Get-SystemTheme 
                #Set-Theme -Window $SyncHash.MainWindow -ThemeMode $Theme
            }

            If ($Theme -eq "Dark") { 
                $this.IsChecked = $true 
                #Set-ItemProperty -Path $SyncHashData.RegistryPath -Value "Dark" -Name Theme | Out-Null
            }
            Else {
                $this.IsChecked = $false
                #Set-ItemProperty -Path $SyncHashData.RegistryPath -Value "Light" -Name Theme | Out-Null 
            }
        })
    $SyncHash.ThemeToggleButton.Add_Click({ 
            $Theme = If ($this.IsChecked -eq $true) { "Dark" } Else { "Light" }
            Set-Theme -Window $SyncHash.MainWindow -ThemeMode $Theme
            Set-ItemProperty -Path $SyncHashData.RegistryPath -Value $Theme -Name Theme | Out-Null
        })

    $SyncHash.TextBoxSelectedPrimaryColor.Add_Loaded({ 
            $PrimaryColor = Get-PrimaryColor
            $this.Text = $PrimaryColor 
        })
    $SyncHash.TextBoxSelectedPrimaryColor.Add_TextChanged({

            #TextBoxSelectedPrimaryColor defaults to #00000000
            If ($this.Text -ne "#00000000") {
                $PrimaryColor = $this.Text
                Set-PrimaryColor $PrimaryColor
            }
            Else {
                $this.Text = $PrimaryColor 
            }
        })
    

    $SyncHash.TextBoxSelectedAccentColor.Add_Loaded({ 
            $AccentColor = Get-AccentColor
            $this.Text = $AccentColor 
        })
    $SyncHash.TextBoxSelectedAccentColor.Add_TextChanged({
            If ($this.Text -ne "#00000000") {
                $AccentColor = $this.Text
                Set-AccentColor $AccentColor
            }
            Else {
                $this.Text = $AccentColor 
            }
        })

    

    #endregion Theme Drawer #############################################################################



    #region Options Drawer #############################################################################

    $SyncHash.DrawerHost1.Add_PreviewMouseLeftButtonDown({

            # Get mouse position and close drawer if outside of drawer.
            $Position = [System.Windows.Input.Mouse]::GetPosition($this)
            If ($Position.X -lt 855) {
                $this.IsRightDrawerOpen = $false
            }
        })

    #region Save Credentials

    #CheckBoxSavePrismCentralCreds
    $SyncHash.CheckBoxSavePrismCentralCreds.Add_Click({
            If (!$SyncHashData.PrismCentralCreds -and $this.IsChecked -eq $true) {
                $Creds = Get-UserCredentials -EndPoint "Prism Central" -UserClicked $true
                If ($Creds) {
                    Save-Credentials "Prism Central" $Creds
                    $Creds = $null
                    [System.GC]::Collect()
                }
                Else {
                    $this.IsChecked = $false
                }
            }   
        })
    $SyncHash.CheckBoxSavePrismCentralCreds.Add_UnChecked({
            Remove-SavedCredentials -EndPoint "Prism Central"
            [System.GC]::Collect()
        })

    #CheckBoxSavePrismElementCreds
    $SyncHash.CheckBoxSavePrismElementCreds.Add_Checked({
            If (!$SyncHashData.PrismElementCreds -and $this.IsChecked -eq $true) {    
                $Creds = Get-UserCredentials -EndPoint "Prism Element" -UserClicked $true
                If ($Creds) {
                    Save-Credentials "Prism Element" $Creds
                    $Creds = $null
                    [System.GC]::Collect()
                }
                Else {
                    $this.IsChecked = $false
                }
            }
        })
    $SyncHash.CheckBoxSavePrismElementCreds.Add_UnChecked({
            Remove-SavedCredentials -EndPoint "Prism Element"
            [System.GC]::Collect()
        })

    #CheckBoxSavevCenterCreds
    $SyncHash.CheckBoxSavevCenterCreds.Add_Checked({
            If (!$SyncHashData.vCenterCreds -and $this.IsChecked -eq $true) {
                $Creds = Get-UserCredentials -EndPoint "vCenter" -UserClicked $true
                If ($Creds) {
                    Save-Credentials "vCenter" $Creds
                    $Creds = $null
                    [System.GC]::Collect()
                }
                Else {
                    $this.IsChecked = $false
                }
            }
        })
    $SyncHash.CheckBoxSavevCenterCreds.Add_UnChecked({
            Remove-SavedCredentials -EndPoint vCenter
            [System.GC]::Collect()
        })

    #CheckBoxSaveMoveCreds
    $SyncHash.CheckBoxSaveMoveCreds.Add_Checked({
            If (!$SyncHashData.MoveCreds -and $this.IsChecked -eq $true) {
                $Creds = Get-UserCredentials -EndPoint "Move" -UserClicked $true
                If ($Creds) {
                    Save-Credentials "Move" $Creds
                    $Creds = $null
                    [System.GC]::Collect()
                }
                Else {
                    $this.IsChecked = $false
                }
            }
        })
    $SyncHash.CheckBoxSaveMoveCreds.Add_UnChecked({
            Remove-SavedCredentials -EndPoint Move
            [System.GC]::Collect()
        })

    #CheckBoxSaveServiceAccountCreds
    $SyncHash.CheckBoxSaveServiceAccountCreds.Add_Checked({
            If (!$SyncHashData.ServiceAccountCreds -and $this.IsChecked -eq $true) {
                $Creds = Get-UserCredentials -EndPoint "Service Account" -UserClicked $true
                If ($Creds) {
                    Save-Credentials "Service Account" $Creds
                    $Creds = $null
                    [System.GC]::Collect()
                }
                Else {
                    $this.IsChecked = $false
                }
            }
        })
    $SyncHash.CheckBoxSaveServiceAccountCreds.Add_UnChecked({
            Remove-SavedCredentials -EndPoint "Service Account"
            [System.GC]::Collect()
        })
    
    # CheckBoxUseSavedCrentials
    $SyncHash.CheckBoxUseSavedCredentials.Add_Checked({
            Set-CredsPreference $true
        })
    $SyncHash.CheckBoxUseSavedCredentials.Add_Unchecked({
            Set-CredsPreference $false
        })

    #endregion Save Credentials

    # Console visibility toggle
    $Synchash.ConsoleVisibilityToggle.Add_Click({
            If ($this.IsChecked -eq $true) {
                Show-Console
            }
            Else {
                Hide-Console
            }
        })

    # Sync data toggle


    # Load saved sync data preferences.

    # Max tasks slider
    $SyncHash.Slider.Add_Loaded({
            $SyncHashData.MaxTasks = Get-ItemPropertyValue -Path $SyncHashData.RegistryPath -Name MaxTasks
            $this.Value = $SyncHashData.MaxTasks
        })
    $SyncHash.Slider.Add_ValueChanged({       
            $SyncHashData.MaxTasks = $this.Value
            Set-ItemProperty -Path $SyncHashData.RegistryPath -Value $this.Value -Name "MaxTasks" | Out-Null
        })


    # Reset tasks button
    $SyncHash.ResetTasksButton.Add_Click({
            Set-ItemProperty -Path $SyncHashData.RegistryPath -Value ([int]$env:NUMBER_OF_PROCESSORS + 1) -Name "MaxTasks" | Out-Null
            $SyncHashData.MaxTasks = Get-ItemPropertyValue -Path $SyncHashData.RegistryPath -Name MaxTasks
            $SyncHash.Slider.Value = $SyncHashData.MaxTasks
            $SyncHashData.RunningTasks = 0
        })
    $SyncHash.ResetTasksButton.Add_MouseEnter({
            $AccentColor = Get-AccentColor
            $SyncHash.ResetTasksIcon.Foreground = $AccentColor
        })
    $SyncHash.ResetTasksButton.Add_MouseLeave({
            $PrimaryColor = Get-PrimaryColor
            $SyncHash.ResetTasksIcon.Foreground = $PrimaryColor
        })




    #endregion Options Drawer #############################################################################
    
    

    #region Info Drawer #############################################################################

    function Get-SelectedMoveBrowserTarget {
        $SelectedItem = $SyncHash.TreeView.SelectedItem
        if ($null -eq $SelectedItem) { return $null }

        $MoveInventoryRoot = Join-Path $SyncHashData.RootDirectory 'Data\MoveVMs'
        if (-not (Test-Path $MoveInventoryRoot)) { return $null }

        $SelectedTag = [string]$SelectedItem.Tag
        $EndpointIP = $null
        $PlanId = $null
        $VmUuid = $null

        if ($SelectedTag -like 'MoveVm:*') {
            $parts = $SelectedTag.Substring(7) -split '\|', 3
            if ($parts.Count -ge 3) {
                $EndpointIP = $parts[0]
                $PlanId = $parts[1]
                $VmUuid = $parts[2]
            }
        }
        elseif ($SelectedTag -like 'MovePlan:*') {
            $parts = $SelectedTag.Substring(9) -split '\|', 2
            if ($parts.Count -ge 2) {
                $EndpointIP = $parts[0]
                $PlanId = $parts[1]
            }
        }
        elseif ($SelectedTag -like 'MoveEndpoint:*') {
            $EndpointIP = $SelectedTag.Substring(13)
        }

        foreach ($JsonFile in Get-ChildItem -Path $MoveInventoryRoot -Filter '*.json' -File -ErrorAction SilentlyContinue) {
            $MoveData = Get-Content -Path $JsonFile.FullName -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json
            if ($null -eq $MoveData) { continue }

            foreach ($Entry in @($MoveData)) {
                if ($EndpointIP -and [string]$Entry.MoveIP -ne $EndpointIP) { continue }
                if ($PlanId -and [string]$Entry.MovePlanId -ne $PlanId) { continue }
                if ($VmUuid -and [string]$Entry.VmUuid -ne $VmUuid) { continue }
                if (-not $VmUuid -and $SelectedTag -like 'MovePlan:*' -and $Entry.MovePlanId -eq $PlanId) { return $Entry }
                if (-not $VmUuid -and $SelectedTag -like 'MoveEndpoint:*' -and -not $Entry.IsDiscoveryRecord) { return $Entry }
                if ($VmUuid -and [string]$Entry.VmUuid -eq $VmUuid) { return $Entry }
            }
        }

        return $null
    }

    function Set-MoveLaunchIp {
        $SelectedMoveEntry = Get-SelectedMoveBrowserTarget
        if ($null -eq $SelectedMoveEntry) {
            $SyncHash.MoveLaunchIpItem.Content = 'IP: No Move VM selected'
            return
        }

        $SyncHash.MoveLaunchIpItem.Content = "IP: $($SelectedMoveEntry.MoveIP)"
    }

    function Open-MoveVmWebpage {
        $SelectedMoveEntry = Get-SelectedMoveBrowserTarget
        if ($null -eq $SelectedMoveEntry) {
            [System.Windows.MessageBox]::Show('Select a Move VM, migration plan, or Move appliance first.', 'Launch Move VM') | Out-Null
            return
        }

        $TargetUrl = "https://$($SelectedMoveEntry.MoveIP):9440/PrismGateway/services/rest/v1/move_plans/$($SelectedMoveEntry.MovePlanId)"
        Start-Process $TargetUrl
    }
 #Region Support Bundle Download #############################################################################
    function Invoke-MoveSupportBundleDownload {
        param(
            [Parameter(Mandatory = $true)]
            [string]$MoveIp,
            [Parameter(Mandatory = $true)]
            [string]$OutputPath,
            [Parameter(Mandatory = $true)]
            [hashtable]$Headers
        )

        Write-Warning "Support bundle download is not implemented for Move appliance $MoveIp."
        return $false
    }
#endregion Support Bundle Download #############################################################################
    $SyncHash.MoveLaunchListBox.Add_MouseLeftButtonUp({ Open-MoveVmWebpage })
    $SyncHash.SupportBundleButton.Add_Click({
            $SelectedMoveEntry = Get-SelectedMoveBrowserTarget
            if ($null -eq $SelectedMoveEntry) {
                [System.Windows.MessageBox]::Show('Select a Move VM, migration plan, or Move appliance first.', 'Support Bundle') | Out-Null
                return
            }

            $OutputPath = Join-Path $SyncHashData.RootDirectory 'Data\MoveSupportBundles'
            $Headers = @{}
            Invoke-MoveSupportBundleDownload -MoveIp ([string]$SelectedMoveEntry.MoveIP) -OutputPath $OutputPath -Headers $Headers | Out-Null
            [System.Windows.MessageBox]::Show('Support Bundle download is not implemented yet.', 'Support Bundle') | Out-Null
        })

    #endregion Info #############################################################################



    #region Devices Drawer #############################################################################

    #endregion Devices #############################################################################



    #region Notes Drawer #############################################################################

    $SyncHash.TextBoxNotes.Add_MouseDown({ $this.Focus() })
    $SyncHash.TextBoxNotes.Add_MouseEnter({ Update-Notes })
    $SyncHash.TextBoxNotes.Add_LostFocus({ Update-Notes })

    #endregion Notes #############################################################################



    #region Discover Drawer #############################################################################

    function Update-MoveSummary {
        $MoveInventory = @()
        $InventoryRoot = Join-Path $SyncHashData.RootDirectory 'Data\MoveVMs'
        if (Test-Path $InventoryRoot) {
            $MoveInventory = @(Import-MoveInventory -RootDirectory $InventoryRoot)
        }

        # A "Move VM" in this application is the Move appliance/endpoint
        # entered by the user, not a guest VM inside a migration plan.
        $MoveVmCount = @(
            $MoveInventory |
                Where-Object { $_.MoveIP } |
                Select-Object -ExpandProperty MoveIP -Unique
        ).Count

        # Discovery records are endpoint cache markers and are NOT plans.
        $PlanCount = @(
            $MoveInventory |
                Where-Object { $_.MovePlanId -and -not $_.IsDiscoveryRecord } |
                Select-Object -ExpandProperty MovePlanId -Unique
        ).Count

        if ($null -ne $SyncHash.MoveVmsCount) { $SyncHash.MoveVmsCount.Text = [string]$MoveVmCount }
        if ($null -ne $SyncHash.MigrationPlansCount) { $SyncHash.MigrationPlansCount.Text = [string]$PlanCount }
    }

    function Reload-MoveTree {
        $InventoryRoot = Join-Path $SyncHashData.RootDirectory 'Data\MoveVMs'
        $MoveInventory = @()
        if (Test-Path $InventoryRoot) {
            $MoveInventory = @(Import-MoveInventory -RootDirectory $InventoryRoot)
        }

        if ($null -eq $SyncHash.TreeView) { return }

        $SyncHash.TreeView.Items.Clear()
        $Root = New-Object System.Windows.Controls.TreeViewItem
        $Root.Header = 'Move VMs'
        $Root.Tag = 'MoveVmsRoot'
        $Root.Uid = 'MoveVmsRoot'
        $SyncHash.TreeView.Items.Add($Root) | Out-Null

        if ($MoveInventory.Count -eq 0) {
            $EmptyNode = New-Object System.Windows.Controls.TreeViewItem
            $EmptyNode.Header = 'No Move VMs discovered'
            $EmptyNode.IsEnabled = $false
            $Root.Items.Add($EmptyNode) | Out-Null
            Update-MoveSummary
            return
        }

        # Group by Move appliance/endpoint first.
        $EndpointGroups = @(
            $MoveInventory |
                Where-Object { $_.MoveIP } |
                Group-Object -Property MoveIP |
                Sort-Object Name
        )

        foreach ($EndpointGroup in $EndpointGroups) {
            $EndpointIP = [string]$EndpointGroup.Name
            $EndpointRecord = @($EndpointGroup.Group | Where-Object { -not $_.IsDiscoveryRecord } | Select-Object -First 1)

            $EndpointLabel = $EndpointIP
            $EndpointName = $null
            if ($EndpointRecord.Count -gt 0) {
                foreach ($PropertyName in @('MoveVmName','MoveName','EndpointName','Name')) {
                    if ($EndpointRecord[0].PSObject.Properties.Name -contains $PropertyName -and $EndpointRecord[0].$PropertyName) {
                        $EndpointName = [string]$EndpointRecord[0].$PropertyName
                        break
                    }
                }
            }
            if ($EndpointName) { $EndpointLabel = "$EndpointName ($EndpointIP)" }

            $EndpointNode = New-Object System.Windows.Controls.TreeViewItem
            $EndpointNode.Header = $EndpointLabel
            $EndpointNode.Tag = "MoveEndpoint:$EndpointIP"
            $EndpointNode.Uid = $EndpointIP
            $EndpointNode.ToolTip = "Move appliance: $EndpointIP"
            $Root.Items.Add($EndpointNode) | Out-Null

            $PlanGroups = @(
                $EndpointGroup.Group |
                    Where-Object { $_.MovePlanId -and -not $_.IsDiscoveryRecord } |
                    Group-Object -Property MovePlanId |
                    Sort-Object @{Expression={
                        $x = $_.Group | Select-Object -First 1
                        if ($x.MovePlanName) { [string]$x.MovePlanName } else { [string]$_.Name }
                    }}
            )

            foreach ($PlanGroup in $PlanGroups) {
                $FirstPlanEntry = $PlanGroup.Group | Select-Object -First 1
                $PlanName = if ($FirstPlanEntry.MovePlanName) { [string]$FirstPlanEntry.MovePlanName } else { [string]$PlanGroup.Name }

                $PlanNode = New-Object System.Windows.Controls.TreeViewItem
                $PlanNode.Header = $PlanName
                $PlanNode.Tag = "MovePlan:$EndpointIP|$($PlanGroup.Name)"
                $PlanNode.Uid = "$EndpointIP|$($PlanGroup.Name)"
                $PlanNode.ToolTip = "Plan ID: $($PlanGroup.Name)"
                $EndpointNode.Items.Add($PlanNode) | Out-Null

                # A VM may belong to multiple plans. Keep it under each plan so
                # the plan contents remain explicit and selectable.
                foreach ($MoveVm in @($PlanGroup.Group | Where-Object { $_.VmUuid -or $_.VmName } | Sort-Object VmName, VmUuid)) {
                    $VmLabel = if ($MoveVm.VmName) { [string]$MoveVm.VmName } else { [string]$MoveVm.VmUuid }
                    $VmNode = New-Object System.Windows.Controls.TreeViewItem
                    $VmNode.Header = $VmLabel
                    $VmNode.Tag = "MoveVm:$EndpointIP|$($PlanGroup.Name)|$($MoveVm.VmUuid)"
                    $VmNode.Uid = "$EndpointIP|$($PlanGroup.Name)|$($MoveVm.VmUuid)"
                    $VmNode.ToolTip = "VM UUID: $($MoveVm.VmUuid)"
                    $PlanNode.Items.Add($VmNode) | Out-Null
                }
            }

            $DiscoveryOnly = @($EndpointGroup.Group | Where-Object { $_.IsDiscoveryRecord }).Count -gt 0
            if ($PlanGroups.Count -eq 0 -and $DiscoveryOnly) {
                $NoPlansNode = New-Object System.Windows.Controls.TreeViewItem
                $NoPlansNode.Header = '[No migration plans found]'
                $NoPlansNode.IsEnabled = $false
                $EndpointNode.Items.Add($NoPlansNode) | Out-Null
            }
        }

        # Keep a useful endpoint even if malformed cache data contains no IP.
        if ($EndpointGroups.Count -eq 0) {
            $EmptyNode = New-Object System.Windows.Controls.TreeViewItem
            $EmptyNode.Header = 'Cached data contains no Move endpoint'
            $EmptyNode.IsEnabled = $false
            $Root.Items.Add($EmptyNode) | Out-Null
        }

        Update-MoveSummary
    }

    $SyncHash.TextBoxPrismCentral.Add_KeyDown({
            If ($_.Key -eq 'Return') {
                $IPList = $this.Text
                If ($IPList) {
                    $IPList = Format-IPList $IPList
                    $IPList = Confirm-ValidIP $IPList
                    If ($IPList) {
                        foreach ($Item in @($IPList)) {
                            $Existing = @($SyncHash.ListBoxPrismCentral.Items | Where-Object { [string]$_ -eq [string]$Item })
                            if ($Existing.Count -eq 0) {
                                $SyncHash.ListBoxPrismCentral.Items.Add([string]$Item) | Out-Null
                            }
                        }
                        $SyncHash.ListBoxPrismCentral.Items | Sort-Object | ForEach-Object { $_ } | Out-Null
                    }
                }

                $this.Clear()
                $SyncHash.ListBoxPrismCentral.Items | Out-File -FilePath "$($SyncHashData.RootDirectory)\Data\MoveVMs.txt" -Force
            }
        })

    $SyncHash.PCPopupBox.Add_Opened({
            $AccentColor = Get-AccentColor
            $this.Background = $AccentColor
            $this.BorderBrush = $AccentColor
        })
    $SyncHash.PCPopupBox.Add_Closed({
            $PrimaryColor = Get-PrimaryColor
            $this.Background = $PrimaryColor
            $this.BorderBrush = $PrimaryColor
        })

    $SyncHash.PCPopupBoxValues.Add_SelectionChanged({
            If ($this.SelectedItem) {
                Switch ($this.SelectedItem.Text) {
                    Add { 
                        $IPList = $SyncHash.TextBoxPrismCentral.Text
                        If ($IPList) {
                            $IPList = Format-IPList $IPList
                            $IPList = Confirm-ValidIP $IPList
                            If ($IPList) {
                                foreach ($Item in @($IPList)) {
                                    $Existing = @($SyncHash.ListBoxPrismCentral.Items | Where-Object { [string]$_ -eq [string]$Item })
                                    if ($Existing.Count -eq 0) {
                                        $SyncHash.ListBoxPrismCentral.Items.Add([string]$Item) | Out-Null
                                    }
                                }
                            }
                        }
                        $SyncHash.TextBoxPrismCentral.Clear()
                        $SyncHash.ListBoxPrismCentral.Items | Out-File -FilePath "$($SyncHashData.RootDirectory)\Data\MoveVMs.txt" -Force
                    }
                    "Import List" { 
                        $IPList = Import-File "Text files (*.txt) |*.txt"
                        If ($IPList) {
                            $IPList = Format-IPList $IPList
                            $IPList = Confirm-ValidIP $IPList
                            If ($IPList) {
                                foreach ($Item in @($IPList)) {
                                    $Existing = @($SyncHash.ListBoxPrismCentral.Items | Where-Object { [string]$_ -eq [string]$Item })
                                    if ($Existing.Count -eq 0) {
                                        $SyncHash.ListBoxPrismCentral.Items.Add([string]$Item) | Out-Null
                                    }
                                }
                            }
                        }
                        $SyncHash.TextBoxPrismCentral.Clear()
                        $SyncHash.ListBoxPrismCentral.Items | Out-File -FilePath "$($SyncHashData.RootDirectory)\Data\MoveVMs.txt" -Force
                    }
                }
                $this.UnselectAll()
            }
        })

    $SyncHash.ListBoxPrismCentral.Add_KeyDown({
            If ($_.Key -eq "Delete" -or $_.Key -eq "Back") {
                $ItemsToRemove = @($this.SelectedItems)
                foreach ($Item in $ItemsToRemove) {
                    $this.Items.Remove($Item) | Out-Null
                }
                $this.Items | Out-File -FilePath "$($SyncHashData.RootDirectory)\Data\MoveVMs.txt" -Force
            }
        })   

    $SyncHash.ButtonInventoryPCList.Add_Click({
            $SelectedIPs = @($SyncHash.ListBoxPrismCentral.Items | ForEach-Object { [string]$_ })
            if ($SelectedIPs.Count -eq 0) {
                $SyncHash.Snackbar.MessageQueue.Enqueue('Add at least one Move VM IP before running inventory.')
                return
            }

            $TaskID = Get-TaskID
            $TargetIPs = $SelectedIPs -join ', '
            New-Task -TaskID $TaskID -Target "Move Inventory" -Details "Discovering Move VMs from: $TargetIPs"

            $InventoryRoot = Join-Path $SyncHashData.RootDirectory 'Data\MoveVMs'
            if (-not (Test-Path $InventoryRoot)) {
                New-Item -ItemType Directory -Force -Path $InventoryRoot | Out-Null
            }

            $MoveInventory = @()
            $FailedIPs = @()
            $Header = Set-NtnxApiHeader -EndPoint 'Move'
            if (-not $Header) {
                Update-Task -TaskID $TaskID -Details 'Move credentials were not provided. Inventory cancelled.' -Status 'Complete'
                $SyncHash.Snackbar.MessageQueue.Enqueue('Move inventory cancelled: credentials were not provided.')
                return
            }

            foreach ($MoveVmIP in $SelectedIPs | Select-Object -Unique) {
                if (-not $MoveVmIP) { continue }

                try {
                    Update-Task -TaskID $TaskID -Details "Querying Move plans and VMs from: $MoveVmIP"
                    $MoveInventory += @(Get-MoveVmInventory -MoveVmIP $MoveVmIP -Header $Header -RootDirectory $InventoryRoot)
                }
                catch {
                    $FailedIPs += $MoveVmIP
                    Update-Task -TaskID $TaskID -Details "Failed to query $MoveVmIP : $($_.Exception.Message)"
                    $SyncHash.Snackbar.MessageQueue.Enqueue("Move inventory failed for ${MoveVmIP}: $($_.Exception.Message)")
                }
            }

            if ($MoveInventory.Count -eq 0) {
                Update-Task -TaskID $TaskID -Details "No new VMs found, loading from previous inventory..."
                $MoveInventory = @(Import-MoveInventory -RootDirectory $InventoryRoot)
            }

            $SyncHashData.MoveVmInventory = $MoveInventory
            $SyncHash.ListBoxPrismCentral.Items | Out-File -FilePath "$($SyncHashData.RootDirectory)\Data\MoveVMs.txt" -Force
            
            Update-Task -TaskID $TaskID -Details "Rebuilding Move VM tree and updating counters..."
            Reload-MoveTree
            
            # A Move VM is a Move appliance/endpoint. Migration plans are counted separately.
            $UniqueMoveVmCount = @($MoveInventory | Where-Object { $_.MoveIP } | Select-Object -ExpandProperty MoveIP -Unique).Count
            $UniquePlanCount = @($MoveInventory | Where-Object { $_.MovePlanId -and -not $_.IsDiscoveryRecord } | ForEach-Object { "$($_.MoveIP)|$($_.MovePlanId)" } | Select-Object -Unique).Count
            
            if ($FailedIPs.Count -gt 0) {
                Update-Task -TaskID $TaskID -Details "Inventory complete. $UniqueMoveVmCount Move VMs, $UniquePlanCount migration plans discovered. Failed: $($FailedIPs -join ', ')" -Status "Complete"
            }
            else {
                Update-Task -TaskID $TaskID -Details "Inventory complete. $UniqueMoveVmCount Move VMs, $UniquePlanCount migration plans discovered." -Status "Complete"
            }
            
            $SyncHash.Snackbar.MessageQueue.Enqueue("Inventory complete. $UniqueMoveVmCount Move VMs found and $UniquePlanCount migration plans discovered.")
        })

    #endregion Discover #############################################################################



    #region Tasks Drawer #############################################################################
 
    $SyncHash.ListViewTasks.Items.SortDescriptions.Add([System.ComponentModel.SortDescription]@{PropertyName = "StartTime"; Direction = "Descending" })
    $SyncHash.ListViewTasks.Add_SizeChanged({
            If ($this.Items.Count -ne 0) {
                If ($this.Items.Status -eq "Running" -or $this.Items.Status -eq "Waiting") {
                    $SyncHash.ProgressBar.Visibility = "Visible"
                }
                Else {
                    $SyncHash.ProgressBar.Visibility = "Hidden" 
                }
            }
        })

    #endregion Tasks #############################################################################
    

    
    # Get credentials prompt preference.
    $UseSavedCreds = Get-CredsPreference

    $SavedCredentialEndpoints = @{
        "Move" = "Move"
        "Prism Central" = "PrismCentral"
        "Prism Element" = "PrismElement"
        "vCenter" = "vCenter"
    }
    Foreach ($SavedCredentialEndpoint in $SavedCredentialEndpoints.GetEnumerator()) {
        $SavedCredentials = Get-SavedCredentials -EndPoint $SavedCredentialEndpoint.Key
        If ($SavedCredentials) {
            $SyncHashData."$($SavedCredentialEndpoint.Key -replace ' ', '')Creds" = $SavedCredentials
            $SyncHash."CheckBoxSave$($SavedCredentialEndpoint.Value)Creds".IsChecked = $true
        }
    }

    If ($UseSavedCreds -eq $true) {
        $SyncHash.CheckBoxUseSavedCredentials.IsChecked = $true
    }
    Else {
        $SyncHash.CheckBoxUseSavedCredentials.IsChecked = $false
    }

    # Setting the number of running tasks to 0.
    $SyncHashData.RunningTasks = 0

    Remove-UnusedRunspaces

    $SyncHash.MainWindow.ShowDialog() | Out-Null

} While ($Refresh.Reload -eq $true)

