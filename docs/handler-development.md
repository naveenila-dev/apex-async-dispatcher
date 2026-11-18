# Writing a handler

Implement `AADHandler` in a public top-level class. Use a no-argument constructor, either implicit or explicit, with no side effects.

```apex
public with sharing class MyAccountAsyncHandler implements AADHandler {
    public void validate(AADRequest request) {
        // Check payloadVersion, JSON structure, IDs, and required parameters.
        // No DML, SOQL-dependent business decisions, callouts, or enqueueing.
    }

    public void execute(AADRequest request, AADExecutionContext context) {
        // Read current records, enforce access, and perform bulk work here.
    }
}
```

Use an operation-specific typed payload and `JSON.deserializeStrict()` where unknown fields should be rejected. The envelope accepts any valid JSON value; the handler must enforce the object shape and business schema it requires. A missing payload is allowed at framework level. Version 1 is the default; individual handlers must explicitly decide which positive payload versions they support.

Validation runs twice: before enqueueing and before execution. It must not mutate the request, perform callouts or DML, consume Queueable slots, or depend on mutable static state. Do not store parsed payload state on the submission-time handler instance. Parse again during execution.

`recordIds` is optional at framework level. Validate the permitted object types, count, nulls, and duplicates for your operation. Prefer IDs and minimal parameters over serialized sObjects. Query current data once per batch and perform bulk DML. A list of 200 IDs does not create 200 independent transactions.

Apply business-state checks at execution time, because records and permissions can change while work waits. Explicitly choose your record-access and CRUD/FLS policy. The Account example uses user-mode DML with all-or-none behaviour.

Use Named Credentials for integrations. Handle expected response statuses explicitly and let unexpected failures propagate. Avoid preceding a callout with DML in the same transaction. The framework does not perform pre-handler logging DML.

Do not attach a Finalizer, enqueue child jobs, or implement retries without documenting the additional limits and transaction semantics. The core does not coordinate those resources for handlers.

For tests, cover real output or effects, invalid payloads, failure propagation, bulk inputs, access expectations, and HTTP failures using `HttpCalloutMock`. The two examples provide concrete implementations.
