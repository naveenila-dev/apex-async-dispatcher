# Migrating GenericQueueableHandler

The surrounding application's `GenericQueueableHandler` remains unchanged. Install this core in the application org before migrating callers. From the parent repository, an explicit deployment path is `packages/apex-async-dispatcher/force-app`; its default root `force-app` deployment does not include the library.

Migrate one operation at a time:

1. Create an application handler implementing `AADHandler`.
2. In `validate()`, check IDs and a typed payload without side effects.
3. In `execute()`, delegate to the existing business service.
4. Register the operation using `AAD_Operation__mdt`.
5. Update callers to create `AADRequest` and invoke `AADDispatcher.submit()`.
6. Verify actual service effects and native job status before migrating the next operation.
7. Remove the old dispatcher only after all its callers and interface dependencies are migrated.

Suggested adapter names, kept in the application rather than the open-source core:

| Existing operation | Suggested application handler |
| --- | --- |
| `PDF_BLOCK` | `ConsumerPdfAsyncHandler` |
| `OPP_QUOTE_GROUP_LOAN_RST` | `OpportunityRequoteAsyncHandler` |
| `PERFORM_ASSET_BACKED_CHECK` | `AssetBackedCheckAsyncHandler` |
| `CapitalisedInsuranceAmount` | `InsuranceCapitalisationAsyncHandler` |
| `OPP_CHANGE_IN_PURPOSE_OF_USE` | `OpportunityPurposeAsyncHandler` |
| `CREATE_PCA_PDF` | `PcaPdfAsyncHandler` |
| `CREATE_INSURANCE_SUITABILITY_ASSESSMENT_PDF` | `InsuranceAssessmentPdfAsyncHandler` |
| `OPEN_AI` | `OpenAiAsyncHandler` |
| `VERIFY_DL` | `DrivingLicenseAsyncHandler` |
| `POST_TO_GOOGLE_WORKSPACE` | `GoogleWorkspaceAsyncHandler` |
| `INSURANCE_QUOTE` | `InsuranceQuoteAsyncHandler` |
| `HARMONEY_FETCH_APPLICATION_STATUS` | `HarmoneyStatusAsyncHandler` |

These adapters are proposed names, not components supplied by this project. Preserve current operation keys during migration where possible. `CREATE_INSURANCE_SUITABILITY_ASSESSMENT_PDF` exceeds the metadata record name limit of 40 characters; register it as `CREATE_INSURANCE_ASSESSMENT_PDF` and update that caller explicitly.

Replace wrapper-specific fields such as `oppIds`, `openAiData`, and `csWrpr` with `recordIds` and operation-specific JSON. Do not add dependencies on application wrapper types to the core.

`invokeMethod()` returned a Boolean and could fall back to Future execution. `submit()` returns a job ID or throws; it has no Future or synchronous fallback. Handle submission errors where the business process can make an explicit decision, rather than silently dropping work.

Move delays from individual requests into operation metadata. If you need request-specific delay overrides later, introduce a documented options contract rather than quietly changing the metadata policy.

Fix swallowed exceptions in migrated handlers. For the requote operation's temporary static flag, restore its prior value in a `finally` block. For flows and service loops, define bulk limits and failure semantics rather than copying the old dispatcher wholesale.
