Function Get-CredsPreference {

    If (Test-Path $SyncHashData.RegistryPath) {
        Try {
            $UseSavedCreds = Get-ItemPropertyValue -Path $SyncHashData.RegistryPath -Name UseSavedCredentials
        }
        Catch {
            $UseSavedCreds = $false
        }
    }

    Return $UseSavedCreds

}