/** Example: overwrites Account.Description using all-or-none user-mode DML. */
public with sharing class AADExampleAccountHandler implements AADHandler {
  public class Payload {
    public String description;
  }

  public void validate(AADRequest request) {
    request.validateEnvelope();
    if (request.payloadVersion != 1) {
      throw new AADException('The Account example supports payloadVersion 1.');
    }
    if (
      request.recordIds == null ||
      request.recordIds.isEmpty() ||
      request.recordIds.size() > 200
    ) {
      throw new AADException('Supply 1 to 200 unique Account IDs.');
    }
    Set<Id> uniqueIds = new Set<Id>(request.recordIds);
    if (uniqueIds.size() != request.recordIds.size()) {
      throw new AADException('Supply unique Account IDs.');
    }
    for (Id recordId : request.recordIds) {
      if (recordId.getSObjectType() != Account.SObjectType) {
        throw new AADException('Only Account IDs are supported.');
      }
    }
    Payload payload = parse(request.payloadJson);
    if (payload.description == null || payload.description.length() > 32000) {
      throw new AADException(
        'Supply a description of at most 32000 characters.'
      );
    }
  }

  public void execute(AADRequest request, AADExecutionContext context) {
    validate(request);
    Payload payload = parse(request.payloadJson);
    List<Account> updates = new List<Account>();
    for (Id recordId : request.recordIds) {
      updates.add(
        new Account(Id = recordId, Description = payload.description)
      );
    }
    Database.update(updates, true, AccessLevel.USER_MODE);
  }

  private static Payload parse(String payloadJson) {
    Payload payload;
    try {
      Object decoded = JSON.deserializeUntyped(payloadJson);
      if (!(decoded instanceof Map<String, Object>)) {
        throw new AADException('Expected a JSON object.');
      }
      Object value = ((Map<String, Object>) decoded).get('description');
      if (!(value instanceof String)) {
        throw new AADException('Expected a string description.');
      }
      payload = (Payload) JSON.deserializeStrict(payloadJson, Payload.class);
    } catch (Exception error) {
      throw new AADException(
        'The Account payload must be a JSON object with a description.'
      );
    }
    if (payload == null) {
      throw new AADException('The Account payload is required.');
    }
    return payload;
  }
}
