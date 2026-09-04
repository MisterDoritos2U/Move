function New-MoveMigrationPlan {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$MoveVmIP,
        [Parameter(Mandatory = $true)][hashtable]$Header,
        [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$PlanName,
        [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$SourceProviderUuid,
        [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$TargetProviderUuid,
        [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$TargetClusterUuid,
        [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$TargetContainerUuid,
        [Parameter(Mandatory = $true)][array]$NetworkMappings,
        [Parameter(Mandatory = $true)][array]$VmEntries,
        [ValidateSet('auto', 'manual')][string]$GuestPrepMode = 'auto',
        [bool]$InstallNGT = $true,
        [bool]$UninstallGuestTools = $true,
        [ValidateSet('Low', 'Medium', 'High')][string]$VMPriority = 'Medium',
        [bool]$RetainMacAddress = $false,
        [bool]$SkipCdrom = $false,
        [bool]$EnableMemoryOvercommit = $false,
        [bool]$RetainUserData = $false,
        [bool]$AddCdrom = $false,
        [bool]$SkipIPRetention = $false,
        [ValidateSet('replicate', 'static')][string]$VMCustomizeType = 'static'
    )

    if (@($VmEntries).Count -eq 0) {
        throw 'At least one VM must be selected.'
    }

    if (@($NetworkMappings).Count -eq 0) {
        throw 'At least one network mapping is required.'
    }

    if ($AddCdrom -and $SkipCdrom) {
        throw 'AddCdrom and SkipCdrom cannot both be true.'
    }

    $vms = foreach ($vm in @($VmEntries)) {
        $uuid = $vm.UUID
        if (-not $uuid) { $uuid = $vm.Uuid }
        if (-not $uuid) { $uuid = $vm.vm_uuid }
        if (-not $uuid) { continue }

        $vmid = $vm.VMID
        if (-not $vmid) { $vmid = $vm.VmID }
        if (-not $vmid) { $vmid = $vm.Id }

        [ordered]@{
            AllowUVMOps                    = ($GuestPrepMode -eq 'auto')
            DiskConfig                     = [ordered]@{ AddCdrom = $AddCdrom }
            EnableMemoryOvercommit        = $EnableMemoryOvercommit
            GuestPrepMode                  = $GuestPrepMode
            InstallNGT                     = $InstallNGT
            PowerOffForpRDMtovRDMConversion = $true
            RetainMacAddress               = $RetainMacAddress
            RetainUserData                 = $RetainUserData
            SkipCdrom                      = $SkipCdrom
            SkipIPRetention                = $SkipIPRetention
            UninstallGuestTools             = $UninstallGuestTools
            VMCustomizeType                = $VMCustomizeType
            VMPriority                     = $VMPriority
            VMReference                    = [ordered]@{
                UUID = [string]$uuid
                VMID = if ($vmid) { [string]$vmid } else { [string]$uuid }
            }
        }
    }

    if (@($vms).Count -eq 0) {
        throw 'Selected workload records do not contain VM UUIDs.'
    }

    $payload = [ordered]@{
        IsUpdatePlanFlow = $false
        Spec = [ordered]@{
            Name = $PlanName
            NetworkMappings = @($NetworkMappings)
            SourceInfo = [ordered]@{
                ProviderUUID = $SourceProviderUuid
            }
            TargetInfo = [ordered]@{
                ProviderUUID = $TargetProviderUuid
                AOSProviderAttrs = [ordered]@{
                    ClusterUUID = $TargetClusterUuid
                    ContainerUUID = $TargetContainerUuid
                }
            }
            Workload = [ordered]@{
                Type = 'VM'
                VMs = @($vms)
            }
        }
    }

    if ($PSCmdlet.ShouldProcess("Move appliance $MoveVmIP", "Create migration plan '$PlanName' with $(@($vms).Count) VM(s)")) {
        return Invoke-MoveApi -Uri "https://$MoveVmIP/move/v2/plans" -Header $Header -Method POST -Body $payload
    }
}
