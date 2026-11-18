# Apex Async Dispatcher

A lightweight, Custom Metadata-driven framework for dispatching Salesforce Queueable jobs to interchangeable Apex handlers.

Suggested GitHub repository: **`apex-async-dispatcher`**. Initial source version: **0.1.0**. Minimum supported Apex API version: **64.0**. This project is independent of the surrounding application's `force-app` directory.

## Install the core

Run commands from this directory, with Salesforce CLI installed and an explicitly selected development org authenticated:

```sh
cd packages/apex-async-dispatcher
sf project deploy start --source-dir force-app --target-org YOUR_DEV_ORG --test-level RunLocalTests --wait 20
```

If this directory has been extracted as its own repository, start in that repository root instead. The default application deployment from the parent repository does not include this project.

Core installation creates no operation registrations. In Setup, open **Custom Metadata Types → Async Operation → Manage Records → New** and register your handler:

| Setting | Example |
| --- | --- |
| Label | Process Accounts |
| Async Operation Name (`DeveloperName`) | `PROCESS_ACCOUNTS` |
| Handler Class | `MyAccountAsyncHandler` |
| Handler Namespace | Leave blank for an unpackaged handler |
| Enabled | Checked |
| Delay Minutes | `0` |

The handler must be a public top-level class implementing `AADHandler` and have a usable no-argument constructor. Implementations and their constructors must follow the [handler contract](docs/handler-development.md).

## Submit work

```apex
AADRequest request = new AADRequest();
request.operationKey = 'PROCESS_ACCOUNTS';
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

## Try the examples

Deploy examples separately, **in a development org**, after installing the core:

```sh
sf project deploy start --source-dir examples --target-org YOUR_DEV_ORG --test-level RunLocalTests --wait 20
```

This installs two enabled example registrations:

| Operation key | Handler | Behaviour |
| --- | --- | --- |
| `EXAMPLE_ACCOUNT_UPDATE` | `AADExampleAccountHandler` | Overwrites `Account.Description` for 1–200 unique Account IDs using user-mode, all-or-none DML |
| `EXAMPLE_HTTP_CALLOUT` | `AADExampleCalloutHandler` | POSTs a JSON `message` to `callout:AAD_Example_API/events`; fails on non-2xx responses |

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

## Project components

| Name | Responsibility |
| --- | --- |
| `AADDispatcher` | Validates and submits work; returns the job ID |
| `AADRequest` | Serializable envelope with operation key, IDs, JSON payload, version, and optional correlation ID |
| `AADHandler` | `validate()` and `execute()` extension contract |
| `AADExecutionContext` | Job ID, operation key, and correlation ID |
| `AADOperationConfig` | Captured handler and delay configuration |
| `AADOperationRegistry` | Reads and validates `AAD_Operation__mdt` registrations |
| `AADHandlerFactory` | Resolves handler types and checks the interface |
| `AADQueueable` | Executes the registered handler with callout support |
| `AADException` | Framework validation/configuration exception |
| `AAD_Operation__mdt` | Operation registrations; no business payloads or job state |

See [architecture](docs/architecture.md), [configuration](docs/configuration.md), [security](docs/security.md), [migration](docs/migration.md), and [contribution and CI instructions](CONTRIBUTING.md).

This version provides one transaction per request. It does not provide automatic retries, durable pending work, a job-history object, or an execution SLA. Bulk processing remains the handler's responsibility. Native job monitoring is available through Apex Jobs and `AsyncApexJob`.

## Publish independently

Copy the contents of this directory, including dotfiles, into a new repository named `apex-async-dispatcher`. Its Salesforce project, CI workflow, examples, documentation, and license are self-contained. Do not publish the surrounding application repository as part of this extraction. The license in this directory covers this project only.

The workflow also runs within the parent repository through `.github/workflows/aad-validate.yml`. Apex CI is opt-in; see [CONTRIBUTING.md](CONTRIBUTING.md). No GitHub repository or Salesforce package has been created by this source change.
