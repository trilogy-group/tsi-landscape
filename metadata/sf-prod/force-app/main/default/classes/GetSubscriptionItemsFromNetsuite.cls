public class GetSubscriptionItemsFromNetsuite {
    // Method to call the NetSuite API
    @InvocableMethod(label='Get NetSuite Data Subscription' description='Fetches subscription data from NetSuite')
    public static List<List<SubscriptionItem>> getNetSuiteData(List<String> requestParams) {
        NetsuiteKeys__c keys = NetsuiteKeys__c.getOrgDefaults();
        String consumerKey = keys.ConsumerKey__c;
        String consumerSecret = keys.ConsumerSecret__c;
        String token = keys.TokenKey__c;
        String tokenSecret = keys.TokenSecret__c;

        // URL of the NetSuite restlet endpoint
        String instanceName = System.URL.getSalesforceBaseUrl().getHost();
        String realm = '4914352';
        if (instanceName.contains('sandbox')) {
            realm += '_SB2';
        }
        String baseUrl =  'https://' + realm.replace('_', '-').toLowerCase() +
            '.restlets.api.netsuite.com/app/site/hosting/restlet.nl';
        String script = 'script=customscript_si_main_main_restlet';
        String deploy = 'deploy=customdeploy_si_main_main';
        String url = baseUrl + '?' + script + '&' + deploy;

        String nonce = String.valueOf(Crypto.getRandomLong());
        String timestamp = String.valueOf(DateTime.now().getTime() / 1000);

        String parameterString = 
            deploy + '&' +
            'oauth_consumer_key=' + consumerKey + '&' +
            'oauth_nonce=' + nonce + '&' +
            'oauth_signature_method=' + 'HMAC-SHA256' + '&' +
            'oauth_timestamp=' + timestamp + '&' +
            'oauth_token=' + token + '&' +
            'oauth_version=1.0&' +
            script;

        // Encode each parameter in the parameter string
        String encodedParameterString = '';
        for (String parameter : parameterString.split('&')) {
            encodedParameterString += EncodingUtil.urlEncode(parameter.split('=')[0], 'UTF-8') + '=' +
                                      EncodingUtil.urlEncode(parameter.split('=')[1], 'UTF-8') + '&';
        }
        encodedParameterString = encodedParameterString.removeEnd('&');

        // create baseString to create signature
        String baseString = 
            'POST&' + 
            EncodingUtil.urlEncode(baseUrl, 'UTF-8') + '&' +
            EncodingUtil.urlEncode(parameterString, 'UTF-8');

        String key = EncodingUtil.urlEncode(consumerSecret, 'UTF-8') + '&' + 
                     EncodingUtil.urlEncode(tokenSecret, 'UTF-8');
        Blob hmacData = Crypto.generateMac('hmacSHA256', Blob.valueOf(baseString), Blob.valueOf(key));
        String signature = EncodingUtil.urlEncode(EncodingUtil.base64Encode(hmacData), 'UTF-8');

        String authHeader = 
            'OAuth realm="'+ realm + '", ' +
            'oauth_consumer_key="' + consumerKey + '", ' +
            'oauth_nonce="' + nonce + '", ' +
            'oauth_signature="' + signature + '", ' +
            'oauth_signature_method="HMAC-SHA256", ' +
            'oauth_timestamp="' + timestamp + '", ' +
            'oauth_token="' + token + '", ' +
            'oauth_version="1.0"';
        System.debug(authHeader);

        // Create a map with the data you want to send
        Map<String, String> dataMap = new Map<String, String>();
        dataMap.put('op', 'subscription.internalGetItems');
        dataMap.put('subscriptionId',requestParams[0]);

        // Define the HTTP request
        HttpRequest req = new HttpRequest();
        req.setEndpoint(url);
        req.setMethod('POST');
        req.setHeader('Authorization', authHeader);
        req.setTimeout(30000);

        // Convert the map to a JSON string and set it as the request body
        String jsonString = JSON.serialize(dataMap);
        req.setBody(jsonString);
        req.setHeader('Content-Type', 'application/json');

        // Execute the HTTP request
        Http http = new Http();
        HttpResponse res = http.send(req);
        System.debug(res.getStatusCode());
        System.debug(res.getBody());

        // Define a list to hold the returned data
        List<SubscriptionItem> responseData = new List<SubscriptionItem>();
        // Process the HTTP response
        if (res.getStatusCode() == 200) {
            // Parse the JSON response
            Map<String, Object> parsedData = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            Map<String, Object> content = (Map<String, Object>) parsedData.get('content');
            List<Object> items = (List<Object>) content.get('items');
            for (Object item : items) {
                string itemSerialized = JSON.serialize(item);
                SubscriptionItem subscriptionItem = (SubscriptionItem) JSON.deserialize(
                    itemSerialized, SubscriptionItem.class);
                responseData.add(subscriptionItem);
            }
        } else {
            System.debug('HTTP request failed with status code ' + res.getStatusCode());
        }
        Double totalARR = 0;
        for (SubscriptionItem item : responseData) {
            totalARR += item.ARR;
        }
        for (SubscriptionItem item : responseData) {
            item.percentARR = item.ARR / totalARR;
        }
        System.debug(responseData);
        // Return the list of data
        List<List<SubscriptionItem>> response = new List<List<SubscriptionItem>>();
        response.add(responseData);
        return response;
    }
}