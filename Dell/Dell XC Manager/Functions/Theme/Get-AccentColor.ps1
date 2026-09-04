function  Get-AccentColor {

    $RegistryValueExists = Test-RegistryValue -Path $($SyncHashData.RegistryPath) -Value AccentColor

    If ($RegistryValueExists -eq $true) {
        $AccentColor = Get-ItemPropertyValue -Path $SyncHashData.RegistryPath -Name "AccentColor"
    }
    Else {
        $AccentColor = "#FF008FFF"
    }

    Return $AccentColor
}