# Security and access

Framework services and examples declare `with sharing` explicitly. That declaration alone is not a complete object/field-permission policy. Handlers must choose and enforce data-access requirements, using user-mode operations where appropriate. The example Account handler explicitly updates in user mode.

The framework is an Apex library, not an exposed REST, Lightning, or Flow API. It does not add an end-user permission set or grant access to business objects. If you later expose submission through a controller or invocable action, authorize permitted operations in that entry point and supply the required class and data permissions.

Metadata registration is an administrative trust boundary. Limit who can edit operation registrations and deploy Apex. Callers select registered operation keys, not arbitrary class names. Public worker constructors are implementation entry points, not a security barrier against other trusted Apex.

Use Named Credentials and External Credentials for integration authentication. Grant the executing user the necessary principal access. Do not place credentials or sensitive full-record snapshots in payloads, correlation IDs, or metadata.

The framework does not log payloads or HTTP response bodies. Handlers should likewise avoid exposing sensitive values in exception messages. Native Salesforce error details and job information may be visible to administrators.

Recheck current business state and access at execution time. Submission-time payload validation does not establish lasting authorization, record access, or external API availability. Pinning this project to Apex API 64.0 makes explicit security choices especially important across org release changes.
