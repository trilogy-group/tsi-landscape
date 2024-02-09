@isTest
public with sharing class MarkOverdueOppAsDraftTests {

    private static Opportunity insertOpportunity(Date renewalDate) {
        User user = TestData.getUser('System Administrator');
        Opportunity opp = new Opportunity(
                Name = 'Test Opportunity',
                StageName = 'Proposal',
                CloseDate = renewalDate.addDays(-1),
                Type = 'Renewal',
                OwnerId = user.Id,
                NetSuite_ID__c = '1234',
                Parent_Subscription_ID__c = 'A-S00000000',
                Product__c = 'Acorn',
                Renewal_Date__c = renewalDate
        );

        return opp;
    }

    @isTest
    static void draftShouldBeTrueForOpporunityRenewalPassed() {
        //Arrange
        Opportunity opp = insertOpportunity(System.now().date().addDays(-7));

        //Act
        Insert opp;
        Opportunity retrievedOpp = [select Id, Draft__c from Opportunity];

        //Assert
        System.assert(retrievedOpp.Draft__c, 'Draft flag should be set to true');
    }


    @isTest
    static void draftShouldBeTrueForOpporunityRenewalToday() {
        //Arrange
        Opportunity opp = insertOpportunity(System.now().date());

        //Act
        Insert opp;
        Opportunity retrievedOpp = [select Id, Draft__c from Opportunity];

        //Assert
        System.assert(retrievedOpp.Draft__c, 'Draft flag should be set to true');
    }

    @isTest
    static void draftShouldBeFalseForOpporunityRenewalFuture() {
          //Arrange
        Opportunity opp = insertOpportunity(System.now().date().addDays(7) );

        //Act
        Insert opp;
        Opportunity retrievedOpp = [select Id, Draft__c from Opportunity];

        //Assert
        System.assert(!retrievedOpp.Draft__c, 'Draft flag should be set to false');
    }
    
}