/** Test fixture for a handler whose no-argument constructor fails. */
@IsTest
public class AADThrowingConstructorHandler implements AADHandler {
  public AADThrowingConstructorHandler() {
    throw new AADException('Simulated constructor failure.');
  }
  public void validate(AADRequest request) {
  }
  public void execute(AADRequest request, AADExecutionContext context) {
  }
}