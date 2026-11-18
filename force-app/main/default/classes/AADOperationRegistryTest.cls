@IsTest
private class AADOperationRegistryTest {
  @IsTest
  static void resolvesEnabledOperationAndSnapshotsConfiguration() {
    AAD_Operation__mdt row = AADTestSupport.registration();
    row.Handler_Namespace__c = ' ';
    row.Delay_Minutes__c = 10;
    AADOperationRegistry.provider = new AADTestSupport.Provider(row);
    AADOperationConfig config = AADOperationRegistry.resolve('TEST_OPERATION');
    System.assertEquals('AADTestHandler', config.handlerClassName);
    System.assertEquals(null, config.handlerNamespace);
    System.assertEquals(10, config.delayMinutes);
    row.Handler_Class__c = 'ChangedAfterLookup';
    System.assertEquals('AADTestHandler', config.handlerClassName);
  }

  @IsTest
  static void rejectsMissingDisabledAndMalformedRegistrations() {
    expectFailure(null, ' ', 'operationKey');
    expectFailure(null, 'MISSING', 'No async operation');
    AAD_Operation__mdt row = AADTestSupport.registration();
    row.Enabled__c = false;
    expectFailure(row, 'TEST_OPERATION', 'disabled');
    row.Enabled__c = true;
    row.Handler_Class__c = null;
    expectFailure(row, 'TEST_OPERATION', 'handler class');
    row.Handler_Class__c = 'AADTestHandler';
    row.Handler_Namespace__c = 'invalid.namespace';
    expectFailure(row, 'TEST_OPERATION', 'namespace');
    row.Handler_Namespace__c = null;
    for (Decimal delay : new List<Decimal>{ null, -1, 11, 0.5 }) {
      row.Delay_Minutes__c = delay;
      expectFailure(row, 'TEST_OPERATION', 'whole-number delay');
    }
  }

  @IsTest
  static void defaultProviderReturnsNoRecordForUnknownKey() {
    // Exercises actual getInstance without depending on any deployed registrations.
    try {
      AADOperationRegistry.resolve('AAD_NONEXISTENT_TEST_OPERATION');
      System.assert(false, 'An unregistered operation must fail.');
    } catch (AADException error) {
      System.assert(
        error.getMessage().contains('No async operation'),
        error.getMessage()
      );
    }
  }

  private static void expectFailure(
    AAD_Operation__mdt row,
    String key,
    String fragment
  ) {
    AADOperationRegistry.provider = new AADTestSupport.Provider(row);
    try {
      AADOperationRegistry.resolve(key);
      System.assert(false, 'Expected configuration rejection.');
    } catch (AADException error) {
      System.assert(error.getMessage().contains(fragment), error.getMessage());
    }
  }
}