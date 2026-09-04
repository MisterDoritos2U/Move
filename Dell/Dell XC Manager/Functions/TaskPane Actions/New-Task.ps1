Function New-Task {

    [CmdletBinding()]
    Param(

        [Parameter(Mandatory = $true,
            Position = 0)]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        $TaskID,

        [Parameter(Mandatory = $true,
            Position = 1)]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [string]
        $Target,

        [Parameter(Mandatory = $true,
            Position = 2)]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [string]
        $Details    
    )

    $TaskInfo = [PSCustomObject]@{
        TaskID         = $TaskID;
        StartTime      = (Get-Date -Format "MM/dd/yyyy HH:mm:ss").ToString();
        Target         = $Target
        Details        = $Details;
        Status         = "Running";
        CompletionTime = $null
    }

    $SyncHash.ListViewTasks.Dispatcher.Invoke([Action] {
            $SyncHash.ListViewTasks.Items.Add($TaskInfo) | Out-Null }, "Background")

}