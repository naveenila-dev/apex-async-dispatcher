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

## GitHub Actions

Every push and pull request runs offline checks, formatting, and Salesforce metadata conversion. Enable Apex integration CI by setting repository variable `AAD_RUN_APEX_TESTS` to `true` and repository secret `SF_DEV_HUB_AUTH_URL` to a Dev Hub SFDX authorization URL. Treat this URL as a credential. The Hub must support scratch org creation and have available allocation.

The Apex job runs only on pushes and manual dispatches, creates a clean one-day scratch org, deploys/tests core independently, deploys/tests examples, uploads results, and deletes the org even after failures. Pull requests do not receive Dev Hub credentials. If Apex CI is disabled, its skipped status is not evidence that Apex tests passed.

Keep core business-independent, preserve the public request/handler contract, include meaningful failure tests, and document behavior changes in `CHANGELOG.md`. Do not add retries or durable queues without defining idempotency and transaction behavior first.
