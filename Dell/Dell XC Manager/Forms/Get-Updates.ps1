[void][reflection.assembly]::Load('System.Windows.Forms, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089')
[void][reflection.assembly]::Load('System.Drawing, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b03f5f7f11d50a3a')
[System.Windows.Forms.Application]::EnableVisualStyles()

# Registry path.
$RegistryPath = "HKCU:\SOFTWARE\DellXCManager"
$NutanixManagerLocation = Split-Path $PSScriptRoot
$RootDirectory = "$($env:APPDATA)\Dell XC Manager"
$UpdateSource = "\\al001mgmgt01.us.chs.net\Software\Dell\Dell XC Manager"

If (Test-Path -Path $RegistryPath) {

    $ReleaseNotesPath = Join-Path $UpdateSource 'Forms\ReleaseNotes.txt'
    $SetupPath = Join-Path $UpdateSource 'Functions\Start-Setup.ps1'
    If (-not (Test-Path -LiteralPath $ReleaseNotesPath) -or -not (Test-Path -LiteralPath $SetupPath)) {
        Write-Verbose "Update source is unavailable. Skipping update check."
        return
    }

    # Import release notes.
    $ReleaseNotes = Get-Content -LiteralPath $ReleaseNotesPath -ErrorAction Stop
    $FormattedReleaseNotes = ($ReleaseNotes | ForEach-Object { "`n$($_)" }) -join ''


    # Get current Nutanix Manager version and look for updates.
    Try {
        $InstalledVersion = Get-ItemPropertyValue -Path $RegistryPath -Name Version
    }
    Catch [System.Management.Automation.PSArgumentException] {
        $InstalledVersion = "0.0.0.0"
    }

    $AvailableVersion = Get-Content -LiteralPath $SetupPath -ErrorAction Stop |
        Where-Object { $_ -match '^\s*\$ScriptVersion\s*=' } |
        Select-Object -First 1
    $AvailableVersion = (($AvailableVersion -replace '^.*?=\s*', '') -replace '["'']', '').Trim()
    If ([string]::IsNullOrWhiteSpace($AvailableVersion)) {
        Write-Verbose "Update source did not provide a valid version. Skipping update check."
        return
    }

    If ($InstalledVersion -lt $AvailableVersion) {
        $Message = "A newer version of Nutanix Manager is available, version $($AvailableVersion). 
        
$($FormattedReleaseNotes)

Do you want to update?"

        $Update = [System.Windows.Forms.MessageBox]::Show($Message, "Update Available", "YesNo" , "Question")
    }

    If ($Update -eq "Yes") {

        Write-Host "INFO: Please wait while we process updates..."

        # Save backup copy of previous version.
        If (!(Test-Path "$($RootDirectory)\Backups\$($InstalledVersion)")) {
            Write-Host "INFO: Creating backups of old version..."
            New-Item -ItemType Directory -Force -Path "$($RootDirectory)\Backups\$($InstalledVersion)" | Out-Null        
        }
        Copy-Item -Path "$($NutanixManagerLocation)\*" -Destination "$($RootDirectory)\Backups\$($InstalledVersion)" -Recurse -Force
        
        # Keep backups of the last 5 versions and discard the rest.
        $LastFiveVersions = Get-ChildItem -Path "$($RootDirectory)\Backups" | Sort-Object -Descending | Select-Object -First 5 | Select-Object FullName
        $Cleanup = Get-ChildItem -Path "$($RootDirectory)\Backups" | 
        Where-Object { $LastFiveVersions.FullName -notcontains $_.FullName } | 
        Sort-Object -Descending | Select-Object FullName 
        If ($Cleanup) {          
            Remove-Item -Path $Cleanup.FullName -Recurse -Force
        }

        # Copy newer files from the server.
        Copy-Item -Path "$UpdateSource\*" -Destination $NutanixManagerLocation -Recurse -Force

        If ($InstalledVersion -eq "0.0.0.0") {
            New-ItemProperty -Path $RegistryPath -Value $AvailableVersion -Name "Version" -PropertyType "String" | Out-Null
        }
        Else {
            # Update version registered in the registry.
            Set-ItemProperty -Path $RegistryPath -Value $AvailableVersion -Name "Version" | Out-Null
        }

        New-ItemProperty -Path $RegistryPath -Value $true -Name "CopyGetUpdate" -PropertyType "String" | Out-Null

        Write-Host "INFO: Updates complete!"
    }

}