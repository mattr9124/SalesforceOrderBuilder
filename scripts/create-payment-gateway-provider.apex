// CHANGE THESE AS NECESSARY!
final String DEVELOPER_NAME = 'Adyen';
final String MASTER_LABEL = 'Adyen';
final String APEX_CLASS_NAME = 'DummyPaymentGatewayAdapter';

Id apexAdapterId = [SELECT Id FROM ApexClass WHERE Name = :APEX_CLASS_NAME LIMIT 1].Id;

String baseUrl = URL.getSalesforceBaseUrl().toExternalForm();
String version = 'v58.0';
String serviceUrlTemplate = '{0}/services/data/{1}/sobjects/PaymentGatewayProvider';

String endpointUrl = String.format(serviceUrlTemplate, new Object []{
        baseUrl, version
});

Http http = new Http();

HttpRequest httpRequest = new HttpRequest();
httpRequest.setMethod('POST');
httpRequest.setEndpoint(endpointUrl);
httpRequest.setHeader('Content-Type', 'application/json');
httpRequest.setBody(
        JSON.serialize(
                new Map<String, Object> {
                        'DeveloperName' => DEVELOPER_NAME,
                        'MasterLabel' => MASTER_LABEL,
                        'ApexAdapterId' => apexAdapterId
                }
        )
);

httpRequest.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId());

HttpResponse httpResponse = http.send(httpRequest);

System.debug(httpResponse.getStatus());
System.debug(
        JSON.serializePretty(
                JSON.deserializeUntyped(httpResponse.getBody()))
);