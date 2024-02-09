@isTest
public class GetSubscriptionItemsFromNetsuiteTest {
    @isTest
    static void testGetNetSuiteData() {
        String requestParam = 'subscription_id_test';
        List<String> requestParams = new List<String>{requestParam};

        // Prepare
        NetsuiteKeys__c testKeys = new NetsuiteKeys__c();
        testKeys.ConsumerKey__c = 'consumer_key_test';
        testKeys.ConsumerSecret__c = 'consumer_secret_test';
        testKeys.TokenKey__c = 'token_key_test';
        testKeys.TokenSecret__c = 'token_secret_test';
        insert testKeys;

        String mockResponseBody = '{"content":{"items":[{"bundleCode":"Test Bundle","code":"Test Code",' + 
            '"supportCode":"Test Support","quantity":10,"isMainItem":true,"ARR":100.0}]}}';
        // Instantiate the HttpCalloutMock and set it in the test context
        Test.setMock(HttpCalloutMock.class, new GetSubscriptionItemsFromNetsuiteMock(mockResponseBody));

        Test.startTest();

        // Call the method to test
        List<List<SubscriptionItem>> results = GetSubscriptionItemsFromNetsuite.getNetSuiteData(requestParams);
        Test.stopTest();

        System.assertNotEquals(null, results, 'Results should not be null.');
        System.assertEquals(1, results.size(), 'There should be one list of subscription items.');
        System.assertEquals(1, results[0].size(), 'There should be one subscription item in the list.');
        System.assertEquals('Test Bundle', results[0][0].bundleCode, 'Bundle code should match the mock response.');
        System.assertEquals('Test Code', results[0][0].code, 'Code should match the mock response.');
        System.assertEquals('Test Support', results[0][0].supportCode, 'Support code should match the mock response.');
        System.assertEquals(10, results[0][0].quantity, 'Quantity should match the mock response.');
        System.assertEquals(true, results[0][0].isMainItem, 'Is main item flag should match the mock response.');
    }
}