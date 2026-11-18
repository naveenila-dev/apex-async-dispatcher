public interface AADHandler {
  // Must be deterministic and have no DML, callouts, enqueueing, or other side effects.
  void validate(AADRequest request);
  void execute(AADRequest request, AADExecutionContext context);
}