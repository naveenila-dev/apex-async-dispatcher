@IsTest
private class AADHandlerFactoryTest {
  @IsTest
  static void instantiatesRegisteredHandler() {
    System.assert(
      AADHandlerFactory.create(
        AADTestSupport.config()
      ) instanceof AADTestHandler
    );
  }

  @IsTest
  static void rejectsUnusableTypes() {
    expectFailure(null, 'configuration is required');
    AADOperationConfig config = AADTestSupport.config();
    config.handlerClassName = 'AADMissingHandler';
    expectFailure(config, 'not found');
    config.handlerClassName = 'AADRequest';
    expectFailure(config, 'must implement AADHandler');
    // This production type has no no-argument constructor.
    config.handlerClassName = 'AADExecutionContext';
    expectFailure(config, 'no-argument constructor');
    config.handlerClassName = 'AADThrowingConstructorHandler';
    expectFailure(config, 'Cannot instantiate handler');
    config.handlerClassName = 'AADTestHandler';
    config.delayMinutes = 11;
    expectFailure(config, 'delay');
    config.delayMinutes = 0;
    config.operationKey = null;
    expectFailure(config, 'operation key');
    config.operationKey = 'TEST_OPERATION';
    config.handlerClassName = 'Namespace.Handler';
    expectFailure(config, 'top-level handler');
  }

  private static void expectFailure(
    AADOperationConfig config,
    String fragment
  ) {
    try {
      AADHandlerFactory.create(config);
      System.assert(false, 'Expected handler resolution failure.');
    } catch (AADException error) {
      System.assert(error.getMessage().contains(fragment), error.getMessage());
    }
  }
}