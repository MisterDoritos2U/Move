Function Initialize-SecretStore {
    try {
        $Vault = Get-SecretVault -Name SecretStore -ErrorAction SilentlyContinue

        if (-not $Vault) {
            $DefaultSecretStorePassword = ConvertTo-SecureString -String "DellXCManager!" -AsPlainText -Force
            Register-SecretVault -Name SecretStore -ModuleName Microsoft.PowerShell.SecretStore -DefaultVault -Password $DefaultSecretStorePassword -ErrorAction Stop
        }

        # Avoid an interactive SecretStore unlock prompt for credentials saved by
        # this application. If a user changed the vault password, leave the vault
        # untouched and Get-SavedCredentials will fail safely and fall back to the UI.
        if (Get-Command Unlock-SecretStore -ErrorAction SilentlyContinue) {
            $DefaultSecretStorePassword = ConvertTo-SecureString -String "DellXCManager!" -AsPlainText -Force
            try { Unlock-SecretStore -Password $DefaultSecretStorePassword -ErrorAction Stop | Out-Null } catch { }
        }
    }
    catch {
        Write-Host "SecretStore initialization was skipped because it is unavailable or locked in this environment. Continuing without persisted credentials." -ForegroundColor Yellow
    }
}
