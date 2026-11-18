# Apex Async Dispatcher

A lightweight, Custom Metadata-driven framework for dispatching Salesforce Queueable jobs to interchangeable Apex handlers.

GitHub repository: **`apex-async-dispatcher`**. Initial source version: **0.1.0**. Minimum supported Apex API version: **64.0**.

## Install the core

Run commands from this directory, with Salesforce CLI installed and an explicitly selected development org authenticated:

```sh
sf project deploy start --source-dir force-app --target-org YOUR_DEV_ORG --test-level RunLocalTests --wait 20
```

Run all commands from the repository root. Core and examples have separate source directories; deploy each explicitly.

Core installation creates no operation registrations. In Setup, open **Custom Metadata Types → Async Operation → Manage Records → New** and register your handler:

| Setting                                | Example                               |
| -------------------------------------- | ------------------------------------- |
| Label                                  | Process Accounts                      |
| Async Operation Name (`DeveloperName`) | `PROCESS_ACCOUNTS`                    |
| Handler Class                          | `MyAccountAsyncHandler`               |
| Handler Namespace                      | Leave blank for an unpackaged handler |
| Enabled                                | Checked                               |
| Delay Minutes                          | `0`                                   |

The handler must be a public top-level class implementing `AADHandler` and have a usable no-argument constructor. Implementations and their constructors must follow the [handler contract](docs/handler-development.md).

## Submit work

```apex
AADRequest request = new AADRequest();
request.operationKey = 'EXAMPLE_ACCOUNT_UPDATE';
request.recordIds = new List<Id>{ accountId };
request.payloadVersion = 1;
request.payloadJson = JSON.serialize(new Map<String, Object>{
    'description' => 'Processed asynchronously'
});
request.correlationId = 'account-import-123';

Id jobId = AADDispatcher.submit(request);
```

`submit()` returns an `AsyncApexJob` ID or throws. Invalid requests are rejected before enqueueing. Submission is part of the caller's transaction: rolling back that transaction also rolls back the enqueue.

Handler selection and delay configuration are captured at submission. Changes to registration records affect subsequent submissions. A delay is a minimum wait from 0–10 minutes, not an execution-time guarantee.

## How this simplifies several Queueables

Consider an application that refreshes Accounts, generates invoices, and sends webhooks. Without a shared dispatcher, callers select a different Queueable for each operation:

```apex
System.enqueueJob(new AccountRefreshQueueable(accountIds));
System.enqueueJob(new InvoiceGenerationQueueable(orderIds));
System.enqueueJob(new WebhookDeliveryQueueable(eventIds));
```

Each wrapper stores its inputs and delegates to a business service. For example:

```apex
public with sharing class AccountRefreshQueueable implements Queueable {
  private List<Id> accountIds;

  public AccountRefreshQueueable(List<Id> accountIds) {
    this.accountIds = accountIds;
  }

  public void execute(QueueableContext context) {
    AccountMaintenanceService.refresh(accountIds);
  }
}
```

`InvoiceGenerationQueueable` and `WebhookDeliveryQueueable` repeat that lifecycle around their own services; the webhook wrapper also implements `Database.AllowsCallouts`. Validation, delay selection, and tracing often end up repeated across callers or wrappers.

With Apex Async Dispatcher, move each operation's validation and service call into an `AADHandler`. The application still owns these handlers and services; one framework worker handles Queueable execution for all three.

| Operation key       | Application handler        | Business service called by `execute()`                 |
| ------------------- | -------------------------- | ------------------------------------------------------ |
| `REFRESH_ACCOUNTS`  | `AccountRefreshHandler`    | `AccountMaintenanceService.refresh(request.recordIds)` |
| `GENERATE_INVOICES` | `InvoiceGenerationHandler` | `InvoiceService.generate(request.recordIds)`           |
| `DELIVER_WEBHOOKS`  | `WebhookDeliveryHandler`   | `WebhookService.deliver(request.recordIds)`            |

An Account adapter could look like this:

```apex
public with sharing class AccountRefreshHandler implements AADHandler {
  public void validate(AADRequest request) {
    if (request.payloadVersion != 1) {
      throw new AADException('Account refresh supports payloadVersion 1.');
    }
    if (
      request.recordIds == null ||
      request.recordIds.isEmpty() ||
      request.recordIds.size() > 200
    ) {
      throw new AADException('Supply 1 to 200 unique Account IDs.');
    }
    if (new Set<Id>(request.recordIds).size() != request.recordIds.size()) {
      throw new AADException('Account IDs must be unique.');
    }
    for (Id recordId : request.recordIds) {
      if (
        recordId == null ||
        recordId.getSObjectType() != Account.SObjectType
      ) {
        throw new AADException('Only Account IDs are supported.');
      }
    }
  }

  public void execute(AADRequest request, AADExecutionContext context) {
    // The service checks current business state and enforces data access.
    AccountMaintenanceService.refresh(request.recordIds);
  }
}
```

Register the three operation keys in `AAD_Operation__mdt`, with their handler class names, Enabled checked, and a delay from 0–10 minutes. Then every caller uses the same submission API:

```apex
AADRequest request = new AADRequest();
request.operationKey = 'REFRESH_ACCOUNTS';
request.recordIds = accountIds;
request.correlationId = 'nightly-maintenance-123';
Id jobId = AADDispatcher.submit(request);
```

For invoices or webhooks, set the corresponding operation key and IDs; add a handler-specific JSON payload when needed. An administrator can disable future submissions or change an operation's minimum delay in metadata. Already queued jobs retain their captured configuration.

The framework centralizes envelope validation, handler resolution, Queueable capacity checks, delay application, and execution context. Business rules, bulk processing, permissions, and failure semantics remain in each handler/service. Three submissions still create three jobs with their own limits; this does not reduce job consumption or add automatic retries. For a single simple Queueable, the extra configuration may not be worthwhile.

The classes and services in this comparison are illustrative application code, not supplied components. For complete deployable implementations, see [AADExampleAccountHandler](examples/main/default/classes/AADExampleAccountHandler.cls) and [AADExampleCalloutHandler](examples/main/default/classes/AADExampleCalloutHandler.cls).

## Try the examples

Deploy examples separately, **in a development org**, after installing the core:

```sh
sf project deploy start --source-dir examples --target-org YOUR_DEV_ORG --test-level RunLocalTests --wait 20
```

This installs two enabled example registrations:

| Operation key            | Handler                    | Behaviour                                                                                      |
| ------------------------ | -------------------------- | ---------------------------------------------------------------------------------------------- |
| `EXAMPLE_ACCOUNT_UPDATE` | `AADExampleAccountHandler` | Overwrites `Account.Description` for 1–200 unique Account IDs using user-mode, all-or-none DML |
| `EXAMPLE_HTTP_CALLOUT`   | `AADExampleCalloutHandler` | POSTs a JSON `message` to `callout:AAD_Example_API/events`; fails on non-2xx responses         |

For the Account example, use the submission code above with `EXAMPLE_ACCOUNT_UPDATE` as the key and actual Account IDs. For the HTTP example, supply `{"message":"Hello"}` as `payloadJson` and configure a Named Credential named **`AAD_Example_API`** for your own API. Configure its External Credential and principal access as required. The project includes no endpoint or authentication secrets. Tests use `HttpCalloutMock` and require no live credential.

## Validate

Offline checks:

```sh
python3 scripts/validate_source.py
sf project convert source --root-dir force-app --output-dir /tmp/aad-core-mdapi --api-version 64.0
sf project convert source --root-dir examples --output-dir /tmp/aad-examples-mdapi --api-version 64.0
```

After deploying to a clean development org, execute the tests and collect coverage:

```sh
sf apex run test --target-org YOUR_DEV_ORG --test-level RunLocalTests --code-coverage --result-format human --wait 20
```

Offline checks validate source structure and metadata conversion. Salesforce compilation and Apex test execution require an authenticated org; offline checks do not replace them.

## Verified deployment

On **18 November 2026**, core and examples deployed successfully to the `valueMapper` development org using deployment API **64.0**:

| Verification                                           | Result                                                                              |
| ------------------------------------------------------ | ----------------------------------------------------------------------------------- |
| Core deployment and five core test classes             | 14 tests passed; 135/135 executable lines covered (100%)                            |
| Examples deployment and all seven project test classes | 22 tests passed; example classes covered 76/80 executable lines (95%)               |
| Real Account submission outside Apex tests             | Returned a job ID; job completed with zero errors and updated `Account.Description` |
| Temporary Account cleanup                              | Deleted after checking the result                                                   |

HTTP behavior was tested with mocks; a live Named Credential endpoint was not exercised. These results are from an existing development org, rather than a fresh scratch org, and cover the project's specified tests. See [deployment and test evidence](docs/validation-results.json) for deployment IDs, test names, coverage, and the live job ID.

## Project components

| Name                   | Responsibility                                                                                    |
| ---------------------- | ------------------------------------------------------------------------------------------------- |
| `AADDispatcher`        | Validates and submits work; returns the job ID                                                    |
| `AADRequest`           | Serializable envelope with operation key, IDs, JSON payload, version, and optional correlation ID |
| `AADHandler`           | `validate()` and `execute()` extension contract                                                   |
| `AADExecutionContext`  | Job ID, operation key, and correlation ID                                                         |
| `AADOperationConfig`   | Captured handler and delay configuration                                                          |
| `AADOperationRegistry` | Reads and validates `AAD_Operation__mdt` registrations                                            |
| `AADHandlerFactory`    | Resolves handler types and checks the interface                                                   |
| `AADQueueable`         | Executes the registered handler with callout support                                              |
| `AADException`         | Framework validation/configuration exception                                                      |
| `AAD_Operation__mdt`   | Operation registrations; no business payloads or job state                                        |

See [architecture](docs/architecture.md), [configuration](docs/configuration.md), [security](docs/security.md), [migration](docs/migration.md), and [contribution and verification instructions](CONTRIBUTING.md).

This version provides one transaction per request. It does not provide automatic retries, durable pending work, a job-history object, or an execution SLA. Bulk processing remains the handler's responsibility. Native job monitoring is available through Apex Jobs and `AsyncApexJob`.

## Development and release

See [CONTRIBUTING.md](CONTRIBUTING.md) for local tooling and clean scratch-org verification, and [CHANGELOG.md](CHANGELOG.md) for changes. Source installation is supported for 0.1.0; an unlocked package is deferred until the public contract stabilises.

Queueable delay and user-mode data access follow the [Salesforce Queueable guide](https://developer.salesforce.com/docs/platform/apex-dev/references/apex-dev/apex-queueing-jobs.html) and [access-control guidance](https://developer.salesforce.com/docs/platform/secure-coding/guide/secure-coding-access-control-protect-from-crud-fls-vulnerabilities.html).
