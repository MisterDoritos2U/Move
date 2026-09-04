Function Set-NtnxApiHeader {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [ValidateSet("Move", "Prism Central", "Prism Element", "vCenter", "Service Account")]
        [string]$EndPoint,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [ValidateSet("Basic")]
        [string]$AuthenticationMethod = "Basic"
    )

    if ($EndPoint -ne 'Move') {
        $UseSavedCreds = Get-CredsPreference
        $Credentials = $null

        if ($UseSavedCreds -eq $false) {
            $Credentials = Get-UserCredentials $EndPoint
        }
        else {
            $FormattedEndpoint = $EndPoint -Replace " ", $null
            $IsSaved = $false

            switch ($EndPoint) {
                "Prism Central" { $IsSaved = $SyncHash.CheckBoxSavePrismCentralCreds.IsChecked }
                "Prism Element" { $IsSaved = $SyncHash.CheckBoxSavePrismElementCreds.IsChecked }
                "vCenter" { $IsSaved = $SyncHash.CheckBoxSavevCenterCreds.IsChecked }
                "Service Account" { $IsSaved = $false }
            }

            if ($IsSaved -eq $true) {
                try {
                    $SavedCredentials = Get-SavedCredentials -EndPoint $EndPoint
                    if ($SavedCredentials) {
                        $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SavedCredentials.Password)
                        try {
                            $UnsecurePassword = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($BSTR)
                        }
                        finally {
                            [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
                        }
                        $Credentials = [PsCustomObject]@{
                            Username = $SavedCredentials.UserName
                            Password = $UnsecurePassword
                        }
                    }
                }
                catch {
                    $Credentials = $null
                }
            }

            if ($null -eq $Credentials) {
                $Credentials = Get-UserCredentials $EndPoint
            }
        }

        if ($null -eq $Credentials) {
            return $null
        }

        $CredentialPair = "{0}:{1}" -f $Credentials.UserName, $Credentials.Password
        $EncodedCredentials = [System.Convert]::ToBase64String(
            [System.Text.Encoding]::UTF8.GetBytes($CredentialPair)
        )

        return [ordered]@{
            Accept        = 'application/json'
            Authorization = "{0} {1}" -f $AuthenticationMethod, $EncodedCredentials
        }
    }

    # Move V2 does not use HTTP Basic for API calls. The Login API accepts
    # username/password in JSON and returns Status.Token. Move then expects
    # that token directly in the Authorization header (without "Bearer").
    $tokenVariable = 'Authorization-Token'
    $token = [Environment]::GetEnvironmentVariable($tokenVariable, 'Process')
    $endpointMarker = [string]$script:MoveAuthorizationEndpoint

    # A token belongs to the Move appliance that issued it. Never reuse a
    # process token when the selected Move appliance changes.
    $needsLogin = [string]::IsNullOrWhiteSpace($token) -or $endpointMarker -ne [string]$script:MoveLoginEndpoint

    if ($needsLogin) {
        $Credentials = $null

        try {
            $SavedCredentials = Get-SavedCredentials -EndPoint 'Move'
            if ($SavedCredentials -is [System.Management.Automation.PSCredential]) {
                $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SavedCredentials.Password)
                try {
                    $UnsecurePassword = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($BSTR)
                }
                finally {
                    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
                }

                $Credentials = [PsCustomObject]@{
                    Username = $SavedCredentials.UserName
                    Password = $UnsecurePassword
                }
            }
        }
        catch {
            $Credentials = $null
        }

        if ($null -eq $Credentials) {
            $Credentials = Get-UserCredentials -EndPoint 'Move'
        }

        if ($null -eq $Credentials) {
            return $null
        }

        $loginBody = [ordered]@{
            Spec = [ordered]@{
                UserName = [string]$Credentials.UserName
                Password = [string]$Credentials.Password
            }
        }

        $loginUri = if ($script:MoveLoginEndpoint) {
            $script:MoveLoginEndpoint
        }
        else {
            $null
        }

        # Set-NtnxApiHeader historically has no Move IP parameter. The Move
        # window sets the process-scoped endpoint before requesting the header.
        if ([string]::IsNullOrWhiteSpace($loginUri)) {
            throw 'Move authentication requires the Move appliance IP. Set $script:MoveLoginEndpoint before calling Set-NtnxApiHeader -EndPoint Move.'
        }

        try {
            $loginResponse = Invoke-RestMethod `
                -Uri $loginUri `
                -Method POST `
                -Headers @{ Accept = 'application/json' } `
                -ContentType 'application/json' `
                -Body ($loginBody | ConvertTo-Json -Depth 10 -Compress) `
                -SkipCertificateCheck `
                -ErrorAction Stop

            $token = [string]$loginResponse.Status.Token
            if ([string]::IsNullOrWhiteSpace($token)) {
                throw 'Move Login API did not return Status.Token.'
            }

            [Environment]::SetEnvironmentVariable($tokenVariable, $token, 'Process')
            $script:MoveAuthorizationEndpoint = $script:MoveLoginEndpoint
        }
        catch {
            throw "Unable to authenticate to Move at $loginUri. $($_.Exception.Message)"
        }
    }

    return [ordered]@{
        Accept        = 'application/json'
        Authorization = $token
    }
}
