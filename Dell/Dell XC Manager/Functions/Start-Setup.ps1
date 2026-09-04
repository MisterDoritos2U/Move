Function Start-Setup {

    $ScriptVersion = "2023.07.27.01"

    #Check for PowerShell version.
    $SyncHashData.PowerShellVersion = Get-Host | Select-Object -ExpandProperty Version

    If ($SyncHashData.PowerShellVersion.Major -le 5) {
        Write-Host "Please install PowerShell version 7 or higher and try again." -ForegroundColor Red
        Start-Sleep -Seconds 10
        Exit;
    }

    # Store reports and logs in the current user's home directory.
    $SyncHashData.RootDirectory = Join-Path $HOME "Logs"
    New-Item -ItemType Directory -Force -Path "$($SyncHashData.RootDirectory)\Data\Contacts" | Out-Null
    New-Item -ItemType Directory -Force -Path "$($SyncHashData.RootDirectory)\Backups" | Out-Null

    # Create registry entries
    $SyncHashData.RegistryPath = "HKCU:\SOFTWARE\DellXCManager"
    
    If (-Not(Test-Path -Path $SyncHashData.RegistryPath)) {
        New-Item -Path "HKCU:\SOFTWARE\" -Name "DellXCManager" | Out-Null

        # Create registry values with default data for first time launch.
        New-ItemProperty -Path $SyncHashData.RegistryPath -Value $false -Name "UseSavedCredentials" -PropertyType "String" | Out-Null
        New-ItemProperty -Path $SyncHashData.RegistryPath -Value $ScriptVersion -Name "Version" -PropertyType "String" | Out-Null
        New-ItemProperty -Path $SyncHashData.RegistryPath -Value "LightBlue" -Name "PrimaryColor" -PropertyType "String" | Out-Null
        New-ItemProperty -Path $SyncHashData.RegistryPath -Value "Lime" -Name "AccentColor" -PropertyType "String" | Out-Null
        New-ItemProperty -Path $SyncHashData.RegistryPath -Value "Dark" -Name "Theme" -PropertyType "String" | Out-Null
        New-ItemProperty -Path $SyncHashData.RegistryPath -Value ([int]$env:NUMBER_OF_PROCESSORS + 1) -Name "MaxTasks" -PropertyType "String" | Out-Null
        New-ItemProperty -Path $SyncHashData.RegistryPath -Value "True" -Name "SyncData" -PropertyType "String" | Out-Null
    }
    Else {
        Set-ItemProperty -Path $SyncHashData.RegistryPath -Value $ScriptVersion -Name "Version" | Out-Null
    }

    # Registry values
    $RegistryValues = "UseSavedCredentials", "Version", "PrimaryColor", "AccentColor", "Theme", "MaxTasks", "SyncData"
    
    # Create any missing values, such as new values during updates.
    Foreach ($RegistryValue in $RegistryValues) {
        If (-Not(Test-RegistryValue $SyncHashData.RegistryPath $RegistryValue)) {
            New-ItemProperty -Path $SyncHashData.RegistryPath -Value $null -Name $RegistryValue -PropertyType "String" | Out-Null
        }

    }


    # Set script shortcut icon.
    $IconLocation = "$($SyncHashData.ScriptPath)\Resources\Images\DellLogo.ico"
    $Shell = New-Object -ComObject ("WScript.Shell")
    $Shortcut = $Shell.CreateShortcut("$($SyncHashData.ScriptPath)\Nutanix Management Console.lnk")
    $Shortcut.IconLocation = $IconLocation
    $Shortcut.Save()

    # Attempt to find and import dependent modules.
    Confirm-Module -Name Microsoft.PowerShell.SecretManagement
    Confirm-Module -Name Microsoft.PowerShell.SecretStore
    Try {
        Initialize-SecretStore
    }
    Catch {
        Write-Host "SecretStore setup was skipped due to environment constraints. The Move app will continue without saved credentials." -ForegroundColor Yellow
    }


}
