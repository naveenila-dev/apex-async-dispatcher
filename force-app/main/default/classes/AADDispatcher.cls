public with sharing class AADDispatcher {
  public static Id submit(AADRequest request) {
    if (request == null) {
      throw new AADException('An async request is required.');
    }
    AADRequest snapshot = request.copy();
    snapshot.validateEnvelope();
    AADOperationConfig config = AADOperationRegistry.resolve(
      snapshot.operationKey
    );
    snapshot.operationKey = config.operationKey;
    AADHandler handler = AADHandlerFactory.create(config);
    handler.validate(snapshot);
    if (Limits.getQueueableJobs() >= Limits.getLimitQueueableJobs()) {
      throw new AADException(
        'No Queueable capacity remains in this transaction. The request was not submitted.'
      );
    }
    return System.enqueueJob(
      new AADQueueable(snapshot, config),
      config.delayMinutes
    );
  }
}