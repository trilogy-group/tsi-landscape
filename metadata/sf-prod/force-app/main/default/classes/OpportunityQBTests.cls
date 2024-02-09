@IsTest
public with sharing class OpportunityQBTests {
    @IsTest
    static void disableAndEnableOpportunityQBTest() {
        Account acct = new Account(Name = 'Test Account');
        insert acct;

        //Opportunity without Type and without NetSuiteId, should not create if validation rules are active
        Opportunity opp = new Opportunity(Name = 'Opportunity',
                StageName = 'Pending',
                CloseDate = System.today().addMonths(1),
                AccountId = acct.Id,
                Product__c = 'DNN');

        OpportunityQBDisable.execute();
        insert opp;
        List<Opportunity> oppsList = [SELECT Id FROM opportunity];
        System.assertEquals(1, oppsList.size(), 'An opportunity should be created with QBs disabled.');
        delete opp;
        
        OpportunityQBEnable.execute();
        String errorMessage = null;
        try {
            insert opp;
        } catch (Exception ex) {
            errorMessage = ex.getMessage();
        }
        System.assertNotEquals(null, errorMessage, 
            'An error should have occurred trying to insert opportunity with QBs enabled.');
        oppsList = [SELECT Id FROM opportunity];
        System.assertEquals(0, oppsList.size(), 'An opportunity should not be created with QBs enabled.');
    }
}