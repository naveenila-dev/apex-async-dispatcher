@IsTest
private class AADQueueableTest {
    @IsTest
    static void snapshotsInputsAndPropagatesExecutionContext() {
        AADRequest request = AADTestSupport.request();
        request.payloadJson = '{"callout":true}';
        AADOperationConfig config = AADTestSupport.config();
        AADQueueable worker = new AADQueueable(request, config);
        request.operationKey = 'CHANGED';
        request.correlationId = 'changed';
        config.handlerClassName = 'MissingAfterSubmission';
        Test.setMock(HttpCalloutMock.class, new AADTestSupport.CalloutMock());
        worker.execute(new AADTestSupport.Context());
    }

    @IsTest
    static void propagatesHandlerFailuresAndRevalidatesPayload() {
        AADRequest request = AADTestSupport.request();
        request.payloadJson = '{"fail":true}';
        expectExecutionFailure(request, AADTestSupport.config(), 'Execution failed');
        request.payloadJson = '{"reject":true}';
        expectExecutionFailure(request, AADTestSupport.config(), 'Rejected by test handler');
        request.payloadJson = '{invalid';
        expectExecutionFailure(request, AADTestSupport.config(), 'valid JSON');
        request.payloadJson = null;
        request.operationKey = 'DIFFERENT';
        expectExecutionFailure(request, AADTestSupport.config(), 'does not match');
    }

    @IsTest
    static void requiresConstructorInputs() {
        try {
            new AADQueueable(null, AADTestSupport.config());
            System.assert(false, 'Null request must be rejected.');
        } catch (AADException error) {
            System.assert(error.getMessage().contains('required'));
        }
        try {
            new AADQueueable(AADTestSupport.request(), null);
            System.assert(false, 'Null config must be rejected.');
        } catch (AADException error) {
            System.assert(error.getMessage().contains('required'));
        }
    }

    private static void expectExecutionFailure(AADRequest request, AADOperationConfig config, String fragment) {
        try {
            new AADQueueable(request, config).execute(new AADTestSupport.Context());
            System.assert(false, 'Worker must propagate failures.');
        } catch (AADException error) {
            System.assert(error.getMessage().contains(fragment), error.getMessage());
        }
    }
}
