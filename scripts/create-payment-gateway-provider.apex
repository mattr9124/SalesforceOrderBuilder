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
                        'DeveloperName' => 'Adyen',
                        'MasterLabel' => 'Adyen',
                        'ApexAdapterId' => '01p5300000F8KGkAAN'
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