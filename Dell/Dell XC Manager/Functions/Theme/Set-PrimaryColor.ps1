Function Set-PrimaryColor ($Color) {

    # Update registry with primary color.
    Set-ItemProperty -Path $SyncHashData.RegistryPath -Value $Color -Name PrimaryColor | Out-Null

    # Update toggles.
    $Toggles = ($SyncHash.GetEnumerator() | Where-Object { $_.Key -match "Toggle" }).Value
    $Toggles | Foreach-Object { $_.Background = $Color }

    # Update checkboxes,
    $CheckBoxes = ($SyncHash.GetEnumerator() | Where-Object { $_.Key -match "CheckBox" }).Value
    $CheckBoxes | Foreach-Object { $_.Background = $Color }

    # Update icons.
    $Icons = ($SyncHash.GetEnumerator() | Where-Object { $_.Key -match "Icon" }).Value
    $Icons | Foreach-Object { $_.Foreground = $Color }

    if ($null -ne $SyncHash.ThemeToggleButton) { $SyncHash.ThemeToggleButton.Background = $Color }
    if ($null -ne $SyncHash.ButtonInventoryPCList) { $SyncHash.ButtonInventoryPCList.Background = $Color; $SyncHash.ButtonInventoryPCList.BorderBrush = $Color }
    if ($null -ne $SyncHash.ButtonInventoryPEList) { $SyncHash.ButtonInventoryPEList.Background = $Color; $SyncHash.ButtonInventoryPEList.BorderBrush = $Color }
    if ($null -ne $SyncHash.TextBoxPrismCentral) { $SyncHash.TextBoxPrismCentral.BorderBrush = $Color }
    if ($null -ne $SyncHash.TextBoxPrismElement) { $SyncHash.TextBoxPrismElement.BorderBrush = $Color }
    if ($null -ne $SyncHash.PCPopupBox) { $SyncHash.PCPopupBox.Background = $Color; $SyncHash.PCPopupBox.BorderBrush = $Color }
    if ($null -ne $SyncHash.PEPopupBox) { $SyncHash.PEPopupBox.Background = $Color; $SyncHash.PEPopupBox.BorderBrush = $Color }

    if ($null -ne $SyncHash.ListBoxPrismElement -and $null -ne $SyncHash.ListBoxPrismElement.Items) {
        Foreach ($Item in $SyncHash.ListBoxPrismElement.Items) {
            If (($SyncHash.TreeView.Items.Tag -contains $Item.Content) -and ($Item.IsSelected -eq $false)) {
                $Item.Background = $Color
                $Item.Background.Opacity = .1
            }
            Else {
                If (($Item.IsSelected -eq $false) -and ($SyncHash.TreeView.Items.Tag -notcontains $Item.Content)) {
                    $Item.Background = "#00FFFFFF"
                    $Item.Background.Opacity = 1
                }
            }
        }
    }
    
}