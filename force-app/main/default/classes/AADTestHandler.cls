/** Test-only dynamically instantiated implementation; not an application handler. */
@IsTest
public class AADTestHandler implements AADHandler {
    public void validate(AADRequest request) {
        if (request.payloadVersion != 1) {
            throw new AADException('Unsupported test payload version.');
        }
        if (request.payloadJson == null) {
            return;
        }
        Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(request.payloadJson);
        if (payload.get('reject') == true) {
            throw new AADException('Rejected by test handler.');
        }
    }

    public void execute(AADRequest request, AADExecutionContext context) {
        System.assertEquals('TEST_OPERATION', request.operationKey);
        System.assertEquals(request.operationKey, context.operationKey);
        System.assertEquals(request.correlationId, context.correlationId);
        System.assertNotEquals(null, context.jobId);
        if (request.payloadJson == null) {
            return;
        }
        Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(request.payloadJson);
        if (payload.get('fail') == true) {
            throw new AADException('Execution failed in test handler.');
        }
        if (payload.get('callout') == true) {
            HttpRequest httpRequest = new HttpRequest();
            httpRequest.setEndpoint('https://example.invalid/aad-test');
            httpRequest.setMethod('GET');
            httpRequest.setHeader('X-Correlation-Id', context.correlationId);
            httpRequest.setHeader('X-Operation-Key', context.operationKey);
            httpRequest.setHeader('X-Job-Id', String.valueOf(context.jobId));
            HttpResponse response = new Http().send(httpRequest);
            System.assertEquals(200, response.getStatusCode());
            System.assertEquals('ok', response.getBody());
        }
    }
}
