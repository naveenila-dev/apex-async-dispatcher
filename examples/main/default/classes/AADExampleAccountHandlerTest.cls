@IsTest
private class AADExampleAccountHandlerTest {
  private static AADRequest request(List<Id> ids) {
    AADRequest request = new AADRequest();
    request.operationKey = 'EXAMPLE_ACCOUNT_UPDATE';
    request.recordIds = ids;
    request.payloadJson = '{"description":"Processed asynchronously"}';
    return request;
  }

  @IsTest
  static void dispatchesThroughRealMetadataAndUpdatesAccounts() {
    List<Account> accounts = new List<Account>();
    for (Integer index = 0; index < 200; index++) {
      accounts.add(new Account(Name = 'Example ' + index));
    }
    insert accounts;
    List<Id> ids = new List<Id>();
    for (Account account : accounts) {
      ids.add(account.Id);
    }
    AADOperationConfig config = AADOperationRegistry.resolve(
      'EXAMPLE_ACCOUNT_UPDATE'
    );
    System.assertEquals('AADExampleAccountHandler', config.handlerClassName);
    Test.startTest();
    AADDispatcher.submit(request(ids));
    System.assertEquals(1, Limits.getQueueableJobs());
    Test.stopTest();
    List<Account> updated = [SELECT Description FROM Account WHERE Id IN :ids];
    System.assertEquals(200, updated.size());
    for (Account account : updated) {
      System.assertEquals('Processed asynchronously', account.Description);
    }
  }

  @IsTest
  static void rejectsInvalidIdsAndPayloadsWithoutEnqueueing() {
    AADRequest request = request(new List<Id>());
    reject(request);
    request.recordIds = null;
    reject(request);
    request.recordIds = new List<Id>{ '003000000000001' };
    reject(request);
    request.recordIds = new List<Id>{ '001000000000001', '001000000000001' };
    reject(request);
    request.recordIds = new List<Id>{ null };
    reject(request);
    request.recordIds = new List<Id>();
    for (Integer index = 0; index < 201; index++) {
      request.recordIds.add('001000000000001');
    }
    reject(request);
    request.recordIds = new List<Id>{ '001000000000001' };
    for (
      String payload : new List<String>{
        null,
        'null',
        '{}',
        '[]',
        '{invalid',
        '{"description":"ok","unknown":true}',
        '{"description":true}'
      }
    ) {
      request.payloadJson = payload;
      reject(request);
    }
    request.payloadJson = '{"description":"ok"}';
    request.payloadVersion = 2;
    reject(request);
  }

  @IsTest
  static void rollsBackAllUpdatesWhenOneRecordIsMissing() {
    Account account = new Account(Name = 'Original', Description = 'Unchanged');
    Account missing = new Account(Name = 'Deleted');
    insert new List<Account>{ account, missing };
    delete missing;
    AADRequest request = request(new List<Id>{ account.Id, missing.Id });
    try {
      new AADExampleAccountHandler()
        .execute(request, new AADExecutionContext(null, request));
      System.assert(false, 'The missing record must fail all-or-none DML.');
    } catch (DmlException error) {
      System.assertNotEquals(null, error.getMessage());
    }
    System.assertEquals(
      'Unchanged',
      [SELECT Description FROM Account WHERE Id = :account.Id].Description
    );
  }

  private static void reject(AADRequest request) {
    Integer before = Limits.getQueueableJobs();
    try {
      AADDispatcher.submit(request);
      System.assert(false, 'Expected invalid Account request to fail.');
    } catch (AADException error) {
      System.assertNotEquals(null, error.getMessage());
    }
    System.assertEquals(before, Limits.getQueueableJobs());
  }
}
