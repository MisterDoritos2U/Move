Function Confirm-ValidIP ($IpList) {

    If ($IpList) {
        $FinalOutput = @()
        $IPv4Regex = '^(?:(25[0-5]|(?:2[0-4]|1[0-9]|[1-9]|)[0-9])(\.(?!$)|$)){4}$'

        Foreach ($Input in $IpList) {
            
            # Look for invalid IP addresses.
            If ($Input -ne "0.0.0.0" -and $Input -ne "255.255.255.255" -and $Input -match $IPv4Regex) {
                   
                $FinalOutput += $Input
            }
        }

        $FinalOutput = $FinalOutput | Sort-Object { $_ -as [Version] }

        Return $FinalOutput
    }

}