# Move V2 migration workflow alignment

This build is aligned to the supplied Move V2 migration API documentation in `MigrationAPI.zip`.

## Supported documented calls

- Create plan: `POST /move/v2/plans/`
- Prepare plan: `POST /move/v2/plans/{id}/prepare`
- Readiness: `POST /move/v2/plans/{id}/readiness`
- Start plan: `POST /move/v2/plans/{id}/start`
- Get workload details: `GET /move/v2/plans/{id}/workloads/{wid}`
- Workload action: `POST /move/v2/plans/{id}/workloads/{wid}/action`
- Refresh workload: `POST /move/v2/plans/{id}/workloads/{wid}/refresh`

## Authentication

The supplied migration API documents specify `Authorization: {{Authorization-Token}}`. They do not include the Login/Refresh Token request definitions in the uploaded archive. Therefore this build does **not** invent a new token exchange. It preserves the application's existing credential/header mechanism.

If the Move appliance is returning HTTP 401, the new `Invoke-MoveApi` error handling reports the HTTP status and response body when Move provides one. That makes it possible to distinguish an authentication failure from an invalid migration payload.

## Create-plan payload

The create-plan payload was changed to match the supplied Create Migration Plan sample: `IsUpdatePlanFlow` plus `Spec`, with provider information, network mappings, and VM workload entries. The previous undocumented top-level `APIVersion`, `Type`, and `MetaData` fields were removed.

The VM fields now include the documented controls such as `AllowUVMOps`, `GuestPrepMode`, `RetainMacAddress`, `SkipCdrom`, `EnableMemoryOvercommit`, `UninstallGuestTools`, `InstallNGT`, `VMCustomizeType`, and `VMReference`.


## Authentication alignment

Move V2 authentication now follows the supplied Login API: `POST /move/v2/users/login`, JSON `Spec.UserName`/`Spec.Password`, then `Status.Token` is sent directly as `Authorization`. The token is cached for the PowerShell process as `Authorization-Token`.
