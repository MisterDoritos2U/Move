# Create Migration Plan

The Move window now supports creating a migration plan after selecting a Move appliance.

## Workflow

1. Select a Move appliance from **Move VM**.
2. Click **Create Plan**.
3. Select a source provider.
4. Select an AHV target provider.
5. Select one or more source VMs.
6. Review the source-to-target network mappings.
7. Enter a migration plan name.
8. Click **Create Plan**.

The module calls the Move v2 `POST /move/v2/plans` API. The payload contains the source provider, target provider/AHV cluster/container, network mappings, and VM workload references.

After creation, the parent Move window refreshes the endpoint inventory so the new plan appears in the Migration Plans list.

## Safety

Creating a migration plan does not start migration or cutover. The API creates the plan in Move; the normal Move preparation/readiness/start/cutover workflow remains separate.

## API documentation alignment

The supplied Move V2 documentation confirms that the plan-list operation is `POST /move/v2/plans/list`, with no request payload and an `Authorization: {{Authorization-Token}}` header. The application uses that documented contract for plan inventory and does not replace it with bearer-token authentication.
