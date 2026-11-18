/** Value object captured at submission; it does not freeze deployed Apex code. */
public class AADOperationConfig {
    public String operationKey;
    public String handlerClassName;
    public String handlerNamespace;
    public Integer delayMinutes;

    public void validate() {
        if (String.isBlank(operationKey)) {
            throw new AADException('Operation configuration requires an operation key.');
        }
        if (String.isBlank(handlerClassName) || !Pattern.matches('[A-Za-z][A-Za-z0-9_]*', handlerClassName)) {
            throw new AADException('Operation ' + operationKey + ' requires a top-level handler class name without a namespace.');
        }
        if (!String.isBlank(handlerNamespace) && !Pattern.matches('[A-Za-z][A-Za-z0-9_]*', handlerNamespace)) {
            throw new AADException('Operation ' + operationKey + ' has an invalid handler namespace.');
        }
        if (delayMinutes == null || delayMinutes < 0 || delayMinutes > 10) {
            throw new AADException('Operation ' + operationKey + ' requires a delay from 0 to 10 minutes.');
        }
    }

    public AADOperationConfig copy() {
        return (AADOperationConfig) JSON.deserialize(JSON.serialize(this), AADOperationConfig.class);
    }
}
