@Echo Off
REM pwsh.exe -ExecutionPolicy Unrestricted -Command "%~dp0\Get-Updates.ps1"
REM pwsh.exe -ExecutionPolicy Unrestricted -Command "%~dp0\MainWindow.ps1"

pwsh.exe -ExecutionPolicy Unrestricted -Command "& ""%~dp0\Get-Updates.ps1"""
pwsh.exe -ExecutionPolicy Unrestricted -Command "& ""%~dp0\MainWindow.ps1"""