Function Update-Task {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true,
            Position = 0)]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [string]
        $TaskID,

        [Parameter(Mandatory = $false)]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [string]
        $Details,

        [Parameter(Mandatory = $false)]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [string]
        $Target,

        [Parameter(Mandatory = $false)]
        [ValidateSet("Complete", "Failed", "Canceled", "Waiting", "Running")]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [string]
        $Status
        
    )

    $TargetItem = $SyncHash.ListViewTasks.Items | Where-Object { $_.TaskID -eq $TaskID }

    If ($Status) {

        Switch ($Status) {

            Complete {
                
                $SyncHash.ListViewTasks.Dispatcher.Invoke([Action] {
                        $TargetItem.Status = "Complete"  
                        $TargetItem.CompletionTime = ((Get-Date -Format "MM/dd/yyyy HH:mm:ss").ToString()) 
                        
                        If ($SyncHash.ListViewTasks.Items.Status -notcontains "Running") {
                            $SyncHash.ProgressBar.Visibility = "Hidden"
                        }
                    }, "Background") 

            }
            Failed {
                
                $SyncHash.ListViewTasks.Dispatcher.Invoke([Action] {
                        $TargetItem.Status = "Failed"
                        $TargetItem.CompletionTime = ((Get-Date -Format "MM/dd/yyyy HH:mm:ss").ToString())

                        If ($SyncHash.ListViewTasks.Items.Status -notcontains "Running") {
                            $SyncHash.ProgressBar.Visibility = "Hidden"
                        }

                    }, "Background") 

            }
            Canceled {
                
                $SyncHash.ListViewTasks.Dispatcher.Invoke([Action] {
                        $TargetItem.Status = "Canceled"
                        $TargetItem.CompletionTime = ((Get-Date -Format "MM/dd/yyyy HH:mm:ss").ToString())

                        If ($SyncHash.ListViewTasks.Items.Status -notcontains "Running") {
                            $SyncHash.ProgressBar.Visibility = "Hidden"
                        }
                        
                    }, "Background")


            }
            Waiting {
                
                $SyncHash.ListViewTasks.Dispatcher.Invoke([Action] {
                        $TargetItem.Status = "Waiting"
                    }, "Background")

            }
            Running {
                
                $SyncHash.ListViewTasks.Dispatcher.Invoke([Action] {
                        $TargetItem.Status = "Running"
                    }, "Background")

            }
        }

    }

    If ($Details) {
        
        $SyncHash.ListViewTasks.Dispatcher.Invoke([Action] {
                $TargetItem.Details = $Details
            }, "Background")
            
    }

    If ($Target) {
        
        $SyncHash.ListViewTasks.Dispatcher.Invoke([Action] {
                $TargetItem.Target = $Target
            }, "Background")
            
    }

    
    $SyncHash.ListViewTasks.Dispatcher.Invoke([Action] {
    
            # Refresh the ListViewItem by resetting its content
            $SyncHash.ListViewTasks.Items[$SyncHash.ListViewTasks.Items.IndexOf($TargetItem)] = $TargetItem
            $TargetItem = $null   
            $SyncHash.ListViewTasks.Items.Refresh()
        }, "Background")

}