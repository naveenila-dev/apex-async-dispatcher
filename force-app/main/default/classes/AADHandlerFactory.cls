public with sharing class AADHandlerFactory {
    public static AADHandler create(AADOperationConfig config) {
        if (config == null) {
            throw new AADException('Operation configuration is required.');
        }
        config.validate();
        Type handlerType = Type.forName(config.handlerNamespace, config.handlerClassName);
        if (handlerType == null) {
            throw new AADException('Handler class was not found for operation ' + config.operationKey + ': ' + config.handlerClassName);
        }
        Object instance;
        try {
            instance = handlerType.newInstance();
        } catch (Exception error) {
            throw new AADException(
                'Cannot instantiate handler ' + config.handlerClassName + '. A usable no-argument constructor is required.'
            );
        }
        if (!(instance instanceof AADHandler)) {
            throw new AADException('Handler ' + config.handlerClassName + ' must implement AADHandler.');
        }
        return (AADHandler) instance;
    }
}
