function Import-MoveInventory {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$RootDirectory = (Join-Path $PWD 'Data\MoveVMs')
    )

    if (-not (Test-Path -Path $RootDirectory)) {
        return @()
    }

    $JsonFiles = Get-ChildItem -Path $RootDirectory -Filter '*.json' -File -ErrorAction SilentlyContinue
    $Inventory = @()

    foreach ($JsonFile in $JsonFiles) {
        try {
            $Content = Get-Content -Path $JsonFile.FullName -Raw -ErrorAction Stop | ConvertFrom-Json
            if ($null -ne $Content) {
                $Inventory += @($Content)
            }
        }
        catch {
            continue
        }
    }

    return @($Inventory)
}
