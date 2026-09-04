Function Test-RegistryValue {

    Param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        $Path,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        $Value
    )

    Try {
        Get-ItemProperty -Path $Path | Select-Object -ExpandProperty $Value -ErrorAction Stop | Out-Null
        Return $true
    }
    Catch {
        Return $false
    }

}
