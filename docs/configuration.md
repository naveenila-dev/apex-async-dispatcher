# Configuration reference

Custom Metadata Type: **`AAD_Operation__mdt`**, label **Async Operation**.

| Field | Metadata type | Meaning |
| --- | --- | --- |
| `DeveloperName` | Standard metadata record name | Stable operation key used by callers |
| `MasterLabel` | Standard label | Human-readable operation label |
| `Handler_Class__c` | Required Text(255) | Top-level class name, without namespace or inner-class qualification |
| `Handler_Namespace__c` | Optional Text(40) | Namespace supplied to `Type.forName(namespace, name)`; blank means no namespace |
| `Enabled__c` | Checkbox, default false | Allows new submissions |
| `Delay_Minutes__c` | Required Number(2,0), default 0 | Minimum delay, 0–10 minutes |

`AAD_Valid_Delay` enforces the delay range declaratively. Apex checks the range and integrality before converting the value to an Integer. All four custom fields use subscriber-controlled manageability to support configuration by the installing org.

Use stable uppercase operation names such as `GENERATE_DOCUMENT`. Changing `DeveloperName` changes the caller contract. The registry copies the registration's canonical `DeveloperName` into the submitted request.

Example source filename: `customMetadata/AAD_Operation.GENERATE_DOCUMENT.md-meta.xml`. Configure `Handler_Class__c` with an implementation such as `DocumentAsyncHandler`, not a service method name.

Metadata changes affect future submissions. To stop existing work, use Salesforce job administration; unchecking Enabled is not a cancellation mechanism. There is no execution-time metadata kill switch in this version.

Use metadata for operation configuration only. Credentials, payloads, execution status, retry counters, and logs do not belong in this type.

The core includes the **Async Operation Layout** for Setup configuration. Example registrations are installed only when the separate `examples` directory is deployed.
