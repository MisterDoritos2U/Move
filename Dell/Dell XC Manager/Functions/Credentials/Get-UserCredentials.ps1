using namespace MaterialDesignColors
using namespace MaterialDesignColors.Recommended
using namespace MaterialDesignThemes.Wpf
using namespace System.Windows.Media

Function Get-UserCredentials {

    Param  
    (  
        [Parameter(Mandatory = $true)]
        [ValidateSet("Move", "Service Account", "vCenter")] 
        $EndPoint,

        [Parameter(Mandatory = $false)]
        [bool]$UserClicked  
    ) 

    Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase | Out-Null

    # Import the xaml file.
    [xml]$Xaml2 = Get-Content -Path "$($SyncHashData.ScriptPath)\.\Xaml\CredentialsPrompt.xaml"

    # Read the form
    $Reader2 = (New-Object System.Xml.XmlNodeReader $Xaml2)

    Try {
        # Load the Xaml reader.
        $CredentialsPrompt = [Windows.Markup.XamlReader]::Load($Reader2) 

        # AutoFind all controls and add them to the SyncHash
        $Xaml2.SelectNodes("//*[@*[contains(translate(name(.),'n','N'),'Name')]]")  | ForEach-Object { 
            (New-Variable -Name $_.Name -Value $CredentialsPrompt.FindName($_.Name) -Force)
            ($_.Name) = Get-Variable -Name $_.Name | Select-Object -ExpandProperty Value
        }

    }
    Catch {
        Write-Host "Unable to load Windows.Markup.XamlReader: Get-UserCredentials.ps1";
        exit
    }


    # Set theme and colors
    $Theme = Get-ThemeMode $CredentialsPrompt
    $PrimaryColor = Get-PrimaryColor
    $AccentColor = Get-AccentColor
    Set-Theme -Window $CredentialsPrompt -ThemeMode $Theme -FromCredentialPromptWindow $true

    # Status of whether OK button is pressed or not.
    $OkPressed = $false

    $FormattedEndpoint = $EndPoint -Replace " ", $null

    $CredentialsPromptOutsideBorder.BorderBrush.GradientStops[0].Color = $PrimaryColor
    $CredentialsPromptOutsideBorder.BorderBrush.GradientStops[1].Color = $AccentColor
    
    $CredentialsPrompt.Add_MouseLeftButtonDown({
            # Allow clicking and dragging of window from anywhere.
            $_.handled = $true
            $this.DragMove()
        }) 

    $CredentialsPrompt.Add_KeyDown({
            If ($_.Key -eq 'Return') {

                $OkPressed = $true    
        
                $Script:UserInput = [PsCustomObject] @{
                    Username = $TextBoxUserName.Text
                    Password = $TextBoxPassword.Password.ToString()
                }

                # Save credentials if "Remember credentials" is checked.
                If (($CheckBoxRememberCreds.IsChecked -eq $true) -and ($UserClicked -eq $false)) {

                    # Save the credentials.
                    If ($Script:UserInput) {
                    
                        Save-Credentials $EndPoint $Script:UserInput

                        # Check if another thread owns this.
                        If ($SyncHash."CheckBoxSave$($FormattedEndpoint)Creds".Dispatcher.CheckAccess() -eq $false) {

                            $SyncHash."CheckBoxSave$($FormattedEndpoint)Creds".Dispatcher.Invoke([Action] {
                                    $SyncHash."CheckBoxSave$($FormattedEndpoint)Creds".IsChecked = $true                               
                                }, "Background")                         
                        }
                        Else {
                            $SyncHash."CheckBoxSave$($FormattedEndpoint)Creds".IsChecked = $true
                        }
                    }
                }
                $CredentialsPrompt.Close() 

            }
            If ($_.Key -eq "Escape") {
                $Script:UserInput = $null
                $CredentialsPrompt.Close()               
            }
        })

    $CredentialsPrompt.Add_Closing({ 

            # Check if OK button was pressed or not.
            If ($OkPressed -eq $false) {
                $Script:UserInput = $null
            }           
        })

    #TextBlockEndPoint
    $TextBlockEndPoint.Text = "Enter your credentials to connect to: $($EndPoint)"

    #TextBoxUserName
    $TextBoxUserName.BorderBrush = $PrimaryColor
    $UserNameHintAssist.Foreground = $PrimaryColor

    #TextBoxPassword
    $TextBoxPassword.BorderBrush = $PrimaryColor
    $PasswordHintAssist.Foreground = $PrimaryColor

    #CheckBoxRememberCreds
    $CheckBoxRememberCreds.Background = $PrimaryColor
    
    If ($UserClicked -eq $true) {
        $CheckBoxRememberCreds.IsChecked = $true
        $CheckBoxRememberCreds.IsEnabled = $false
    }
    ElseIf ($SyncHashData."$($FormattedEndpoint)Creds") {
        
        $CheckBoxRememberCreds.Content = "Overwrite existing saved credentials."
    }

    # ButtonCancel
    $ButtonCancel.Background = $PrimaryColor
    $ButtonCancel.BorderBrush = $PrimaryColor
    $ButtonCancel.Add_Click({
            $Script:UserInput = $null
            $CredentialsPrompt.Close()
        })

    # ButtonOK
    $ButtonOK.Background = $PrimaryColor
    $ButtonOK.BorderBrush = $PrimaryColor
    $ButtonOK.Add_Click({

            $OkPressed = $true    
        
            $Script:UserInput = [PsCustomObject] @{
                Username = $TextBoxUserName.Text
                Password = $TextBoxPassword.Password.ToString()
            }

            # Save credentials if "Remember credentials" is checked.
            If (($CheckBoxRememberCreds.IsChecked -eq $true) -and ($UserClicked -eq $false)) {

                # Save the credentials.
                If ($Script:UserInput) {
                    
                    Save-Credentials $EndPoint $Script:UserInput

                    # Check if another thread owns this.
                    If ($SyncHash."CheckBoxSave$($FormattedEndpoint)Creds".Dispatcher.CheckAccess() -eq $false) {

                        $SyncHash."CheckBoxSave$($FormattedEndpoint)Creds".Dispatcher.Invoke([Action] {
                                $SyncHash."CheckBoxSave$($FormattedEndpoint)Creds".IsChecked = $true
                                
                            }, "Background")                         
                    }
                    Else {

                        $SyncHash."CheckBoxSave$($FormattedEndpoint)Creds".IsChecked = $true
                    }
                }

            }
            $CredentialsPrompt.Close()
        })

    # Show form.
    $CredentialsPrompt.ShowDialog() | Out-Null

    $UserClicked = $false

    Return $Script:UserInput

}