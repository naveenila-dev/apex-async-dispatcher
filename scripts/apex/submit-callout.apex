// Deploy examples and configure the AAD_Example_API Named Credential first.
AADRequest request = new AADRequest();
request.operationKey = 'EXAMPLE_HTTP_CALLOUT';
request.payloadVersion = 1;
request.payloadJson = JSON.serialize(new Map<String, Object>{ 'message' => 'Hello' });
request.correlationId = 'example-callout';
Id jobId = AADDispatcher.submit(request);
System.assertNotEquals(null, jobId, 'Submission outside test context must return a job ID.');
System.debug('Submitted job: ' + jobId);
