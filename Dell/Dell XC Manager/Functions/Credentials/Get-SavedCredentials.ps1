Function Get-SavedCredentials {

    Param (
        [Parameter(Mandatory = $true)]
        [ValidateSet("Move", "Service Account", "vCenter", "Prism Central", "Prism Element")]
        $EndPoint
    )

    $FormattedEndpoint = $EndPoint -Replace " ", $null

    Try {
        $Credentials = Get-Secret -Name "DellXCManager-$($FormattedEndpoint)" -Vault SecretStore -ErrorAction Stop
        If ($Credentials -is [System.Management.Automation.PSCredential]) {
            Return $Credentials
        }
    }
    Catch {
    }

    Return $null

}