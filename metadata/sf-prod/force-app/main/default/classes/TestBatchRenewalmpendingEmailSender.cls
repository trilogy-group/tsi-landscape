@isTest
public class TestBatchRenewalmpendingEmailSender {
    @TestSetup
    static void makeData() {
        TestData.createOpportunityForCPQDocument('Renewal','ACRM');
        TestData.createDummyTemplate(true);                                    
    }
    @isTest static void testBatchwithValidOpportunity() {
        // Prepare Test Data
        OpportunityQBDisable.execute();
        Opportunity testOpp = [SELECT Id, Renewal_Date__c, CloseDate,Customer_Termination_Notice_Period__c,
                                SBQQ__PrimaryQuote__c,AR_Quote__c,Product_Configuration__c 
                                FROM Opportunity Limit 1];
        testOpp.Renewal_Date__c = Date.today()+44;
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
        // Start the test
        Test.startTest();
        BatchRenewalmpendingEmailSender batchInstance = new BatchRenewalmpendingEmailSender();
        Database.executeBatch(batchInstance,1);
        Test.stopTest();
        List<ApexLogger__c> lstLogs = [SELECT Id,Exception_Message__c,Stack_Trace_String__c from ApexLogger__c];
        String error ='';
        if(lstLogs!=null && !lstLogs.isEmpty()) {
            error+='Error message:'+lstLogs[0].Exception_Message__c+'\n';
            error+='Stack Trace: '+lstLogs[0].Stack_Trace_String__c;
        }
        System.assertEquals(0, lstLogs.size(),error);
        //Cannot assert emails in test class
        
    }
    @isTest static void testBatchWithInvalidOpportunity() {
        // Prepare Test Data
        OpportunityQBDisable.execute();
        Opportunity testOpp = [SELECT Id, Renewal_Date__c, CloseDate,
                                Customer_Termination_Notice_Period__c,Product_Configuration__c 
                                FROM Opportunity Limit 1];
        testOpp.Renewal_Date__c = Date.today()+44;
        testOpp.CloseDate = Date.today()+10;
        testOpp.CurrentContractHasAutoRenewalClause__c = 'Yes';
        testOpp.Customer_Termination_Notice_Period__c = 0;
        update testOpp;
        Product_Configuration__c config = new Product_Configuration__c(
                                            Id=testOpp.Product_Configuration__c,
                                            Mailbox_Override__c='ignitetech.com',
                                            Renewal_Enabled__c=true);
        update config;
        List<OpportunityContactRole> lstOCR = [SELECT Id,ContactId FROM OpportunityContactRole 
                                                WHERE opportunityId =:testOpp.Id
                                               AND isPrimary = true];
        delete lstOCR;
        // Start the test
        Test.startTest();
        BatchRenewalmpendingEmailSender batchInstance = new BatchRenewalmpendingEmailSender();
        Database.executeBatch(batchInstance,1);
        Test.stopTest();
        //Cannot assert emails in test class
    }
    @isTest static void testBatchWithSkippableOpportunity() {
        OpportunityQBDisable.execute();
        Opportunity testOpp = [SELECT Id, Renewal_Date__c, CloseDate,
                                Customer_Termination_Notice_Period__c,Product_Configuration__c 
                                FROM Opportunity Limit 1];
        testOpp.Renewal_Date__c = Date.today()+44;
        testOpp.Customer_Termination_Notice_Period__c = 0;
        testOpp.CloseDate = Date.today()+10;
        testOpp.CurrentContractHasAutoRenewalClause__c = 'Yes';
        testOpp.StageName='Finalizing';
        testOpp.Loss_Reason__c ='Product Issues';
        testOpp.Loss_Reason_Notes__c = 'Product Issues';
        update testOpp;
        Product_Configuration__c config = new Product_Configuration__c(
                                            Id=testOpp.Product_Configuration__c,
                                            Mailbox_Override__c='ignitetech.com',
                                            Renewal_Enabled__c=true);
        update config;
        // Start the test
        Test.startTest();
        BatchRenewalmpendingEmailSender batchInstance = new BatchRenewalmpendingEmailSender();
        Database.executeBatch(batchInstance,1);
        Test.stopTest();
        //Cannot assert emails in test class
    }
    @isTest static void testGeneralUtility() {
        Opportunity testOpp = [SELECT Id, OwnerId 
                                FROM Opportunity Limit 1];
        List<OpportunityChatterWrapper> lstChatterMsgs = new List<OpportunityChatterWrapper>();
        List<String> lstUserIds = new List<String>();
        lstUserIds.add(testOpp.OwnerId);
        OpportunityChatterWrapper ocw = new OpportunityChatterWrapper();
        ocw.opportunityId = testOpp.Id;
        ocw.userIds = lstUserIds;
        ocw.customMessage = 'Test Chatter Message';
        lstChatterMsgs.add(ocw);
        if(lstChatterMsgs!=null && !lstChatterMsgs.isEmpty()) {
            GeneralUtility.postChatterInBulk(lstChatterMsgs);
        }
        try{
            Integer i = 1/0;
        } catch(Exception ex) {
            GeneralUtility.logApexException(ex,'Test message');
        }
    }
}