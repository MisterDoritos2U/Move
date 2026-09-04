Function Remove-SavedCredentials {

    Param (
        [Parameter(Mandatory = $true)]
        [ValidateSet("Move", "Service Account", "vCenter")]
        $EndPoint
    )

    $FormattedEndpoint = $EndPoint -Replace " ", $null

    Try {
        Remove-Secret -Name "DellXCManager-$($FormattedEndpoint)" -Vault SecretStore -ErrorAction SilentlyContinue
    }
    Catch {
    }

    $SyncHashData."$($FormattedEndpoint)Creds" = $null

}