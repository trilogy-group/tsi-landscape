@isTest
public class TestBatchCallPostGridAPI {
    // Mock class for HTTP callouts
    private class MyHttpCalloutMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            // Create a mock HTTP response
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"success":true}');
            return res;
        }
    }
	@TestSetup
    static void makeData() {
        TestData.createOpportunityForCPQDocument('Renewal','ACRM');
        TestData.createDummyTemplate(true);                                    
    }
    @isTest static void testBatchCallPostGridAPIValidate() {
        // Prepare Test Data
        OpportunityQBDisable.execute();
        Opportunity testOpp = [SELECT Id, Renewal_Date__c, CloseDate,Customer_Termination_Notice_Period__c,
                                SBQQ__PrimaryQuote__c,AR_Quote__c,Product_Configuration__c 
                                FROM Opportunity Limit 1];
        testOpp.Renewal_Date__c = Date.today()+40;
        testOpp.CloseDate = Date.today()+10;
        testOpp.CurrentContractHasAutoRenewalClause__c = 'Yes';
        testOpp.Customer_Termination_Notice_Period__c = 0;
        testOpp.AR_Quote__c = testOpp.SBQQ__PrimaryQuote__c;
        update testOpp;
        Product_Configuration__c config = new Product_Configuration__c(
                                            Id=testOpp.Product_Configuration__c,
                                            Mailbox_Override__c='ignitetech.com',
                                            Renewal_Enabled__c=true);
        update config;
      
        // Set up the HTTP mock
        Test.setMock(HttpCalloutMock.class, new MyHttpCalloutMock());

        // Start the batch job
        Test.startTest();
        Set<String> recordIds = new Set<String>();
        recordIds.add(testOpp.id);
        batchCallPostGridAPI batchJob = new batchCallPostGridAPI(recordIds);
        Database.executeBatch(batchJob);
        Test.stopTest();
    }
    
    @isTest static void testBatchCallPostGridAPIValidatePartner() {
        // Prepare Test Data
        OpportunityQBDisable.execute();
        Opportunity testOpp = [SELECT Id, Renewal_Date__c, CloseDate,Customer_Termination_Notice_Period__c,
                                SBQQ__PrimaryQuote__c,AR_Quote__c,Product_Configuration__c 
                                FROM Opportunity Limit 1];
        testOpp.Renewal_Date__c = Date.today()+40;
        testOpp.CloseDate = Date.today()+10;
        testOpp.CurrentContractHasAutoRenewalClause__c = 'Yes';
        testOpp.Customer_Termination_Notice_Period__c = 0;
        testOpp.AR_Quote__c = testOpp.SBQQ__PrimaryQuote__c;
        update testOpp;
        Account testResellerAccount = new Account
                                    (Id = null, 
                                    Name = 'Test Reseller account', 
                                    BillingCountry = 'USA', 
                                    BillingCity = 'New York',
                                    BillingState ='New York',
                                    BillingStreet = 'Test Times Square Corner');
        insert testResellerAccount;
        OpportunityPartner oppyPartner = new OpportunityPartner
                                        (OpportunityId=testOpp.Id,
                                        AccountToId=testResellerAccount.Id,
                                        Role='Distributor');
        insert oppyPartner;
        
        Product_Configuration__c config = new Product_Configuration__c(
                                            Id=testOpp.Product_Configuration__c,
                                            Mailbox_Override__c='ignitetech.com',
                                            Renewal_Enabled__c=true);
        update config;
      
        // Set up the HTTP mock
        Test.setMock(HttpCalloutMock.class, new MyHttpCalloutMock());

        // Start the batch job
        Test.startTest();
        Set<String> recordIds = new Set<String>();
        recordIds.add(testOpp.id);
        batchCallPostGridAPI batchJob = new batchCallPostGridAPI(recordIds);
        Database.executeBatch(batchJob);
        Test.stopTest();
    }
}