# Contributing

Use Node.js 22+, Python 3.9+, Java 17+ (for the Apex formatter), and Salesforce CLI. Run commands from the repository root.

```sh
npm ci
npm test
npm run prettier:verify
```

`npm test` checks source structure, XML, API versions, example registrations, and local documentation links. It does not compile Apex. Format changes with `npm run prettier`; the commit hook runs source checks and verifies formatting.

## Salesforce verification

Use a clean development scratch org to avoid application triggers and org configuration influencing tests:

```sh
sf org login web --alias aad-hub --set-default-dev-hub
sf org create scratch --definition-file config/project-scratch-def.json --target-dev-hub aad-hub --alias aad-dev --duration-days 1 --wait 20
sf project deploy start --source-dir force-app --target-org aad-dev --api-version 64.0 --test-level RunLocalTests --wait 30
sf project deploy start --source-dir examples --target-org aad-dev --api-version 64.0 --test-level RunLocalTests --wait 30
sf apex run test --target-org aad-dev --test-level RunLocalTests --code-coverage --result-format human --wait 30
sf org delete scratch --target-org aad-dev --no-prompt
```

Salesforce documents that `System.enqueueJob` can return null in test context ([Queueable reference](https://developer.salesforce.com/docs/platform/apex-ref/references/apex-ref/apex-class-system-queueable.html)). Tests check enqueue consumption and handler effects, and inspect job status when an ID is available. To verify the returned ID outside tests, configure the example Named Credential and execute `sf apex run --file scripts/apex/submit-callout.apex --target-org aad-dev`; inspect the eventual outcome using `scripts/soql/jobs.soql`.

Deploy core first to verify it has no example dependency. Example tests use deployed Custom Metadata records and HTTP mocks; they do not require a live Named Credential. Account example tests create their own data and verify user-mode, all-or-none updates. Apex tests and compilation must pass before a release; offline checks alone cannot establish release readiness.

## Automation

This repository currently has no GitHub Actions workflow. Run the local and Salesforce verification commands above before releasing. If CI is added later, deploy and test core independently before deploying examples, and keep org credentials out of pull requests from untrusted branches.

Keep core business-independent, preserve the public request/handler contract, include meaningful failure tests, and document behavior changes in `CHANGELOG.md`. Do not add retries or durable queues without defining idempotency and transaction behavior first.
