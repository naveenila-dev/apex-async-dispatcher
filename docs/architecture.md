# Architecture

The dispatcher follows this sequence:

```text
AADDispatcher.submit(request)
  → copy and validate envelope
  → AADOperationRegistry.resolve(operationKey)
  → AADHandlerFactory.create(config)
  → handler.validate(request)
  → check remaining Queueable slots
  → enqueue AADQueueable(request snapshot, configuration snapshot)
  → return job ID

AADQueueable.execute(context)
  → validate envelope and captured configuration
  → instantiate the captured handler class
  → handler.validate(request)
  → handler.execute(request, execution context)
```

The framework intentionally has no application-service dependencies. Metadata selects a class that implements a fixed interface; method names and arbitrary executable expressions are not configurable.

## Transaction semantics

Validation and constructors run during submission and again during worker execution. They must be side-effect-free. A new handler instance is created in each transaction; state set on the instance during submission is not preserved for execution.

The worker stores deep copies of request and configuration. It does not consult the registry during execution. Disabling an operation prevents new submissions but does not cancel jobs already submitted. Configuration snapshots freeze selected class names and delay values, not Apex code, credentials, permissions, record contents, or external services.

Submission consumes one available Queueable slot. The framework does not reserve remaining org-wide asynchronous execution capacity. A capacity check is an early rejection, not a guarantee that every platform limit or subsequent operation will succeed.

Unexpected handler exceptions propagate. The framework neither swallows exceptions nor commits an error log within a failed worker transaction. Handlers must decide whether their DML uses all-or-none or partial-success semantics. An external callout cannot be rolled back with Salesforce DML.

## Extension boundaries

`AADDispatcher.submit()` is the supported application entry point. `AADQueueable` and the configuration classes are public to support Apex execution and serialization; directly constructing a worker bypasses registration enablement checks. This library is not a sandbox for untrusted Apex code.

The registry's `Provider` boundary isolates metadata lookup for tests. The provider override is private and `@TestVisible`; application callers cannot replace it through the public API. Queueable tests must not depend on static test configuration surviving into the worker transaction.

Version 0.1.0 supports unpackaged source installation. Namespace-aware lookup is included, but managed-package installation and subscriber extension are not claimed as tested. That distribution model requires a separately designed global API.

## Later releases

Consider `AADFlowAction` for Flow submission and `AADFinalizer` for post-execution reporting. A durable pending-work design would use `AAD_Work_Item__c`, `AADWorkDispatcher`, and `AADWorkScheduler`. Execution history could use `AAD_Execution__c`.

Do not add automatic retries until idempotency, attempt limits, backoff, retryable errors, and final failure handling are specified. A correlation ID is a tracing value; it is not a deduplication or idempotency mechanism.
