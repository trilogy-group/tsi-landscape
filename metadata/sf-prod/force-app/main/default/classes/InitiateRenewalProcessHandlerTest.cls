@isTest
public class InitiateRenewalProcessHandlerTest {
    static final String LABEL_FAKE_ACCOUNT = 'Fake account';
    static final STRING ROLE_DISTRIBUTOR = 'Distributor';
    static final String ROLE_RESELLLER = 'VAR/Reseller';
    static final String USER_PROFILE = 'System Administrator';
    static final String USER_ROLE = 'ISR Renewals';
    static final String MANAGER_PROFILE = 'Team Manager';
    static final String MANAGER_ROLE = 'Manager New Sales';
    @isTest
    static void testOnOutReachTransitionWithoutSurvey() {
        TestData.createOpportunityForCPQDocument('Renewal','ACRM');
        //create test data for class
        Opportunity testOpportunity = [SELECT Id, StageName,OwnerId,Product_Configuration__c 
                                       FROM Opportunity WHERE Type='Renewal' limit 1];
        TestData.createDummyTemplate(true, System.Label.IntroTemplateWithLink , 
                                     System.Label.IntroTemplateWithLink);
        
        TestData.createDummyTemplate(true, System.Label.IntroTemplateWithoutLink,System.Label.IntroTemplateWithoutLink);
        Product_Configuration__c config = new Product_Configuration__c(
        Id=testOpportunity.Product_Configuration__c,
        Mailbox_Override__c='ignitetech.com',
        Renewal_Enabled__c=true);
        update config;
        User userManager = TestData.getUser(MANAGER_PROFILE);
        TestData.updateUserRole(userManager, MANAGER_ROLE);
        User testUser = TestData.createTestUser(USER_PROFILE, USER_ROLE, TestData.PRODUCT_FAMILY, userManager);
        testOpportunity.StageName = 'Pending';
        testOpportunity.OwnerId = testUser.Id;
        update testOpportunity;
        //start test
        Test.startTest();
        testOpportunity.StageName = 'OutReach';
        update testOpportunity;
        Test.stopTest();
    } 
    @isTest(seeAllData=true)
    static void testOnOutReachWithSurvey() {
        //start test
        Opportunity testOpportunity = TestData.createOpportunityForCPQDocument('Renewal','ACRM');
        Id productConfigId = [SELECT Product_Configuration__c 
                              FROM Opportunity
                              WHERE Id =:testOpportunity.Id ][0].Product_Configuration__c;
        //create test data for class
        TestData.createDummyTemplate(true, System.Label.IntroTemplateWithLink , 
                                     System.Label.IntroTemplateWithLink);
        TestData.createDummyTemplate(true, System.Label.IntroTemplateWithoutLink,System.Label.IntroTemplateWithoutLink);
        Id testSurveyId = [SELECT Id from Survey limit 1][0].Id;
        Product_Configuration__c config = new Product_Configuration__c(
        Id=productConfigId,
        Mailbox_Override__c='ignitetech.com',
        Renewal_Enabled__c=true,
        Intro_Survey__c=testSurveyId
        );
        update config;
        User userManager = TestData.getUser(MANAGER_PROFILE);
        TestData.updateUserRole(userManager, MANAGER_ROLE);
        User testUser = TestData.createTestUser(USER_PROFILE, USER_ROLE, TestData.PRODUCT_FAMILY, userManager);
        testOpportunity.StageName = 'Pending';
        testOpportunity.OwnerId = testUser.Id;
        update testOpportunity;
        //start test
        Test.startTest();
        testOpportunity.StageName = 'OutReach';
        update testOpportunity;
        Test.stopTest();
    }
    @isTest(seeAllData=true)
    static void testOnOutReachWithInvalidContact() {
        //start test
        Opportunity testOpportunity = TestData.createOpportunityForCPQDocument('Renewal','ACRM');
        Id productConfigId = [SELECT Product_Configuration__c 
                              FROM Opportunity
                              WHERE Id =:testOpportunity.Id ][0].Product_Configuration__c;
        //create test data for class
        TestData.createDummyTemplate(true, System.Label.IntroTemplateWithLink , 
                                     System.Label.IntroTemplateWithLink);
        TestData.createDummyTemplate(true, System.Label.IntroTemplateWithoutLink,System.Label.IntroTemplateWithoutLink);
        Id testSurveyId = [SELECT Id from Survey limit 1][0].Id;
        Product_Configuration__c config = new Product_Configuration__c(
        Id=productConfigId,
        Mailbox_Override__c='ignitetech.com',
        Renewal_Enabled__c=true,
        Intro_Survey__c=testSurveyId
        );
        update config;
        User userManager = TestData.getUser(MANAGER_PROFILE);
        TestData.updateUserRole(userManager, MANAGER_ROLE);
        User testUser = TestData.createTestUser(USER_PROFILE, USER_ROLE, TestData.PRODUCT_FAMILY, userManager);
        testOpportunity.StageName = 'Pending';
        testOpportunity.OwnerId = testUser.Id;
        update testOpportunity;
        //start test
        Test.startTest();
        testOpportunity.StageName = 'OutReach';
        List<OpportunityContactRole> lstOCR = [SELECT ID from OpportunitycontactRole 
                                                where OpportunityId=:testOpportunity.Id];
        delete lstOCR;
        update testOpportunity;
        Test.stopTest();
    }
}