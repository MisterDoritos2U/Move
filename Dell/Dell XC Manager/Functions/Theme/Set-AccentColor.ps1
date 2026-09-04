Function Set-AccentColor ($Color) {

    # Update registry with accent color.
    Set-ItemProperty -Path $SyncHashData.RegistryPath -Value $Color -Name AccentColor | Out-Null

    Foreach ($Item in $SyncHash.ListBoxPrismElement.Items) {

        If ($Item.IsSelected -eq $true) {
            $AccentColor = Get-AccentColor
            $Item.Background = $AccentColor
            $Item.Background.Opacity = 1
        }
        
    }

}