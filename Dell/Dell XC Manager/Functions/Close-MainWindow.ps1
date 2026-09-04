Function Close-MainWindow {
    Try {
        if ($SyncHashData.DebugEnabled) {
            try { Stop-Transcript | Out-Null } catch { }
            $SyncHashData.DebugEnabled = $false
        }

        #Cleanup runspaces, including the one created by the remove-unusedrunspaces function.
        $SyncHashData.Close = $true

        Get-Runspace | Foreach-Object { 
            
            If ($SyncHashData.RunspaceInstances.Guid -contains $_.InstanceId) {
                $_.Close() | Out-Null    
                $_.Dispose() | Out-Null
            }
        }
        

        # Save the Move VM discovery list used by the Move-only flow.
        if ($null -ne $SyncHash.ListBoxPrismCentral -and $null -ne $SyncHash.ListBoxPrismCentral.Items) {
            $SyncHash.ListBoxPrismCentral.Items | Out-File -FilePath "$($SyncHashData.RootDirectory)\Data\MoveVMs.txt" -Force
        }

        # Preserve legacy list files when present.
        if ($null -ne $SyncHash.ListBoxPrismElement -and $null -ne $SyncHash.ListBoxPrismElement.Items) {
            $SyncHash.ListBoxPrismElement.Items.Content | Out-File -FilePath "$($SyncHashData.RootDirectory)\Data\PrismElementList.txt" -Force
        }

        # Save copies out to server.
        If ($SyncHashData.SyncData -eq $true) {
            If (Test-Path "$($SyncHashData.RootDirectory)\Data") {
                if ($null -ne $SyncHash.ListBoxPrismElement -and $null -ne $SyncHash.ListBoxPrismElement.Items) {
                    $SyncHash.ListBoxPrismElement.Items.Content | Out-File -FilePath "$($SyncHashData.RootDirectory)\Data\PrismElementList.txt" -Force
                }
                if ($null -ne $SyncHash.ListBoxPrismCentral -and $null -ne $SyncHash.ListBoxPrismCentral.Items) {
                    $SyncHash.ListBoxPrismCentral.Items | Out-File -FilePath "$($SyncHashData.RootDirectory)\Data\MoveVMs.txt" -Force
                }
            }
        }

        # Save the max tasks preference.
        Set-ItemProperty -Path $SyncHashData.RegistryPath -Value $SyncHashData.MaxTasks -Name "MaxTasks" | Out-Null

        # Set stored credentials to null and call garbage collector.
        $CredVariables = Get-Variable -name *Cred*
        Foreach ($CredVariable in $CredVariables) {
            Set-Variable -Name $CredVariable.Name -Value $null -Force
            Remove-Variable -Name $CredVariable.Name -Force
        }
        $SyncHashData["MoveCreds"] = $null
        $SyncHashData["ServiceAccountCreds"] = $null
        $SyncHashData["PrismCentralCreds"] = $null
        $SyncHashData["PrismElementCreds"] = $null
        $SyncHashData["vCenterCreds"] = $null
        $CredVariables = $null
        [System.GC]::Collect()

    }
    Catch { 
        Out-Null
    }
}