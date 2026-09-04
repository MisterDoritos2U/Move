Function Import-SavedLists {
    if ($null -eq $SyncHash -or $null -eq $SyncHash.ListBoxPrismCentral) {
        return
    }

    $SyncHash.ListBoxPrismCentral.Items.Clear()

    $SavedMoveListPath = Join-Path $SyncHashData.RootDirectory 'Data\MoveVMs.txt'
    if (Test-Path $SavedMoveListPath) {
        $SavedMoveIPs = @(Get-Content -Path $SavedMoveListPath -ErrorAction SilentlyContinue)
        foreach ($SavedMoveIP in $SavedMoveIPs) {
            if (-not $SavedMoveIP) { continue }
            $Validated = Confirm-ValidIP (Format-IPList $SavedMoveIP)
            if ($Validated) {
                $SyncHash.ListBoxPrismCentral.Items.Add([string]$Validated) | Out-Null
            }
        }
    }

    $InventoryRoot = Join-Path $SyncHashData.RootDirectory 'Data\MoveVMs'
    if (Test-Path $InventoryRoot) {
        foreach ($JsonFile in Get-ChildItem -Path $InventoryRoot -Filter 'MoveVms-*.json' -File -ErrorAction SilentlyContinue) {
            $Ip = $JsonFile.BaseName -replace '^MoveVms-', ''
            if ($Ip) {
                $Existing = @($SyncHash.ListBoxPrismCentral.Items | Where-Object { [string]$_ -eq [string]$Ip })
                if ($Existing.Count -eq 0) {
                    $SyncHash.ListBoxPrismCentral.Items.Add([string]$Ip) | Out-Null
                }
            }
        }
    }
}
