@IsTest
private class AADRequestTest {
  @IsTest
  static void rejectsInvalidEnvelopes() {
    AADRequest request = AADTestSupport.request();
    request.operationKey = ' ';
    expectFailure(request, 'operationKey');
    request = AADTestSupport.request();
    request.payloadVersion = null;
    expectFailure(request, 'payloadVersion');
    request.payloadVersion = 0;
    expectFailure(request, 'payloadVersion');
    request = AADTestSupport.request();
    request.recordIds.add(null);
    expectFailure(request, 'null IDs');
    request = AADTestSupport.request();
    request.payloadJson = '{invalid';
    expectFailure(request, 'valid JSON');
  }

  @IsTest
  static void acceptsOptionalFieldsAndCopiesCollections() {
    AADRequest request = AADTestSupport.request();
    request.recordIds = null;
    request.validateEnvelope();
    request.recordIds = new List<Id>{ '001000000000001' };
    request.payloadJson = '{"nested":{"value":1}}';
    request.validateEnvelope();
    AADRequest snapshot = request.copy();
    request.recordIds.clear();
    request.payloadJson = '{}';
    System.assertEquals(1, snapshot.recordIds.size());
    System.assertEquals('{"nested":{"value":1}}', snapshot.payloadJson);
  }

  private static void expectFailure(AADRequest request, String fragment) {
    try {
      request.validateEnvelope();
      System.assert(false, 'Expected an invalid envelope to be rejected.');
    } catch (AADException error) {
      System.assert(error.getMessage().contains(fragment), error.getMessage());
    }
  }
}