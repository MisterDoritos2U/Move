Function Get-TaskID {

    Do {
        $TaskID = (Get-Random -Minimum 0 -Maximum 999999).ToString("000000")
    }
    Until ($SyncHash.TaskIDs -notcontains $TaskID)
    $SyncHash.TaskIDs += $TaskID
    
    Return $TaskID
}