Function Set-CredsPreference ($Bool) {

    If ($Bool -eq $true) {
        Set-ItemProperty -Path $SyncHashData.RegistryPath -Value $true -Name UseSavedCredentials | Out-Null
    }
    Else {
        Set-ItemProperty -Path $SyncHashData.RegistryPath -Value $false -Name UseSavedCredentials | Out-Null
    }

}