@isTest
public with sharing class AdvanceRenewalOppToRenewalEngagementTest {
    
    @isTest
    public static void notActiveOpportunityShouldNotMoveToRenewalEngagementTest() {
        // Arrange
        insertOpportunity(DateTime.now().addDays(5).date(), true);
        // Act
        startFlow();
        // Assert
        Opportunity oppAfterFlow = [SELECT ID, StageName FROM Opportunity];
        System.assert(oppAfterFlow.StageName == 'Pending', 'Opportunity should not move from Pending');
    }

    @isTest
    public static void activeOpportunityShouldMoveToRenewalEngagementTest() {
        // Arrange
        insertOpportunity(DateTime.now().addDays(5).date(), false);
        // Act
        startFlow();
        // Assert
        Opportunity oppAfterFlow = [SELECT ID, StageName FROM Opportunity];
        System.assert(oppAfterFlow.StageName == 'Outreach', 'Opportunity should move to Outreach');
    }

    @isTest
    public static void testOpportunityShouldNotMoveToRenewalEngagementTest() {
        // Arrange
        insertOpportunity(DateTime.now().addDays(5).date(), false);
        Opportunity opp = [SELECT ID, NAME FROM Opportunity];
        opp.name = '_Test_';
        update opp;
        // Act
        startFlow();
        // Assert
        Opportunity oppAfterFlow = [SELECT ID, StageName FROM Opportunity];
        System.assert(oppAfterFlow.StageName == 'Pending', 'Opportunity should move not move to Outreach');
    }

    @isTest
    public static void notRenewalOpportunityShouldNotMoveToRenewalEngagementTest() {
        // Arrange
        insertOpportunity(DateTime.now().addDays(5).date(), false);
        Opportunity opp = [SELECT ID, type FROM Opportunity];
        opp.type = 'New Business';
        update opp;
        // Act
        startFlow();
        // Assert
        Opportunity oppAfterFlow = [SELECT ID, StageName FROM Opportunity];
        System.assert(oppAfterFlow.StageName == 'Pending', 'Opportunity should move not move to Outreach');
    }

    /*@isTest
    public static void closeDateMoreThan121DaysShouldNotMoveToRenewalEngagementTest() {
        // Arrange
        insertOpportunity(DateTime.now().addDays(122).date(), false);
        // Act
        startFlow();
        // Assert
        Opportunity oppAfterFlow = [SELECT ID, StageName FROM Opportunity];
        System.assert(oppAfterFlow.StageName == 'Pending', 'Opportunity should not move to Renewal Engagement');
    }*/

    private static void startFlow() {
        Map<String, Object> params = new Map<String, Object>();
        Flow.Interview.AdvanceRenewalOpportunityFromPendingToRenewalEngagement flow = 
           new Flow.Interview.AdvanceRenewalOpportunityFromPendingToRenewalEngagement(params);
        
        flow.start();
    }

    private static Opportunity insertOpportunity(Date renewalDate, Boolean draft) {
        Subsidiary__c subsidiary = new Subsidiary__c();
        insert subsidiary;
        Product_Configuration__c prodConfig = TestData.createProductConfiguration(subsidiary.Id, null,'Kayako');
        /*Product_Configuration__c prodConfig = new Product_Configuration__c(Name = 'Kayako',
                 Product__c = 'Kayako',
                 US_Provider_Name__c = TestData.USA_PROVIDER_NAME,
                 Non_US_Provider_Name__c = TestData.NON_USA_PROVIDER_NAME,
                 Fulfillment_Email__c='test@trilogy.com',
                 Manual_Quote__c = false,
                 Renewal_Enabled__c = true,
                 New_Business_Enabled__c = true,
                 Contracting_Entity_US_and_AE__c = subsidiary.Id,
                 Contracting_Entity_Other__c = subsidiary.Id);
        insert prodConfig;*/
        Product_Configuration__c prodConfigDb = [SELECT Id FROM Product_Configuration__c
                                                 WHERE Id = :prodConfig.Id];

        User user = TestData.getUser('System Administrator');
        Opportunity opp = new Opportunity(
                Name = 'Advance Renewal',
                StageName = 'Pending',
                CloseDate = renewalDate.addDays(-1),
                Type = 'Renewal',
                OwnerId = user.Id,
                NetSuite_ID__c = '1234',
                Product__c = 'Kayako',
                Renewal_Date__c = renewalDate,
                Draft__c = draft,
                Parent_Subscription_ID__c = 'A-S12345678',
                Product_Configuration__c = prodConfigDb.Id,
                Product_Configuration__r = prodConfigDb
        );
        insert opp;
        return opp;
    }

}