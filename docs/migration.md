# Migrating GenericQueueableHandler

The surrounding application's `GenericQueueableHandler` remains unchanged. Install the core from this repository using `sf project deploy start --source-dir force-app --target-org YOUR_DEV_ORG` before migrating callers.

Migrate one operation at a time:

1. Create an application handler implementing `AADHandler`.
2. In `validate()`, check IDs and a typed payload without side effects.
3. In `execute()`, delegate to the existing business service.
4. Register the operation using `AAD_Operation__mdt`.
5. Update callers to create `AADRequest` and invoke `AADDispatcher.submit()`.
6. Verify actual service effects and native job status before migrating the next operation.
7. Remove the old dispatcher only after all its callers and interface dependencies are migrated.

For example, an application-specific `InsuranceQuoteAsyncHandler` can delegate to an existing `InsuranceAPI.sendInsuranceRequest()` service. Such adapters belong in the application repository. Preserve existing operation keys when they fit Salesforce metadata record naming constraints; explicitly update callers when a key must change.

Replace wrapper-specific fields such as `oppIds`, `openAiData`, and `csWrpr` with `recordIds` and operation-specific JSON. Do not add dependencies on application wrapper types to the core.

`invokeMethod()` returned a Boolean and could fall back to Future execution. `submit()` returns a job ID or throws; it has no Future or synchronous fallback. Handle submission errors where the business process can make an explicit decision, rather than silently dropping work.

Move delays from individual requests into operation metadata. If you need request-specific delay overrides later, introduce a documented options contract rather than quietly changing the metadata policy.

Fix swallowed exceptions in migrated handlers. Restore any temporary static flags to their prior values in a `finally` block. For flows and service loops, define bulk limits and failure semantics rather than copying the old dispatcher wholesale.
