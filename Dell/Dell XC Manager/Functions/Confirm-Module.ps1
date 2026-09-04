Function Confirm-Module {

    Param(
        [Parameter(Mandatory = $true,
            Position = 0)]  
        [string]
        $Name
    )

    Write-Host "INFO: Checking for required module, $($Name)..."

    If (-not(Get-Module -name $Name)) {

        If (Get-Module -Name $Name -ListAvailable) {

            Write-Host "INFO: Module found. Importing module..."

            # If module is found then import it.
            Try {
                Get-Module -Name $Name -ListAvailable | Import-Module -Force | Out-Null
            }
            Catch [System.Management.Automation.RuntimeException] {}

            If ($Name -eq "VMware.PowerCLI") {
                Set-PowerCLIConfiguration -Scope User -ParticipateInCEIP $false -Confirm:$false | Out-Null
            }
        }
        Else { 

            # If module is not found.
            $InstallModule = [System.Windows.Forms.MessageBox]::Show("ERROR: A required module, $($Name), is not available. Do you want to install it from the PowerShell Gallery?", "Module Missing", "YesNo" , "Question")

            If ($InstallModule -eq "Yes") {

                Write-Host "INFO: Attempting to install module from PSGallery..."
                Find-Module -Name $Name -Repository PSGallery | Install-Module -Scope CurrentUser -Force -AllowClobber
                Get-Module -Name $Name -ListAvailable | Import-Module -Force 

                If ($Name -eq "VMware.PowerCLI") {
                    Set-PowerCLIConfiguration -Scope User -ParticipateInCEIP $false
                }

                If (-not(Get-Module -name $Name)) {
                    $SyncHashData.Exit = $true
                }
                Else {
                    $SyncHashData.Exit = $false
                }
            }
            Else {
                $SyncHashData.Exit = $true
            }

        } 
    }
}