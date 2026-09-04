function Get-MovePlanInventory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$MoveVmIP,

        [Parameter(Mandatory = $true)]
        [hashtable]$Header
    )

    $DebugLog = Join-Path $HOME 'Logs\Data\Move_Debug.log'
    $DebugDir = Split-Path $DebugLog -Parent
    if (-not (Test-Path -LiteralPath $DebugDir)) {
        New-Item -ItemType Directory -Force -Path $DebugDir | Out-Null
    }

    Add-Content -Path $DebugLog -Value "=== Get-MovePlanInventory called for $MoveVmIP at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ===" -Force

    function ConvertTo-MovePlanCollection {
        param([object]$Value)

        if ($null -eq $Value -or $Value -is [string]) {
            return @()
        }

        if ($Value.PSObject.Properties.Name -contains 'Entities') {
            return @($Value.Entities)
        }

        if ($Value -is [System.Collections.IEnumerable] -and
            -not ($Value -is [System.Collections.IDictionary])) {
            return @($Value)
        }

        return @()
    }

    # Source: Nutanix Move V2 "List All Plans" documentation.
    # POST https://{move_ip}/move/v2/plans/list
    # Content-Type: application/json
    # Accept: application/json
    # Authorization: {{Authorization-Token}}
    # Request payload: No Payload
    $Uri = "https://$MoveVmIP/move/v2/plans/list"

    try {
        Add-Content -Path $DebugLog -Value "Request: POST $Uri (no payload)"
        $Response = Invoke-MoveApi -Uri $Uri -Header $Header -Method POST

        $Plans = @(ConvertTo-MovePlanCollection -Value $Response)
        Add-Content -Path $DebugLog -Value "Successful response. Migration plan count: $($Plans.Count)"

        return $Plans
    }
    catch {
        $message = $_.Exception.Message
        Add-Content -Path $DebugLog -Value "Move plan request failed: $message"
        throw "Unable to query migration plans from Move appliance $MoveVmIP. $message"
    }
}
