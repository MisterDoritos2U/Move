Function Save-Credentials {

    Param  
    (  
        [Parameter(Mandatory = $true,
            Position = 0)] 
        [ValidateSet("Move", "Service Account", "vCenter")]
        $EndPoint,
        
        [Parameter(Mandatory = $true,
            Position = 1)] 
        $UserInput
    ) 

    $FormattedEndpoint = $Endpoint -Replace " ", $null

    If ($UserInput) {

        $SecureString = ConvertTo-SecureString $UserInput.Password -AsPlainText -Force
        $Credentials = New-Object System.Management.Automation.PSCredential($UserInput.Username, $SecureString)

        Try {
            Set-Secret -Name "DellXCManager-$($FormattedEndpoint)" -Secret $Credentials -Vault SecretStore -ErrorAction Stop
            $SyncHashData."$($FormattedEndpoint)Creds" = $Credentials
        }
        Catch {
            Write-Warning "Unable to save credentials in SecretStore: $($_.Exception.Message)"
        }

    }

}