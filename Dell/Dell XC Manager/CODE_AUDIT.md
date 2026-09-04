# Dell XC Manager Code Audit

Date: 2026-09-02

## Naming / verb audit

PowerShell functions were reviewed against the approved Verb-Noun convention.

### Corrected

- `Load-MoveWindow` -> `Show-MoveWindow`
  - `Load` is not an approved PowerShell verb.
  - `Show` accurately describes the function because it creates and displays the Move dialog.
- Nested helper `Walk` -> `Invoke-WorkloadTraversal`
  - `Walk` was not a Verb-Noun function name.
  - `Invoke` is an approved verb and accurately describes the traversal operation.

### Automatic/system variables

The code was checked for assignments to PowerShell automatic/system variables such as `$PSScriptRoot`, `$PSCommandPath`, `$PSBoundParameters`, `$Error`, `$HOME`, `$Host`, `$this`, `$input`, and `$args`.

No improper assignments were found. A redundant `$null = $this` statement in the Move window Closed handler was removed. `$this` remains used normally by WPF event handlers elsewhere.

## Unused functions removed

The following functions had no callers outside their own definition and were removed:

- `Remove-SelectedListBoxItems`
- `Sort-ListViewOnClick`
- `Start-TaskQueue`
- `Update-TaskQueue`
- `Add-TreeViewItem`
- `Get-TreeViewItem`
- `Remove-TreeViewItem`

## Unused external modules removed

The startup code no longer attempts to install/import modules for which there are no command references in the application:

- `Posh-SSH`
- `VMware.VimAutomation.Core`
- `ImportExcel`

The following SecretManagement/SecretStore modules remain because the credential subsystem directly uses them:

- `Microsoft.PowerShell.SecretManagement`
- `Microsoft.PowerShell.SecretStore`

## Dead compatibility code removed

Removed the unused `Remove-BrokenClusterData` compatibility call from startup. No implementation of that command exists in the supplied application codebase.

## Module consistency

`MoveModule.psm1` and `MoveModule.psd1` now consistently export `Show-MoveWindow`.

## Validation

- All PowerShell files were scanned for function definitions and cross-file references.
- Remaining function definitions have callers or are exported/public entry points.
- Removed function files are no longer present.
- Removed external module names are no longer referenced by startup.
- XAML files remain unchanged by this cleanup.

PowerShell itself was not available in the build environment, so runtime execution and PSScriptAnalyzer execution could not be performed here.
