public class AADExecutionContext {
  public Id jobId;
  public String operationKey;
  public String correlationId;

  public AADExecutionContext(Id jobId, AADRequest request) {
    this.jobId = jobId;
    this.operationKey = request.operationKey;
    this.correlationId = request.correlationId;
  }
}