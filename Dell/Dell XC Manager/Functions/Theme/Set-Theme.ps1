function  Set-Theme {
    param(
        [Parameter(Mandatory = $true)]
        $Window,
        #[Parameter(Mandatory = $false)]
        #$PrimaryColor,
        #[Parameter(Mandatory = $false)]
        #$AccentColor,
        [Parameter(Mandatory = $false)]
        [ValidateSet('Dark', 'Light')]
        $ThemeMode,
        [Parameter(Mandatory = $false)]
        [bool]$FromCredentialPromptWindow
    )

    $Theme = [MaterialDesignThemes.Wpf.ResourceDictionaryExtensions]::GetTheme($Window.Resources)

    <#If ($PrimaryColor) {
        $PrimaryColorObj = [MaterialDesignColors.SwatchHelper]::Lookup[$PrimaryColor]
        [void][MaterialDesignThemes.Wpf.ThemeExtensions]::SetPrimaryColor($Theme, $PrimaryColorObj)      

    }
    If ($AccentColor) {
        $AccentColorObj = [MaterialDesignColors.SwatchHelper]::Lookup[$AccentColor]
        [void][MaterialDesignThemes.Wpf.ThemeExtensions]::SetSecondaryColor($Theme, $AccentColorObj)
    }#>
    If ($ThemeMode) {
        If ($FromCredentialPromptWindow -eq $false) {
            $DarkBackground = "#FF202020"
            $LightBackground = "#FF999999"

            foreach ($Property in @(
                'MainMenuTopBorder', 'MainMenuBottomBorder', 'SavedCredentialsBorder', 'DiscoverBorder',
                'LogsBorder', 'DevicesBorder', 'TasksBorder', 'TreeView', 'TreeViewBorder', 'TopHostInfoBorder',
                'MiddleHostInfoBorder', 'MaxTasksBorder', 'ContactsBorder', 'TextBoxNotes'
            )) {
                if ($null -ne $SyncHash.$Property) {
                    if ($ThemeMode -eq 'Dark') {
                        if ($Property -eq 'TreeViewBorder') {
                            $SyncHash.$Property.BorderBrush = $DarkBackground
                        }
                        else {
                            $SyncHash.$Property.Background = $DarkBackground
                        }
                    }
                    else {
                        if ($Property -eq 'TreeViewBorder') {
                            $SyncHash.$Property.BorderBrush = $LightBackground
                        }
                        else {
                            $SyncHash.$Property.Background = $LightBackground
                        }
                    }
                }
            }

            if ($null -ne $SyncHash.ToolsBorder) {
                $SyncHash.ToolsBorder.Background = $(if ($ThemeMode -eq 'Dark') { '#FF202020' } else { '#FF999999' })
            }
        }
        [void][MaterialDesignThemes.Wpf.ThemeExtensions]::SetBaseTheme($Theme, [MaterialDesignThemes.Wpf.Theme]::$ThemeMode)
    }
    [void][MaterialDesignThemes.Wpf.ResourceDictionaryExtensions]::SetTheme($Window.Resources, $Theme)
}