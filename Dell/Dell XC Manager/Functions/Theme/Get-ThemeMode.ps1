function  Get-ThemeMode {
    Param(
        $Window
    )
    $Theme = [MaterialDesignThemes.Wpf.ResourceDictionaryExtensions]::GetTheme($Window.Resources)
    Return [MaterialDesignThemes.Wpf.ThemeExtensions]::GetBaseTheme($Theme)
}