# Move inventory behavior update

## Tree hierarchy

The Move tree is now:

Move VMs
  ├── <Move appliance IP/name>
  │    ├── <Migration Plan>
  │    │    ├── <Guest VM>
  │    │    └── <Guest VM>
  │    └── <Migration Plan>
  └── <Move appliance IP/name>

The dashboard counters now mean:

- MOVE VMs = unique Move appliance endpoints discovered/cached
- MIGRATION PLAN = unique endpoint + migration-plan combinations

Discovery-only cache records are never counted as migration plans.

## Credential behavior

Move credentials are loaded from SecretStore during application startup. If a saved Move credential exists, Set-NtnxApiHeader uses it automatically and does not display the credentials prompt.

The Move inventory workflow asks for Move credentials only when no saved Move credential is available.

## Cache behavior

The application loads the existing Move inventory cache before refreshing the appliances. A failed Move API refresh no longer replaces good cached data with an "[Endpoint Discovered]" placeholder.

A successful API response containing zero migration plans is still cached as an endpoint discovery record.
