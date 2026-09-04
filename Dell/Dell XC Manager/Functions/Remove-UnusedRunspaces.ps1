Function Remove-UnusedRunspaces {

    $RunSpace = [runspacefactory]::CreateRunspace()
    $RunSpace.ApartmentState = "STA"

    # Add functions
    $Functions = (Get-Item -LiteralPath function:\)
    $Functions = $Functions | Where-Object { $_.Name -notmatch ":" -and $_.Source -ne "PowerShellEditorServices.Commands" }
        
    Foreach ($Function in $Functions.Name) {
        $Definition = Get-Content Function:\$Function -ErrorAction Stop
        $SessionStateFunction = New-Object System.Management.Automation.Runspaces.SessionStateFunctionEntry -ArgumentList $Function, $Definition
        $Runspace.InitialSessionState.Commands.Add($SessionStateFunction)
    }

    $Runspace.Open()

    # Add runspace intance id to list so it can be disposed of with close-mainconsole function if it fails to close on its own.
    $SyncHashData.RunspaceInstances += $RunSpace.InstanceId

    $RunSpace.SessionStateProxy.SetVariable("SyncHash", $SyncHash)
    $RunSpace.SessionStateProxy.SetVariable("SyncHashData", $SyncHashData)

    $Global:CleanUpPowerShell = [powershell]::Create().AddScript({  


            $SyncHashData.Close = $false

            While ($SyncHashData.Close -eq $false) {

                Start-Sleep -Seconds 30
            
                Foreach ($RunSpace in Get-Runspace) {
            
                    If (($Runspace.RunspaceAvailability -eq "Available") -or (($Runspace.RunspaceStateInfo.State -eq "Closed")) -and ($SyncHashData.RunspaceInstances.Guid -contains $Runspace.InstanceId.Guid)  ) {

                        Start-Sleep -Seconds 5
                        If (($Runspace.RunspaceAvailability -eq "Available") -or ($Runspace.RunspaceStateInfo.State -eq "Closed")) {
                            $Runspace.Close() | Out-Null
                            $Runspace.Dispose() | Out-Null
                        }
                    }                 
                }
            }

        }) # End of scriptblock.

    $Global:CleanUpPowerShell.Runspace = $RunSpace
    $Global:CleanUpPowerShell.BeginInvoke()

    <#Register-EngineEvent -SourceIdentifier "ListViewTaskUpdated" -Action { 

        $Global:SyncHashData.Host.UI.Write("Event Happened $($RunSpace.InstanceId) ")
    }#>

    # Need Runspaces to be disposed when done.
    $null = Register-ObjectEvent -InputObject $Global:CleanUpPowerShell -EventName InvocationStateChanged -Action {
        Param([System.Management.Automation.PowerShell] $PS)
        
        # NOTE: Use $EventArgs.InvocationStateInfo, not $ps.InvocationStateInfo, 
        #       as the latter is updated in real-time, so for a short-running script
        #       the state may already have changed since the event fired.
        $State = $EventArgs.InvocationStateInfo.State
        
        # Dispose of Runspace when done.
        If ($State -in 'Completed', 'Failed', 'Stopped') {
            $Global:CleanUpPowerShell.Runspace.Close() | Out-Null
            $Global:CleanUpPowerShell.Runspace.Dispose() | Out-Null
            $PS.Close() | Out-Null
            $PS.Dispose() | Out-Null
        }       
        
    }

}