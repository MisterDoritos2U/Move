function  Get-PrimaryColor {

    $RegistryValueExists = Test-RegistryValue -Path $($SyncHashData.RegistryPath) -Value PrimaryColor

    If ($RegistryValueExists -eq $true) {
        $PrimaryColor = Get-ItemPropertyValue -Path $SyncHashData.RegistryPath -Name "PrimaryColor"
    }
    Else {
        $PrimaryColor = "#FF008FFF"
    }
    
    Return $PrimaryColor
}
