Function Get-SelectedInfo {

   

    $SelectedItem = $SyncHash.TreeView.SelectedItem
    if ($null -eq $SelectedItem) {
        return
    }

    $SelectedParent = $SelectedItem.Parent
    if ($SelectedParent -and $SelectedParent.Header) {
        $SelectedParentHeader = $SelectedParent.Header
    }
    else {
        $SelectedParentHeader = $null
    }

    $ItemHeader = $SelectedItem.Header
    $ItemTag = $SelectedItem.Tag

    if (($null -ne $ItemTag -and ($ItemTag -like "MoveEndpoint:*" -or $ItemTag -like "MovePlan:*" -or $ItemTag -like "MoveVm:*"))) {
        $SyncHash.MenuIsm.Visibility = "Hidden"
        $SyncHash.MenuPtAgent.Visibility = "Hidden"
        $SyncHash.MenuNX.Visibility = "Hidden"
        $SyncHash.MenuPuttyHost.Visibility = "Hidden"
        $SyncHash.MenuPuttyCvm.Visibility = "Hidden"
        $SyncHash.MenuPuttyNX.Visibility = "Hidden"
        $SyncHash.MenuBrowserHost.Visibility = "Hidden"
        $SyncHash.MenuBrowserCvm.Visibility = "Hidden"
        $SyncHash.MenuBrowserNX.Visibility = "Hidden"
        $SyncHash.MenuPingHost.Visibility = "Hidden"
        $SyncHash.MenuPingCvm.Visibility = "Hidden"
        $SyncHash.MenuPingNX.Visibility = "Hidden"

        $SyncHash.TextBoxHostName.Text = $null
        if ($SyncHash.TextBoxMoveVmJson) { $SyncHash.TextBoxMoveVmJson.Text = "Move VM JSON:" }

        $MoveInventoryRoot = Join-Path $SyncHashData.RootDirectory "Data\MoveVMs"
        $MoveEntries = @(Import-MoveInventory -RootDirectory $MoveInventoryRoot)

        $SelectionType = 'Endpoint'
        $EndpointIP = $null
        $PlanId = $null
        $VmUuid = $null

        if ($ItemTag -like "MoveVm:*") {
            $SelectionType = 'Vm'
            $parts = $ItemTag.Substring(7) -split '\|', 3
            if ($parts.Count -ge 3) { $EndpointIP=$parts[0]; $PlanId=$parts[1]; $VmUuid=$parts[2] }
        }
        elseif ($ItemTag -like "MovePlan:*") {
            $SelectionType = 'Plan'
            $parts = $ItemTag.Substring(9) -split '\|', 2
            if ($parts.Count -ge 2) { $EndpointIP=$parts[0]; $PlanId=$parts[1] }
        }
        elseif ($ItemTag -like "MoveEndpoint:*") {
            $SelectionType = 'Endpoint'
            $EndpointIP = $ItemTag.Substring(13)
        }

        $SelectedMoveEntry = $null
        if ($SelectionType -eq 'Vm') {
            $SelectedMoveEntry = $MoveEntries | Where-Object { [string]$_.MoveIP -eq $EndpointIP -and [string]$_.MovePlanId -eq $PlanId -and [string]$_.VmUuid -eq $VmUuid } | Select-Object -First 1
        }
        elseif ($SelectionType -eq 'Plan') {
            $SelectedMoveEntry = $MoveEntries | Where-Object { [string]$_.MoveIP -eq $EndpointIP -and [string]$_.MovePlanId -eq $PlanId -and -not $_.IsDiscoveryRecord } | Select-Object -First 1
        }
        else {
            $SelectedMoveEntry = $MoveEntries | Where-Object { [string]$_.MoveIP -eq $EndpointIP -and -not $_.IsDiscoveryRecord } | Select-Object -First 1
        }

        if ($SelectionType -eq 'Endpoint') {
            $EndpointEntries = @($MoveEntries | Where-Object { [string]$_.MoveIP -eq $EndpointIP -and -not $_.IsDiscoveryRecord })
            $PlanCount = @($EndpointEntries | Where-Object { $_.MovePlanId } | Select-Object -ExpandProperty MovePlanId -Unique).Count
            $VmCount = @($EndpointEntries | Where-Object { $_.VmUuid } | Select-Object -ExpandProperty VmUuid -Unique).Count

            $SyncHash.TextBoxHostName.Text = $EndpointIP
            $SyncHash.TextBoxNotes.Text = "Move endpoint $EndpointIP contains $PlanCount migration plan(s) and $VmCount VM record(s)."
            if ($SyncHash.TextBoxMoveVmJson) { $SyncHash.TextBoxMoveVmJson.Text = ($EndpointEntries | ConvertTo-Json -Depth 100) }
            return
        }

        if ($SelectedMoveEntry) {
            $PlanEntries = @($MoveEntries | Where-Object { [string]$_.MoveIP -eq $EndpointIP -and [string]$_.MovePlanId -eq $PlanId -and -not $_.IsDiscoveryRecord })
            $PlanVmCount = @($PlanEntries | Where-Object { $_.VmUuid } | Select-Object -ExpandProperty VmUuid -Unique).Count

            if ($SelectionType -eq 'Plan') {
                $SyncHash.TextBoxHostName.Text = [string]$SelectedMoveEntry.MovePlanName
                $SyncHash.TextBoxNotes.Text = ($PlanEntries | ConvertTo-Json -Depth 100)
                if ($SyncHash.TextBoxMoveVmJson) { $SyncHash.TextBoxMoveVmJson.Text = ($PlanEntries | ConvertTo-Json -Depth 100) }
            }
            else {
                $SyncHash.TextBoxHostName.Text = [string]$SelectedMoveEntry.VmName
                $NtpServer = if ($SelectedMoveEntry.NtpServer) { $SelectedMoveEntry.NtpServer } else { 'Not available' }
                $SnapshotConfiguration = if ($SelectedMoveEntry.SnapshotConfiguration) { $SelectedMoveEntry.SnapshotConfiguration } else { 'Not available' }
                $VddkUpload = if ($SelectedMoveEntry.VddkUpload) { $SelectedMoveEntry.VddkUpload } else { 'Not available' }
                $MoveVersion = if ($SelectedMoveEntry.MoveVersion) { $SelectedMoveEntry.MoveVersion } else { 'Not available' }
                $SyncHash.MoveNtpServer.Text = "NTP Server: $NtpServer"
                $SyncHash.MoveSnapshotConfiguration.Text = "Snapshot Configuration: $SnapshotConfiguration"
                $SyncHash.MoveVddkUpload.Text = "VDDK Upload: $VddkUpload"
                $SyncHash.MoveVersion.Text = "Move Version: $MoveVersion"
                try { $json = $SelectedMoveEntry.VmConfigJson | ConvertFrom-Json | ConvertTo-Json -Depth 100 } catch { $json = [string]$SelectedMoveEntry.VmConfigJson }
                $SyncHash.TextBoxNotes.Text = $json
                if ($SyncHash.TextBoxMoveVmJson) { $SyncHash.TextBoxMoveVmJson.Text = $json }
            }
        }
        else {
            $SyncHash.TextBoxHostName.Text = $ItemHeader
            $SyncHash.TextBoxNotes.Text = "No Move VM configuration was found for the selected item."
            if ($SyncHash.TextBoxMoveVmJson) { $SyncHash.TextBoxMoveVmJson.Text = "Move VM JSON:" }
        }

        return
    }

    $SyncHash.TextBoxHostName.Text = $ItemHeader
    if ($SyncHash.TextBoxMoveVmJson) { $SyncHash.TextBoxMoveVmJson.Text = "Move VM JSON:" }
    return

    # Is selected item a host or cluster?
    If (($SelectedParent -eq $null) -and ($ItemTag.Length -gt 7)) {
        $Script:IsCluster = $true        
    }
    Else {
        $Script:IsCluster = $false       
    }


    Switch ($Script:IsCluster) {
        True {

            $SyncHash.MenuIsm.Visibility = "Hidden"
            $SyncHash.MenuPtAgent.Visibility = "Hidden"
            $SyncHash.MenuNX.Visibility = "Hidden"
            $SyncHash.MenuPuttyHost.Visibility = "Hidden"
            $SyncHash.MenuPuttyCvm.Visibility = "Hidden"
            $SyncHash.MenuPuttyNX.Visibility = "Hidden"
            $SyncHash.MenuBrowserHost.Visibility = "Hidden"
            $SyncHash.MenuBrowserCvm.Visibility = "Hidden"
            $SyncHash.MenuBrowserNX.Visibility = "Hidden"
            $SyncHash.MenuPingHost.Visibility = "Hidden"
            $SyncHash.MenuPingCvm.Visibility = "Hidden"
            $SyncHash.MenuPingNX.Visibility = "Hidden"
            

            $SyncHash.TextBoxHostName.Text = $null
            $SyncHash.TextBoxVendor.Text = $null
            $SyncHash.TextBoxModel.Text = $null
            $SyncHash.TextBoxServiceTag.Text = $null
            $SyncHash.TextBoxHypervisor.Text = $null
            $SyncHash.TextBoxvCentername.Text = "vCenter:"
            $SyncHash.TextBoxDatacenter.Text = "Datacenter:"
            $SyncHash.TextBoxClusterName.Text = "Cluster:"
            $SyncHash.TextBoxAosClusterName.Text = "AOS Cluster Name:"
            $SyncHash.TextBoxAosClusterIP.Text = "Cluster IP:"
            $SyncHash.TextBoxvCenterIP.Text = "vCenter IP:"
            $SyncHash.TextBoxDataServicesIP.Text = "Data Services IP:"
            $SyncHash.TextBoxHostIP.Text = "Host IP:"
            $SyncHash.TextBoxCvmIP.Text = "CVM IP:"
            $SyncHash.TextBoxNXIP.Text = "NX IP:"
            $SyncHash.TextBoxAosVersion.Text = "AOS:"
            $SyncHash.TextBoxNccVersion.Text = "NCC:"
            $SyncHash.TextBoxFoundationVersion.Text = "Foundation:"
            $SyncHash.TextBoxFoundationPlatformVersion.Text = "Foundation Platform:"
            $SyncHash.TextBoxFilesVersion.Text = "Files:"
            $SyncHash.TextBoxFSMVersion.Text = "FSM:"
            $SyncHash.TextBoxBlockPosition.Text = "Block Position:"
            $SyncHash.TextBoxHostId.Text = "Host ID:"
            $SyncHash.TextBoxHostUuid.Text = "Host UUID:"
            $SyncHash.TextBoxAosClusterUuid.Text = "Cluster UUID:"
            $SyncHash.TextBoxExpressServiceCode.Text = "Express Service Code:"
            $SyncHash.TextBoxRingStatus.Text = "Metadata Ring:"
            $SyncHash.TextBoxConnectionState.Text = "Connection State:"
            $SyncHash.TextBoxUptime.Text = "Uptime (Days):"
            $SyncHash.TextBoxPtAgentStatus.Text = "PTAgent: "
            $SyncHash.TextBoxIsmStatus.Text = "iSM: "
                
            $Data = $null
            If (Test-Path -Path "$($SyncHashData.RootDirectory)\Data\Clusters\$($ItemHeader)\$($ItemHeader).csv") {
                $Data = Import-Csv -Path "$($SyncHashData.RootDirectory)\Data\Clusters\$($ItemHeader)\$($ItemHeader).csv"
            } 

            # Import notes.
            If (Test-Path "$($SyncHashData.RootDirectory)\Data\Clusters\$($ItemHeader)\$($ItemHeader)_Notes.txt") {
                $Notes = Get-Content -Path "$($SyncHashData.RootDirectory)\Data\Clusters\$($ItemHeader)\$($ItemHeader)_Notes.txt"
                $SyncHash.TextBoxNotes.Text = $Notes | Out-String
            }
            Else {
                $SyncHash.TextBoxNotes.Text = $null
            }

            If ($Data) {
                $Script:vCenterName = $Data.vCenterName
                $Script:Datacenter = $Data.Datacenter
                $Script:Cluster = $Data.Cluster
                $Script:AosClusterName = $Data.AosClusterName
                $Script:AosClusterIP = $Data.AosClusterIP
                $Script:vCenterIP = $Data.vCenterIP
                $Script:IscsiDataServicesIP = $Data.IscsiDataServicesIP
                $Script:AosVersion = $Data.AosVersion
                $Script:NccVersion = $Data.NccVersion
                $Script:FilesVersion = $Data.FilesVersion
                $Script:FsmVersion = $Data.FsmVersion
                $Script:AosClusterUuid = $Data.AosClusterUuid
                $Script:Hypervisor = $Data.Hypervisor

                $SyncHash.TextBoxHostName.Text = $($Script:AosClusterName)
                $SyncHash.TextBoxvCentername.Text = "vCenter: $($Script:vCenterName)"
                $SyncHash.TextBoxDatacenter.Text = "Datacenter: $($Script:Datacenter)"
                $SyncHash.TextBoxClusterName.Text = "Cluster: $($Script:Cluster)"
                $SyncHash.TextBoxAosClusterName.Text = "AOS Cluster Name: $($Script:AosClusterName)"
                $SyncHash.TextBoxAosClusterIP.Text = "Cluster IP: $($Script:AosClusterIP)"
                $SyncHash.TextBoxvCenterIP.Text = "vCenter IP: $($Script:vCenterIP)"
                $SyncHash.TextBoxDataServicesIP.Text = "Data Services IP: $($Script:IscsiDataServicesIP)"
                $SyncHash.TextBoxAosVersion.Text = "AOS: $($Script:AosVersion)"
                $SyncHash.TextBoxNccVersion.Text = "NCC: $($Script:NccVersion)"
                $SyncHash.TextBoxFilesVersion.Text = "Files: $($Script:FilesVersion)"
                $SyncHash.TextBoxFSMVersion.Text = "FSM: $($Script:FsmVersion)"
                $SyncHash.TextBoxAosClusterUuid.Text = "Cluster UUID: $($Script:AosClusterUuid)"
                $SyncHash.HealthIcon.Visibility = "Hidden"
            }
        }
        False { 

            $SyncHash.MenuIsm.Visibility = "Hidden"
            $SyncHash.MenuPtAgent.Visibility = "Hidden"
            $SyncHash.MenuNX.Visibility = "Visible"
            $SyncHash.MenuPuttyHost.Visibility = "Visible"
            $SyncHash.MenuPuttyCvm.Visibility = "Visible"
            $SyncHash.MenuPuttyNX.Visibility = "Visible"
            $SyncHash.MenuBrowserHost.Visibility = "Visible"
            $SyncHash.MenuBrowserCvm.Visibility = "Visible"
            $SyncHash.MenuBrowserNX.Visibility = "Visible"
            $SyncHash.MenuPingHost.Visibility = "Visible"
            $SyncHash.MenuPingCvm.Visibility = "Visible"
            $SyncHash.MenuPingNX.Visibility = "Visible"

            $SyncHash.TextBlockLastInventory.Text = "Host Inventory Completed On:"
            $SyncHash.TextBoxHostName.Text = $null
            $SyncHash.TextBoxvCentername.Text = "vCenter:"
            $SyncHash.TextBoxDatacenter.Text = "Datacenter:"
            $SyncHash.TextBoxClusterName.Text = "Cluster:"
            $SyncHash.TextBoxAosClusterName.Text = "AOS Cluster Name:"
            $SyncHash.TextBoxAosClusterIP.Text = "Cluster IP:"
            $SyncHash.TextBoxvCenterIP.Text = "vCenter IP:"
            $SyncHash.TextBoxDataServicesIP.Text = "Data Services IP:"
            $SyncHash.TextBoxAosVersion.Text = "AOS:"
            $SyncHash.TextBoxNccVersion.Text = "NCC:"
            $SyncHash.TextBoxFilesVersion.Text = "Files:"
            $SyncHash.TextBoxFSMVersion.Text = "FSM:"
            $SyncHash.TextBoxAosClusterUuid.Text = "Cluster UUID:"


            $ClusterName = $SyncHash.TreeView.SelectedItem.Parent.Header
            $BasicInfo = $null
            $Devices = $null
            $NXLogs = $null

            # Import basic host info.
            If (Test-Path -Path "$($SyncHashData.RootDirectory)\Data\Clusters\$($ClusterName)\$($ItemTag)\$($ItemTag)_BasicInfo.csv") {
                $BasicInfo = Import-Csv -Path "$($SyncHashData.RootDirectory)\Data\Clusters\$($ClusterName)\$($ItemTag)\$($ItemTag)_BasicInfo.csv"
            }

            # Import devices and firmware info.
            If (Test-Path -Path "$($SyncHashData.RootDirectory)\Data\Clusters\$($ClusterName)\$($ItemTag)\$($ItemTag)_HostFirmware.csv") {
                $Devices = Import-Csv -Path "$($SyncHashData.RootDirectory)\Data\Clusters\$($ClusterName)\$($ItemTag)\$($ItemTag)_HostFirmware.csv"
            }

            # Import NX logs.
            If (Test-Path -Path "$($SyncHashData.RootDirectory)\Data\Clusters\$($ClusterName)\$($ItemTag)\$($ItemTag)_NXLogs.csv") {
                $NXLogs = Import-Csv -Path "$($SyncHashData.RootDirectory)\Data\Clusters\$($ClusterName)\$($ItemTag)\$($ItemTag)_NXLogs.csv"
            }

            # Import saved notes.
            If (Test-Path -Path "$($SyncHashData.RootDirectory)\Data\Clusters\$($ClusterName)\$($ItemTag)\$($ItemTag)_Notes.txt") {
                $Notes = Get-Content -Path "$($SyncHashData.RootDirectory)\Data\Clusters\$($ClusterName)\$($ItemTag)\$($ItemTag)_Notes.txt"
                $SyncHash.TextBoxNotes.Text = $Notes | Out-String
            }
            Else {
                $SyncHash.TextBoxNotes.Text = $null
            }

            If ($Devices) {
                Foreach ($Device in $Devices) {
                    Populate-Firmware $Device.Description $Device.Version
                }
            }
            If ($NXLogs) {
                Foreach ($NXLog in $NXLogs) {
                    Populate-NXLogs $NXLog.Date $NXLog.Severity $NXLog.Description
                }
            }

            If ($BasicInfo) {
                $Script:LastInventory = $BasicInfo.LastInventory
                $Script:Hostname = $BasicInfo.Hostname
                $Script:Vendor = $BasicInfo.Manufacturer
                $Script:Model = $BasicInfo.Model
                $Script:ServiceTag = $BasicInfo.ServiceTag
                $Script:Hypervisor = $BasicInfo.Hypervisor
                $Script:HypervisorVersion = $BasicInfo.HypervisorVersion
                $Script:vCenterName = $BasicInfo.vCenterName
                $Script:Datacenter = $BasicInfo.Datacenter
                $Script:Cluster = $BasicInfo.Cluster
                $Script:AosClusterName = $BasicInfo.AosClusterName
                $Script:AosClusterIP = $BasicInfo.AosClusterIP
                $Script:vCenterIP = $BasicInfo.vCenterIP
                $Script:IscsiDataServicesIP = $BasicInfo.IscsiDataServicesIP
                $Script:HostIP = $BasicInfo.HostIP
                $Script:CvmIP = $BasicInfo.CvmIP
                $Script:NXAddress = $BasicInfo.NXAddress
                $Script:AosVersion = $BasicInfo.AosVersion
                $Script:NccVersion = $BasicInfo.NccVersion
                $Script:FoundationVersion = $BasicInfo.FoundationVersion
                $Script:FoundationPlatformVersion = $BasicInfo.FoundationPlatformVersion
                $Script:FilesVersion = $BasicInfo.FilesVersion
                $Script:FsmVersion = $BasicInfo.FsmVersion
                $Script:BlockPosition = $BasicInfo.BlockPosition
                $Script:HostId = $BasicInfo.HostId
                $Script:HostUuid = $BasicInfo.HostUuid
                $Script:AosClusterUuid = $BasicInfo.AosClusterUuid
                $Script:ExpressServiceCode = $BasicInfo.ExpressServiceCode
                $Script:RingStatus = $BasicInfo.CvmRingStatus
                $Script:ConnectionState = $BasicInfo.ConnectionState
                $Script:Uptime = $BasicInfo.UptimeDays
                $Script:HardwareHealth = $BasicInfo.HardwareHealth


                $SyncHash.TextBlockLastInventory.Text = "Host Inventory Completed On: $($Script:LastInventory)"
                $SyncHash.TextBoxHostName.Text = ($Script:Hostname).ToUpper()
                $SyncHash.TextBoxVendor.Text = $Script:Vendor
                $SyncHash.TextBoxModel.Text = $Script:Model
                $SyncHash.TextBoxServiceTag.Text = $Script:ServiceTag
                $SyncHash.TextBoxHypervisor.Text = "$($Script:Hypervisor) $($Script:HypervisorVersion)"
                $SyncHash.TextBoxvCentername.Text = "vCenter: $($Script:vCenterName)"
                $SyncHash.TextBoxDatacenter.Text = "Datacenter: $($Script:Datacenter)"
                $SyncHash.TextBoxClusterName.Text = "Cluster: $($Script:Cluster)"
                $SyncHash.TextBoxAosClusterName.Text = "AOS Cluster Name: $($Script:AosClusterName)"
                $SyncHash.TextBoxAosClusterIP.Text = "Cluster IP: $($Script:AosClusterIP)"
                $SyncHash.TextBoxvCenterIP.Text = "vCenter IP: $($Script:vCenterIP)"
                $SyncHash.TextBoxDataServicesIP.Text = "Data Services IP: $($Script:IscsiDataServicesIP)"
                $SyncHash.TextBoxHostIP.Text = "Host IP: $($Script:HostIP)"
                $SyncHash.TextBoxCvmIP.Text = "CVM IP: $($Script:CvmIP)"
                $SyncHash.TextBoxNXIP.Text = "NX IP: $($Script:NXAddress)"
                $SyncHash.TextBoxAosVersion.Text = "AOS: $($Script:AosVersion)"
                $SyncHash.TextBoxNccVersion.Text = "NCC: $($Script:NccVersion)"
                $SyncHash.TextBoxFoundationVersion.Text = "Foundation: $($Script:FoundationVersion)"
                $SyncHash.TextBoxFoundationPlatformVersion.Text = "Foundation Platform: $($Script:FoundationPlatformVersion)"
                $SyncHash.TextBoxFilesVersion.Text = "Files: $($Script:FilesVersion)"
                $SyncHash.TextBoxFSMVersion.Text = "FSM: $($Script:FsmVersion)"
                $SyncHash.TextBoxBlockPosition.Text = "Block Position: $($Script:BlockPosition)"
                $SyncHash.TextBoxHostId.Text = "Host ID: $($Script:HostId)"
                $SyncHash.TextBoxHostUuid.Text = "Host UUID: $($Script:HostUuid )"
                $SyncHash.TextBoxAosClusterUuid.Text = "Cluster UUID: $($Script:AosClusterUuid)"
                $SyncHash.TextBoxExpressServiceCode.Text = "Express Service Code: $($Script:ExpressServiceCode)"
                $SyncHash.TextBoxRingStatus.Text = "Metadata Ring: $($Script:RingStatus)"
                $SyncHash.TextBoxConnectionState.Text = "Connection State: $($Script:ConnectionState)"
                $SyncHash.TextBoxUptime.Text = "Uptime (Days): $($Script:Uptime)"
                $SyncHash.TextBoxPtAgentStatus.Text = "PTAgent: "
                $SyncHash.TextBoxIsmStatus.Text = "iSM: "
                $SyncHash.HealthIcon.Visibility = "Visible"
          
                If ($Script:RingStatus -ne "Normal" -or $Script:ConnectionState -ne "Connected" -or $Script:HardwareHealth -ne "Ok") {
                    If ($Script:HardwareHealth -ne $null -and $Script:HardwareHealth -ne "") {
                        $SyncHash.HealthIcon.Kind = "HeartFlash"
                        $SyncHash.HealthIcon.Foreground = "#FFFF0000"
                    }
                    Else {
                        $SyncHash.HealthIcon.Kind = "HeartPulse"
                        $SyncHash.HealthIcon.Foreground = $SyncHash.ChangePrimaryColorPopupBox.Background
                    }
                }
                Else {
                    $SyncHash.HealthIcon.Kind = "HeartPulse"
                    $SyncHash.HealthIcon.Foreground = $SyncHash.ChangePrimaryColorPopupBox.Background
                }

            }

        }
    }

    # Find and import contact information.
    If (Test-Path "$($SynchashData.RootDirectory)\Data\Contacts\$($Script:AosClusterName)\$($Script:AosClusterName)_Contacts.csv") {
        $Script:ContactInfo = Import-Csv -Path "$($SynchashData.RootDirectory)\Data\Contacts\$($Script:AosClusterName)\$($Script:AosClusterName)_Contacts.csv"

        $SyncHash.FacilityName.Text = $Script:ContactInfo.FacilityName
        $SyncHash.PrimaryContactname.Text = $Script:ContactInfo.PrimaryName
        $SyncHash.PrimaryContactPhone.Text = $Script:ContactInfo.PrimaryPhone
        $SyncHash.PrimaryContactEmail.Text = $Script:ContactInfo.PrimaryEmail
        $Synchash.PrimaryContactTitle.Text = $Script:ContactInfo.PrimaryTitle
        $Synchash.SecondaryContactName.Text = $Script:ContactInfo.SecondaryName
        $Synchash.SecondaryContactPhone.Text = $Script:ContactInfo.SecondaryPhone
        $Synchash.SecondaryContactEmail.Text = $Script:ContactInfo.SecondaryEmail
        $Synchash.SecondaryContactTitle.Text = $Script:ContactInfo.SecondaryTitle
        $Synchash.GroupContactName.Text = $Script:ContactInfo.GroupName
        $Synchash.GroupContactPhone.Text = $Script:ContactInfo.GroupPhone
        $Synchash.GroupContactEmail.Text = $Script:ContactInfo.GroupEmail
        $Synchash.Street.Text = $Script:ContactInfo.Street
        $Synchash.City.Text = $Script:ContactInfo.City
        $Synchash.State.Text = $Script:ContactInfo.State
        $Synchash.Zip.Text = $Script:ContactInfo.Zip
    }
    Else {
        $Script:ContactInfo = $null
        $SyncHash.FacilityName.Text = $null
        $SyncHash.PrimaryContactname.Text = $null
        $SyncHash.PrimaryContactPhone.Text = $null
        $SyncHash.PrimaryContactEmail.Text = $null
        $Synchash.PrimaryContactTitle.Text = $null
        $Synchash.SecondaryContactName.Text = $null
        $Synchash.SecondaryContactPhone.Text = $null
        $Synchash.SecondaryContactEmail.Text = $null
        $Synchash.SecondaryContactTitle.Text = $null
        $Synchash.GroupContactName.Text = $null
        $Synchash.GroupContactPhone.Text = $null
        $Synchash.GroupContactEmail.Text = $null
        $Synchash.Street.Text = $null
        $Synchash.City.Text = $null
        $Synchash.State.Text = $null
        $Synchash.Zip.Text = $null
    }

}