function Get-MoveVmInventory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$MoveVmIP,

        [Parameter(Mandatory = $true)]
        [hashtable]$Header,

        [Parameter()]
        [string]$RootDirectory = (Join-Path $PWD 'Data\MoveVMs')
    )

    $DebugLog = Join-Path $HOME 'Logs\Data\Move_Debug.log'
    $DebugDir = Split-Path $DebugLog
    if (-not (Test-Path $DebugDir)) {
        New-Item -ItemType Directory -Force -Path $DebugDir | Out-Null
    }

    Add-Content -Path $DebugLog -Value "`n=== Get-MoveVmInventory called for $MoveVmIP at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ===" -Force

    function Get-PropertyValue {
        param(
            [Parameter()][object]$Object,
            [Parameter()][string[]]$PropertyNames = @()
        )

        if ($null -eq $Object) {
            return $null
        }

        foreach ($PropertyName in $PropertyNames) {
            if ($Object.PSObject.Properties.Name -contains $PropertyName) {
                return $Object.$PropertyName
            }
        }

        foreach ($Property in $Object.PSObject.Properties) {
            $NestedValue = $Property.Value
            if ($null -eq $NestedValue) {
                continue
            }

            if ($NestedValue -is [string]) {
                continue
            }

            if ($NestedValue -is [System.Collections.IDictionary] -or $NestedValue -is [System.Collections.IEnumerable]) {
                foreach ($Child in @($NestedValue)) {
                    $Result = Get-PropertyValue -Object $Child -PropertyNames $PropertyNames
                    if ($null -ne $Result) {
                        return $Result
                    }
                }
            }
            elseif ($NestedValue -is [pscustomobject] -or $NestedValue -is [System.Management.Automation.PSObject]) {
                $Result = Get-PropertyValue -Object $NestedValue -PropertyNames $PropertyNames
                if ($null -ne $Result) {
                    return $Result
                }
            }
        }

        return $null
    }

    function Get-MoveVmEntries {
        param(
            [Parameter()][object]$MovePlan
        )

        if ($null -eq $MovePlan) {
            return @()
        }

        $CandidateNames = @('vms', 'virtual_machines', 'move_vms', 'entities', 'items', 'results', 'data', 'value', 'vm_list', 'migration_entities', 'machines', 'vm_entities', 'virtualMachines', 'migrationVms', 'virtual_machines_list', 'vmEntries')
        foreach ($PropertyName in $CandidateNames) {
            if ($MovePlan.PSObject.Properties.Name -contains $PropertyName) {
                $Value = $MovePlan.$PropertyName
                if ($null -ne $Value) {
                    $Entries = @($Value)
                    if ($Entries.Count -gt 0) {
                        return @($Entries)
                    }
                }
            }
        }

        foreach ($Property in $MovePlan.PSObject.Properties) {
            $Value = $Property.Value
            if ($null -eq $Value -or $Value -is [string]) {
                continue
            }

            if ($Value -is [System.Collections.IDictionary] -or $Value -is [System.Collections.IEnumerable]) {
                $Entries = @($Value)
                foreach ($Entry in $Entries) {
                    if ($null -eq $Entry) { continue }
                    if ($Entry -is [string]) { continue }
                    $HasVmIdentity = $false
                    foreach ($Candidate in @('vm_uuid', 'vmUuid', 'uuid', 'id', 'entity_uuid', 'entityUuid', 'vm_name', 'vmName', 'name', 'display_name', 'displayName')) {
                        if ($Entry.PSObject.Properties.Name -contains $Candidate) {
                            $HasVmIdentity = $true
                            break
                        }
                    }
                    if ($HasVmIdentity) {
                        return @($Entries)
                    }
                }
            }
        }

        return @()
    }

    $MoveInventory = @()
    $MovePlans = @(Get-MovePlanInventory -MoveVmIP $MoveVmIP -Header $Header)

    Add-Content -Path $DebugLog -Value "Got $($MovePlans.Count) plans from Move API"

    # If endpoint was queried but returned no plans, still create a discovery record
    $EndpointDiscoveryRecord = [pscustomobject]@{
        MoveIP                      = $MoveVmIP
        MovePlanName               = "[Endpoint Discovered]"
        MovePlanId                 = "discovery-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        MovePlanStatus             = "No plans found"
        MovePlanSourceCluster      = ""
        MovePlanDestinationCluster = ""
        VmName                     = ""
        VmUuid                     = ""
        VmState                    = ""
        VmSource                   = ""
        VmDestination              = ""
        VmConfigJson               = ""
        VmConfig                   = $null
        IsDiscoveryRecord          = $true
    }

    foreach ($MovePlan in $MovePlans) {
        if ($null -eq $MovePlan) {
            Add-Content -Path $DebugLog -Value "  Plan is null, skipping"
            continue
        }

        Add-Content -Path $DebugLog -Value "Processing plan: $($MovePlan | ConvertTo-Json -Depth 2 -Compress | Select-Object -First 300)"

        # Handle Move V2 API response where plans are in MetaData
        $PlanData = if ($MovePlan.PSObject.Properties.Name -contains 'MetaData') { $MovePlan.MetaData } else { $MovePlan }

        $PlanId = Get-PropertyValue -Object $PlanData -PropertyNames @('UUID', 'uuid', 'id', 'plan_uuid', 'planId', 'plan_id', 'planUuid', 'migration_plan_uuid')
        if (-not $PlanId) {
            $PlanId = Get-PropertyValue -Object $PlanData -PropertyNames @('Name', 'name', 'plan_name')
        }
        if (-not $PlanId) {
            Add-Content -Path $DebugLog -Value "  No plan ID found, skipping plan"
            continue
        }

        Add-Content -Path $DebugLog -Value "  Plan ID: $PlanId"

        $PlanUri = "https://$MoveVmIP/move/v2/plans/$PlanId"
        $MovePlanDetails = $null

        try {
            $MovePlanDetails = Invoke-MoveApi -Uri $PlanUri -Header $Header -Method GET
        }
        catch {
            Add-Content -Path $DebugLog -Value "  Failed to fetch plan details: $($_.Exception.Message)"
            $MovePlanDetails = $PlanData
        }

        if ($null -eq $MovePlanDetails) {
            $MovePlanDetails = $PlanData
        }

        $PlanName = Get-PropertyValue -Object $MovePlanDetails -PropertyNames @('Name', 'name', 'plan_name', 'planName')
        if (-not $PlanName) {
            $PlanName = Get-PropertyValue -Object $PlanData -PropertyNames @('Name', 'name', 'plan_name', 'planName')
        }

        Add-Content -Path $DebugLog -Value "  Plan Name: $PlanName"

        $PlanStatus = Get-PropertyValue -Object $MovePlanDetails -PropertyNames @('status', 'state', 'migration_state')
        $SourceCluster = Get-PropertyValue -Object $MovePlanDetails -PropertyNames @('source_cluster', 'sourceCluster', 'source_cluster_name', 'sourceClusterName')
        $DestinationCluster = Get-PropertyValue -Object $MovePlanDetails -PropertyNames @('destination_cluster', 'destinationCluster', 'target_cluster', 'targetCluster', 'destination_cluster_name')

        $VmEntries = @(Get-MoveVmEntries -MovePlan $MovePlanDetails)
        if ($VmEntries.Count -eq 0) {
            $VmEntries = @(Get-MoveVmEntries -MovePlan $MovePlan)
        }

        Add-Content -Path $DebugLog -Value "  Found $($VmEntries.Count) VM entries in plan"

        foreach ($VmEntry in $VmEntries) {
            if ($null -eq $VmEntry) {
                Add-Content -Path $DebugLog -Value "    VM entry is null, skipping"
                continue
            }

            $VmName = Get-PropertyValue -Object $VmEntry -PropertyNames @('name', 'vm_name', 'vmName', 'display_name', 'displayName', 'entity_name', 'entityName')
            $VmUuid = Get-PropertyValue -Object $VmEntry -PropertyNames @('uuid', 'vm_uuid', 'vmUuid', 'id', 'entity_uuid', 'entityUuid')
            $VmState = Get-PropertyValue -Object $VmEntry -PropertyNames @('power_state', 'powerState', 'state', 'status')
            $VmSource = Get-PropertyValue -Object $VmEntry -PropertyNames @('source_vm', 'sourceVm', 'source_vm_name', 'sourceVmName')
            $VmDestination = Get-PropertyValue -Object $VmEntry -PropertyNames @('destination_vm', 'destinationVm', 'target_vm', 'targetVm')

            Add-Content -Path $DebugLog -Value "    VM Entry properties: $(($VmEntry.PSObject.Properties.Name -join ', '))"
            Add-Content -Path $DebugLog -Value "    VM Name: $VmName, UUID: $VmUuid"

            if (-not $VmUuid -and -not $VmName) {
                Add-Content -Path $DebugLog -Value "    No VM identity found at top level, checking nested objects"
                $NestedVmEntry = $null
                foreach ($Property in $VmEntry.PSObject.Properties) {
                    $Nested = $Property.Value
                    if ($null -eq $Nested -or $Nested -is [string]) { continue }
                    if ($Nested -is [System.Collections.IEnumerable] -and -not ($Nested -is [string])) {
                        foreach ($Candidate in @($Nested)) {
                            if ($null -ne $Candidate -and $Candidate.PSObject.Properties.Name -contains 'vm_uuid') {
                                $NestedVmEntry = $Candidate
                                Add-Content -Path $DebugLog -Value "    Found nested VM at property: $($Property.Name)"
                                break
                            }
                        }
                    }
                    if ($null -ne $NestedVmEntry) { break }
                }
                if ($null -ne $NestedVmEntry) {
                    $VmName = Get-PropertyValue -Object $NestedVmEntry -PropertyNames @('name', 'vm_name', 'vmName', 'display_name', 'displayName', 'entity_name', 'entityName')
                    $VmUuid = Get-PropertyValue -Object $NestedVmEntry -PropertyNames @('uuid', 'vm_uuid', 'vmUuid', 'id', 'entity_uuid', 'entityUuid')
                    $VmState = Get-PropertyValue -Object $NestedVmEntry -PropertyNames @('power_state', 'powerState', 'state', 'status')
                    $VmSource = Get-PropertyValue -Object $NestedVmEntry -PropertyNames @('source_vm', 'sourceVm', 'source_vm_name', 'sourceVmName')
                    $VmDestination = Get-PropertyValue -Object $NestedVmEntry -PropertyNames @('destination_vm', 'destinationVm', 'target_vm', 'targetVm')
                    Add-Content -Path $DebugLog -Value "    Nested VM Name: $VmName, UUID: $VmUuid"
                }
            }

            if (-not $VmUuid -and -not $VmName) {
                Add-Content -Path $DebugLog -Value "    Rejecting VM: no identity found"
                continue
            }

            Add-Content -Path $DebugLog -Value "    Accepting VM: $VmName ($VmUuid)"

            $MoveInventory += [pscustomobject]@{
                MoveIP                      = $MoveVmIP
                MovePlanName               = $PlanName
                MovePlanId                 = $PlanId
                MovePlanStatus             = $PlanStatus
                MovePlanSourceCluster      = $SourceCluster
                MovePlanDestinationCluster = $DestinationCluster
                VmName                     = $VmName
                VmUuid                     = $VmUuid
                VmState                    = $VmState
                VmSource                   = $VmSource
                VmDestination              = $VmDestination
                VmConfigJson               = ($VmEntry | ConvertTo-Json -Depth 100 -Compress)
                VmConfig                   = $VmEntry
            }
        }
    }

    Add-Content -Path $DebugLog -Value "Total VMs collected: $($MoveInventory.Count)"
    Add-Content -Path $DebugLog -Value "MoveVmIP parameter value was: [$MoveVmIP]"

    # If we found plans but no VMs, add the discovery record to show the endpoint was reached
    if ($MovePlans.Count -gt 0 -and $MoveInventory.Count -eq 0) {
        Add-Content -Path $DebugLog -Value "Plans found but no VMs. Adding discovery record for endpoint."
        $MoveInventory += $EndpointDiscoveryRecord
    }
    # If no plans were found at all, still add a discovery record to cache the endpoint
    elseif ($MovePlans.Count -eq 0 -and $MoveInventory.Count -eq 0) {
        Add-Content -Path $DebugLog -Value "No plans found. Adding discovery record for endpoint."
        $MoveInventory += $EndpointDiscoveryRecord
    }

    $MoveInventoryRoot = $RootDirectory
    if (-not (Test-Path -Path $MoveInventoryRoot)) {
        New-Item -ItemType Directory -Force -Path $MoveInventoryRoot | Out-Null
    }

    $JsonPath = Join-Path $MoveInventoryRoot "MoveVms-$MoveVmIP.json"
    $CsvPath = Join-Path $MoveInventoryRoot "MoveVms-$MoveVmIP.csv"

    if ($MoveInventory.Count -gt 0) {
        Add-Content -Path $DebugLog -Value "Saving $($MoveInventory.Count) inventory records (including discovery records) to JSON and CSV"
        $MoveInventory | ConvertTo-Json -Depth 100 | Set-Content -Path $JsonPath -Encoding UTF8
        # For CSV, filter out discovery records (they have no VM UUID)
        $MoveInventory | Where-Object { $_.VmUuid -or $_.IsDiscoveryRecord } | Select-Object MoveIP, MovePlanName, MovePlanId, MovePlanStatus, MovePlanSourceCluster, MovePlanDestinationCluster, VmName, VmUuid, VmState, VmSource, VmDestination, VmConfigJson | Export-Csv -Path $CsvPath -NoTypeInformation -Force -Encoding UTF8
    }
    else {
        @() | ConvertTo-Json -Depth 100 | Set-Content -Path $JsonPath -Encoding UTF8
        @() | Export-Csv -Path $CsvPath -NoTypeInformation -Force -Encoding UTF8
    }

    return @($MoveInventory)
}
