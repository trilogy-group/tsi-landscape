@isTest
public class AccountRollupBatchTest {

    @TestSetup
    static void makeData() {
        TestData.ArrangeReturn data = TestData.createOppAndContract();
    }
    @isTest
    static void testAccountRollupBatch() {
        
        Test.startTest();
        List<Opportunity> lstOpportunity = new List<Opportunity>();
        lstOpportunity = [SELECT Id, MRR__c, StageName, Purchase_Order__c,AccountId,Renewal_Date__c,Product__c,Success_Level__c from Opportunity];
        lstOpportunity[0].MRR__c = 100;
        lstOpportunity[0].Purchase_Order__c = 'Not Required';
        lstOpportunity[0].StageName = 'Closed Won';
        lstOpportunity[0].Renewal_Date__c = Date.today()-1;
        lstOpportunity[0].Product__c = 'ACRM';
        lstOpportunity[0].Success_Level__c = 'Platinum';
        OpportunityQBDisable.execute();
        update lstOpportunity;
        OpportunityQBEnable.execute();
        // Execute Batch
        AccountRollupBatch processor = new AccountRollupBatch();
        String sch ='0 1 * * * ?';
        Id batchId = System.schedule('Batch Scheduled',sch,processor);
        Database.executeBatch(processor,50);
        Test.stopTest();
        
        // Asserts
        List<Account> updatedAccounts = [SELECT Id, ARR__c, Product_families__c,Success_Level__c FROM Account where Id = :lstOpportunity[0].AccountId];
        System.assertEquals('ACRM', updatedAccounts[0].Product_families__c, 'Testing Product Families');
        //System.assertEquals(1200.0, updatedAccounts[0].ARR__c,'Testing ARR value');
        System.assertEquals('Platinum',updatedAccounts[0].Success_Level__c,'Testing Success Level');
    }
}