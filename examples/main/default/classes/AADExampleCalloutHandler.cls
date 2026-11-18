/** Example: configure the AAD_Example_API Named Credential before use. */
public with sharing class AADExampleCalloutHandler implements AADHandler {
  public class Payload {
    public String message;
  }

  public void validate(AADRequest request) {
    request.validateEnvelope();
    if (request.payloadVersion != 1) {
      throw new AADException('The HTTP example supports payloadVersion 1.');
    }
    if (request.recordIds != null && !request.recordIds.isEmpty()) {
      throw new AADException('The HTTP example does not accept record IDs.');
    }
    Payload payload = parse(request.payloadJson);
    if (String.isBlank(payload.message)) {
      throw new AADException('The HTTP payload requires a nonblank message.');
    }
  }

  public void execute(AADRequest request, AADExecutionContext context) {
    validate(request);
    HttpRequest outbound = new HttpRequest();
    outbound.setEndpoint('callout:AAD_Example_API/events');
    outbound.setMethod('POST');
    outbound.setTimeout(30000);
    outbound.setHeader('Content-Type', 'application/json');
    outbound.setBody(JSON.serialize(parse(request.payloadJson)));
    HttpResponse response = new Http().send(outbound);
    if (response.getStatusCode() < 200 || response.getStatusCode() >= 300) {
      throw new AADException(
        'Example API returned HTTP ' + response.getStatusCode() + '.'
      );
    }
  }

  private static Payload parse(String payloadJson) {
    Payload payload;
    try {
      Object decoded = JSON.deserializeUntyped(payloadJson);
      if (!(decoded instanceof Map<String, Object>)) {
        throw new AADException('Expected a JSON object.');
      }
      Object value = ((Map<String, Object>) decoded).get('message');
      if (!(value instanceof String)) {
        throw new AADException('Expected a string message.');
      }
      payload = (Payload) JSON.deserializeStrict(payloadJson, Payload.class);
    } catch (Exception error) {
      throw new AADException(
        'The HTTP payload must be a JSON object with a message.'
      );
    }
    if (payload == null) {
      throw new AADException('The HTTP payload is required.');
    }
    return payload;
  }
}
