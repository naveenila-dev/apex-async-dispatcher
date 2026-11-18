public with sharing class AADQueueable implements Queueable, Database.AllowsCallouts {
  private AADRequest request;
  private AADOperationConfig config;

  public AADQueueable(AADRequest request, AADOperationConfig config) {
    if (request == null || config == null) {
      throw new AADException(
        'A request and operation configuration are required.'
      );
    }
    this.request = request.copy();
    this.config = config.copy();
  }

  public void execute(QueueableContext context) {
    request.validateEnvelope();
    if (request.operationKey != config.operationKey) {
      throw new AADException(
        'The request operation does not match the captured configuration.'
      );
    }
    AADHandler handler = AADHandlerFactory.create(config);
    handler.validate(request);
    handler.execute(
      request,
      new AADExecutionContext(context.getJobId(), request)
    );
  }
}