Function Format-IPList ($IpList) {

    $IpList = $IpList -Split { $_ -eq ',' -or $_ -eq ';' -or $_ -eq ' ' }
    $IpList = $IpList.Trim()
    $IpList = $IpList.Split([System.Environment]::NewLine, [System.StringSplitOptions]::RemoveEmptyEntries)
    $IpList = $IpList | Sort-Object -Unique

    Return $IpList
}