@IsTest
public class AADTestSupport {
  public static AADRequest request() {
    AADRequest request = new AADRequest();
    request.operationKey = 'TEST_OPERATION';
    request.correlationId = 'test-correlation';
    return request;
  }

  public static AAD_Operation__mdt registration() {
    return new AAD_Operation__mdt(
      DeveloperName = 'TEST_OPERATION',
      MasterLabel = 'Test Operation',
      Handler_Class__c = 'AADTestHandler',
      Enabled__c = true,
      Delay_Minutes__c = 0
    );
  }

  public static AADOperationConfig config() {
    AADOperationConfig config = new AADOperationConfig();
    config.operationKey = 'TEST_OPERATION';
    config.handlerClassName = 'AADTestHandler';
    config.delayMinutes = 0;
    return config;
  }

  public class Provider implements AADOperationRegistry.Provider {
    private AAD_Operation__mdt registration;

    public Provider(AAD_Operation__mdt registration) {
      this.registration = registration;
    }

    public AAD_Operation__mdt find(String operationKey) {
      return registration != null &&
        registration.DeveloperName == operationKey
        ? registration
        : null;
    }
  }

  public class Context implements QueueableContext {
    public Id getJobId() {
      return '707000000000001';
    }
  }

  public class CalloutMock implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest request) {
      System.assertEquals(
        'https://example.invalid/aad-test',
        request.getEndpoint()
      );
      System.assertEquals(
        'test-correlation',
        request.getHeader('X-Correlation-Id')
      );
      System.assertEquals(
        'TEST_OPERATION',
        request.getHeader('X-Operation-Key')
      );
      System.assertNotEquals(null, request.getHeader('X-Job-Id'));
      HttpResponse response = new HttpResponse();
      response.setStatusCode(200);
      response.setBody('ok');
      return response;
    }
  }
}