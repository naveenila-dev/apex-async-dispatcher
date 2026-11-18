public with sharing class AADOperationRegistry {
  public interface Provider {
    AAD_Operation__mdt find(String operationKey);
  }

  private class MetadataProvider implements Provider {
    public AAD_Operation__mdt find(String operationKey) {
      return AAD_Operation__mdt.getInstance(operationKey);
    }
  }

  @TestVisible
  private static Provider provider = new MetadataProvider();

  public static AADOperationConfig resolve(String operationKey) {
    if (String.isBlank(operationKey)) {
      throw new AADException('An operationKey is required.');
    }
    AAD_Operation__mdt registration = provider.find(operationKey);
    if (registration == null) {
      throw new AADException(
        'No async operation is registered for ' + operationKey + '.'
      );
    }
    if (registration.Enabled__c != true) {
      throw new AADException(
        'Async operation ' + operationKey + ' is disabled.'
      );
    }
    Decimal delay = registration.Delay_Minutes__c;
    if (
      delay == null ||
      delay < 0 ||
      delay > 10 ||
      delay != delay.setScale(0)
    ) {
      throw new AADException(
        'Operation ' +
          operationKey +
          ' requires a whole-number delay from 0 to 10 minutes.'
      );
    }
    AADOperationConfig config = new AADOperationConfig();
    config.operationKey = registration.DeveloperName;
    config.handlerClassName = registration.Handler_Class__c;
    config.handlerNamespace = String.isBlank(registration.Handler_Namespace__c)
      ? null
      : registration.Handler_Namespace__c;
    config.delayMinutes = delay.intValue();
    config.validate();
    return config;
  }
}