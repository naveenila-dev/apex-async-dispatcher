@IsTest
private class AADExampleCalloutHandlerTest {
  private static AADRequest request() {
    AADRequest request = new AADRequest();
    request.operationKey = 'EXAMPLE_HTTP_CALLOUT';
    request.payloadJson = '{"message":"Hello"}';
    return request;
  }

  private class Mock implements HttpCalloutMock {
    private Integer status;
    Mock(Integer status) {
      this.status = status;
    }
    public HttpResponse respond(HttpRequest outbound) {
      System.assertEquals(
        'callout:AAD_Example_API/events',
        outbound.getEndpoint()
      );
      System.assertEquals('POST', outbound.getMethod());
      System.assertEquals(
        'application/json',
        outbound.getHeader('Content-Type')
      );
      System.assertEquals(
        'Hello',
        ((Map<String, Object>) JSON.deserializeUntyped(outbound.getBody()))
          .get('message')
      );
      HttpResponse response = new HttpResponse();
      response.setStatusCode(status);
      response.setBody('Sensitive response must not be included in errors');
      return response;
    }
  }

  private class FailingMock implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest outbound) {
      throw new CalloutException('Simulated timeout');
    }
  }

  @IsTest
  static void dispatchesThroughRealMetadataWithMockedHttp() {
    Test.setMock(HttpCalloutMock.class, new Mock(201));
    Test.startTest();
    AADDispatcher.submit(request());
    System.assertEquals(1, Limits.getQueueableJobs());
    Test.stopTest();
  }

  @IsTest
  static void acceptsSuccessStatusBoundaries() {
    for (Integer status : new List<Integer>{ 200, 299 }) {
      Test.setMock(HttpCalloutMock.class, new Mock(status));
      AADRequest request = request();
      new AADExampleCalloutHandler()
        .execute(request, new AADExecutionContext(null, request));
    }
  }

  @IsTest
  static void propagatesHttpFailuresWithoutResponseBodies() {
    for (Integer status : new List<Integer>{ 199, 300, 400, 500 }) {
      Test.setMock(HttpCalloutMock.class, new Mock(status));
      AADRequest request = request();
      try {
        new AADExampleCalloutHandler()
          .execute(request, new AADExecutionContext(null, request));
        System.assert(false, 'Expected non-2xx response to fail.');
      } catch (AADException error) {
        System.assertEquals(
          'Example API returned HTTP ' + status + '.',
          error.getMessage()
        );
      }
    }
  }

  @IsTest
  static void propagatesTransportFailure() {
    Test.setMock(HttpCalloutMock.class, new FailingMock());
    AADRequest request = request();
    try {
      new AADExampleCalloutHandler()
        .execute(request, new AADExecutionContext(null, request));
      System.assert(false, 'Expected transport failure.');
    } catch (CalloutException error) {
      System.assertEquals('Simulated timeout', error.getMessage());
    }
  }

  @IsTest
  static void rejectsInvalidPayloadsBeforeSubmission() {
    AADRequest request = request();
    for (
      String payload : new List<String>{
        null,
        'null',
        '{}',
        '[]',
        '{invalid',
        '{"message":" "}',
        '{"message":"ok","unknown":true}',
        '{"message":true}'
      }
    ) {
      request.payloadJson = payload;
      reject(request);
    }
    request.payloadJson = '{"message":"Hello"}';
    request.payloadVersion = 2;
    reject(request);
    request.payloadVersion = 1;
    request.recordIds.add('001000000000001');
    reject(request);
  }

  private static void reject(AADRequest request) {
    Integer before = Limits.getQueueableJobs();
    try {
      AADDispatcher.submit(request);
      System.assert(false, 'Expected invalid HTTP request to fail.');
    } catch (AADException error) {
      System.assertNotEquals(null, error.getMessage());
    }
    System.assertEquals(before, Limits.getQueueableJobs());
  }
}
