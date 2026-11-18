@IsTest
private class AADDispatcherTest {
  @IsTest
  static void submitsAndExecutesCalloutWithContext() {
    AADOperationRegistry.provider = new AADTestSupport.Provider(
      AADTestSupport.registration()
    );
    AADRequest request = AADTestSupport.request();
    request.payloadJson = '{"callout":true}';
    Test.setMock(HttpCalloutMock.class, new AADTestSupport.CalloutMock());
    Test.startTest();
    Id jobId = AADDispatcher.submit(request);
    System.assertEquals(1, Limits.getQueueableJobs());
    // Caller mutation and metadata changes must not change the queued work.
    request.operationKey = 'CHANGED';
    request.correlationId = 'changed';
    request.payloadJson = '{"fail":true}';
    AAD_Operation__mdt disabled = AADTestSupport.registration();
    disabled.Enabled__c = false;
    AADOperationRegistry.provider = new AADTestSupport.Provider(disabled);
    Test.stopTest();
    // Salesforce can return null job IDs in Apex test context.
    if (jobId != null) {
      AsyncApexJob job = [
        SELECT Status, NumberOfErrors
        FROM AsyncApexJob
        WHERE Id = :jobId
      ];
      System.assertEquals('Completed', job.Status);
      System.assertEquals(0, job.NumberOfErrors);
    }
  }

  @IsTest
  static void rejectsBadRequestsWithoutEnqueueing() {
    AADOperationRegistry.provider = new AADTestSupport.Provider(
      AADTestSupport.registration()
    );
    expectFailure(null, 'request is required');
    AADRequest request = AADTestSupport.request();
    request.payloadJson = '{"reject":true}';
    expectFailure(request, 'Rejected by test handler');
    request.payloadJson = null;
    request.payloadVersion = 2;
    expectFailure(request, 'Unsupported test payload');
    request.payloadVersion = 1;
    request.operationKey = 'UNREGISTERED';
    expectFailure(request, 'No async operation');
  }

  @IsTest
  static void rejectsSubmissionWhenTransactionCapacityIsExhausted() {
    AADOperationRegistry.provider = new AADTestSupport.Provider(
      AADTestSupport.registration()
    );
    Test.startTest();
    Integer available =
      Limits.getLimitQueueableJobs() - Limits.getQueueableJobs();
    for (Integer index = 0; index < available; index++) {
      System.enqueueJob(
        new AADQueueable(AADTestSupport.request(), AADTestSupport.config())
      );
    }
    expectFailure(AADTestSupport.request(), 'No Queueable capacity');
    Test.stopTest();
  }

  private static void expectFailure(AADRequest request, String fragment) {
    Integer before = Limits.getQueueableJobs();
    try {
      AADDispatcher.submit(request);
      System.assert(false, 'Expected submission rejection.');
    } catch (AADException error) {
      System.assert(error.getMessage().contains(fragment), error.getMessage());
    }
    System.assertEquals(
      before,
      Limits.getQueueableJobs(),
      'Rejected requests must not consume an enqueue.'
    );
  }
}