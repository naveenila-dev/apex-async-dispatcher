/** Serializable envelope. Business payloads belong to individual handlers. */
public class AADRequest {
    public String operationKey;
    public List<Id> recordIds = new List<Id>();
    public String payloadJson;
    public Integer payloadVersion = 1;
    public String correlationId;

    public void validateEnvelope() {
        if (String.isBlank(operationKey)) {
            throw new AADException('An operationKey is required.');
        }
        if (payloadVersion == null || payloadVersion < 1) {
            throw new AADException('payloadVersion must be a positive integer.');
        }
        if (recordIds != null && recordIds.contains(null)) {
            throw new AADException('recordIds must not contain null IDs.');
        }
        if (payloadJson != null) {
            try {
                JSON.deserializeUntyped(payloadJson);
            } catch (Exception error) {
                throw new AADException('payloadJson must contain valid JSON when supplied.');
            }
        }
    }

    public AADRequest copy() {
        return (AADRequest) JSON.deserialize(JSON.serialize(this), AADRequest.class);
    }
}
