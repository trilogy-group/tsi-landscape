@isTest
public with sharing class TestOpportunityTriggerHandler {
    static final String LABEL_FAKE_ACCOUNT = 'Fake account';
    static final STRING ROLE_DISTRIBUTOR = 'Distributor';
    static final String ROLE_RESELLLER = 'VAR/Reseller';

    @TestSetup
    static void makeData() {
        TestData.createOpportunityForCPQDocument('Renewal','ACRM');
    }

    @isTest
    static void checkOpportunityPartnersSkippedWhenStageNameIsNotFinalQuote() {
        Opportunity oppy = [SELECT Id, Name,StageName,AccountId FROM Opportunity WHERE Type='Renewal' limit 1];
        Account fakeAccount = new Account(Name=LABEL_FAKE_ACCOUNT);
        insert fakeAccount;
        SBQQ__Quote__c primaryQuote = [
            SELECT Id, SBQQ__Partner__c FROM SBQQ__Quote__c WHERE SBQQ__Opportunity2__c=:oppy.Id LIMIT 1
        ];
        primaryQuote.SBQQ__Partner__c = fakeAccount.Id;
        update primaryQuote;

        Test.startTest();
        oppy.StageName = 'Engaged';
        update oppy;
        System.assert(true, 'Passed if no error occurred.');
        Test.stopTest();
    }

    @isTest
    static void checkOpportunityPartnersFailedWhenResellerSetupIsInvalid() {
        Opportunity oppy = [SELECT Id, Name,StageName,AccountId FROM Opportunity WHERE Type='Renewal' limit 1];
        Account fakeAccount = new Account(Name=LABEL_FAKE_ACCOUNT);
        insert fakeAccount;
        SBQQ__Quote__c primaryQuote = [
            SELECT Id, SBQQ__Partner__c FROM SBQQ__Quote__c WHERE SBQQ__Opportunity2__c=:oppy.Id LIMIT 1
        ];
        primaryQuote.SBQQ__Partner__c = fakeAccount.Id;
        update primaryQuote;
        
        Test.startTest();
        oppy.StageName = System.Label.FinalQuote;
        try {
            update oppy;
            System.assert(false,'Control will not reach here');
        } catch (DMLException dmlex) {
            String message = String.format(System.Label.FinalQuoteIncorrectOpportunityPartner,
                                           new String[]{'partner', ROLE_RESELLLER});
            System.assertEquals(message,dmlex.getDmlMessage(0).trim(),'Verifying error message');
        }
        Test.stopTest();
    }

    @isTest
    static void checkOpportunityPartnersFailedWhenResellerSetupIsInvalidWithDuplicateRole() {
        Opportunity oppy = [SELECT Id, Name,StageName,AccountId FROM Opportunity WHERE Type='Renewal' limit 1];
        Account fakeAccount1 = new Account(Name=LABEL_FAKE_ACCOUNT+' 1');
        Account fakeAccount2 = new Account(Name=LABEL_FAKE_ACCOUNT+' 2');
        insert new Account[] { fakeAccount1, fakeAccount2 };
        SBQQ__Quote__c primaryQuote = [
            SELECT Id, SBQQ__Partner__c FROM SBQQ__Quote__c WHERE SBQQ__Opportunity2__c=:oppy.Id LIMIT 1
        ];
        primaryQuote.SBQQ__Partner__c = fakeAccount1.Id;
        update primaryQuote;
        insert new OpportunityPartner[] {
            new OpportunityPartner(OpportunityId=oppy.Id, AccountToId=fakeAccount1.Id, Role=ROLE_RESELLLER), 
            new OpportunityPartner(OpportunityId=oppy.Id, AccountToId=fakeAccount2.Id, Role=ROLE_RESELLLER)
        };

        Test.startTest();
        oppy.StageName = System.Label.FinalQuote;
        try {
            update oppy;
            System.assert(false,'Control will not reach here');
        } catch (DMLException dmlex) {
            String message = String.format(System.Label.FinalQuoteIncorrectOpportunityPartner,
                                           new String[]{'partner', ROLE_RESELLLER});
            System.assertEquals(message,dmlex.getDmlMessage(0).trim(),'Verifying error message');
        }
        Test.stopTest();
    }

    @isTest
    static void checkOpportunityPartnersFailedWhenDistributorSetupIsInvalid() {
        Opportunity oppy = [SELECT Id, Name,StageName,AccountId FROM Opportunity WHERE Type='Renewal' limit 1];
        Account fakeAccount = new Account(Name=LABEL_FAKE_ACCOUNT);
        insert fakeAccount;
        SBQQ__Quote__c primaryQuote = [
            SELECT Id, SBQQ__Distributor__c FROM SBQQ__Quote__c WHERE SBQQ__Opportunity2__c=:oppy.Id LIMIT 1
        ];
        primaryQuote.SBQQ__Distributor__c = fakeAccount.Id;
        update primaryQuote;

        Test.startTest();
        oppy.StageName = System.Label.FinalQuote;
        try {
            update oppy;
            System.assert(false,'Control will not reach here');
        } catch (DMLException dmlex) {
            String message = String.format(System.Label.FinalQuoteIncorrectOpportunityPartner,
                                           new String[]{'distributor', ROLE_DISTRIBUTOR});
            System.assertEquals(message,dmlex.getDmlMessage(0).trim(),'Verifying error message');
        }
        Test.stopTest();
    }

    @isTest
    static void checkOpportunityPartnersFailedWhenDistributorSetupIsInvalidWithDuplicateRole() {
        Opportunity oppy = [SELECT Id, Name,StageName,AccountId FROM Opportunity WHERE Type='Renewal' limit 1];
        Account fakeAccount1 = new Account(Name=LABEL_FAKE_ACCOUNT+' 1');
        Account fakeAccount2 = new Account(Name=LABEL_FAKE_ACCOUNT+' 2');
        insert new Account[] { fakeAccount1, fakeAccount2 };
        SBQQ__Quote__c primaryQuote = [SELECT Id, SBQQ__Distributor__c FROM SBQQ__Quote__c
                                       WHERE SBQQ__Opportunity2__c=:oppy.Id LIMIT 1];
        primaryQuote.SBQQ__Distributor__c = fakeAccount1.Id;
        update primaryQuote;
        OpportunityPartner fakeDistributor1 = new OpportunityPartner(
            OpportunityId=oppy.Id, AccountToId=fakeAccount1.Id, Role=ROLE_DISTRIBUTOR
        );
        OpportunityPartner fakeDistributor2 = new OpportunityPartner(
            OpportunityId=oppy.Id, AccountToId=fakeAccount2.Id, Role=ROLE_DISTRIBUTOR
        );
        insert new OpportunityPartner[] { fakeDistributor1, fakeDistributor2 };

        Test.startTest();
        oppy.StageName = System.Label.FinalQuote;
        try {
            update oppy;
            System.assert(false,'Control will not reach here');
        } catch (DMLException dmlex) {
            String message = String.format(System.Label.FinalQuoteIncorrectOpportunityPartner,
                                           new String[]{'distributor', ROLE_DISTRIBUTOR});
            System.assertEquals(message,dmlex.getDmlMessage(0).trim(),'Verifying error message');
        }
        Test.stopTest();
    }

    @isTest
    static void checkOpportunityValidations() {
        Opportunity testOpportunity = [SELECT Id, Name,StageName FROM Opportunity WHERE Type='Renewal' limit 1];
        Account testResellerAccount = new Account
                                    (Id = null, 
                                    Name = 'Test Reseller account', 
                                    BillingCountry = 'USA', 
                                    BillingCity = 'New York',
                                    BillingState ='New York',
                                    BillingStreet = 'Test Times Square Corner');
        insert testResellerAccount;
        OpportunityPartner oppyPartner = new OpportunityPartner
                                        (OpportunityId=testOpportunity.Id,
                                        AccountToId=testResellerAccount.Id,
                                        Role='Distributor');
        insert oppyPartner;
        SBQQ__Quote__c primaryQuote = [SELECT Id, SBQQ__Status__c,Service_Provider_Name__c,Service_Provider_Street__c,
                                       Service_Provider_City__c,Service_Provider_Country__c, Service_Provider__c
                                       FROM SBQQ__Quote__c
                                       WHERE SBQQ__Opportunity2__c=:testOpportunity.Id LIMIT 1];
        primaryQuote.SBQQ__Distributor__c = testResellerAccount.Id;
        update primaryQuote;
        Contact testContact = new Contact(LastName = 'LastName', Email = 'test@test2.com', HasOptedOutOfEmail = false,AccountId=testResellerAccount.Id);
        insert testContact;
        Test.startTest();
        //break the validation
        testOpportunity.Addresses_Validated__c = true;
        testOpportunity.StageName = System.Label.FinalQuote;
        try {
            update testOpportunity;
            System.assert(false,'Control will not reach here');
        } catch (DMLException dmlex) {
            String message = '';
            message = message + System.Label.FinalQuoteError;
            System.assertEquals(message,dmlex.getDmlMessage(0).trim(),'Verifying error message');
        }
       	Reseller_Agreement__c agreement = new Reseller_Agreement__c(
            Account__c = testResellerAccount.Id,
            Subsidiary__c = primaryQuote.Service_Provider__c,
            Reseller_Agreement_Link__c = 'https://www.trilogy.com'
        );
        insert agreement;
		primaryQuote.SBQQ__EndDate__c = Date.today()+90;
        primaryQuote.SBQQ__Status__c = 'Draft';
        primaryQuote.SBQQ__Primarycontact__c=testContact.Id;
        testOpportunity.SBQQ__PrimaryQuote__c = primaryQuote.Id;
        update primaryQuote;
        update testOpportunity;
        System.assert(true,'No error occurred test passed!!');
        Test.stopTest();
    }

    @isTest
    static void checkOpportunityAddressValidations() {
        Opportunity testOpportunity = [SELECT Id, Name,StageName,AccountId FROM Opportunity WHERE Type='Renewal' limit 1];
        Account testResellerAccount = new Account
                                    (Id = null, 
                                    Name = 'Test Reseller account', 
                                    BillingCountry = 'USA', 
                                    BillingCity = 'New York');
        insert testResellerAccount;
        OpportunityPartner oppyPartner = new OpportunityPartner
                                        (OpportunityId=testOpportunity.Id,
                                        AccountToId=testResellerAccount.Id,
                                        Role='Distributor');
        insert oppyPartner;
        Contact testContact = new Contact(LastName = 'LastName', Email = 'test@test2.com', HasOptedOutOfEmail = false,AccountId=testResellerAccount.Id);
        insert testContact;
        SBQQ__Quote__c primaryQuote = [SELECT Id, SBQQ__Status__c,Service_Provider_Name__c,Service_Provider_Street__c,
                                       Service_Provider_City__c,Service_Provider_Country__c,
                                       SBQQ__Primary__c,SBQQ__EndDate__c, Service_Provider__c FROM SBQQ__Quote__c
                                       WHERE SBQQ__Opportunity2__c=:testOpportunity.Id LIMIT 1];
        primaryQuote.SBQQ__Distributor__c=testResellerAccount.Id;
        update primaryQuote;
        Reseller_Agreement__c agreement = new Reseller_Agreement__c(
            Account__c = testResellerAccount.Id,
            Subsidiary__c = primaryQuote.Service_Provider__c,
            Reseller_Agreement_Link__c = 'https://www.trilogy.com'
        );
        insert agreement;

        Test.startTest();
        //break the validation
        testOpportunity.Addresses_Validated__c = true;
        testOpportunity.StageName = System.Label.FinalQuote;
        try {
            update testOpportunity;
            System.assert(false,'Control will not reach here');
        } catch (DMLException dmlex) {
            String message = '';
            message = message +System.Label.FinalQuoteBillingAddressError;
            System.assertEquals(message,dmlex.getDmlMessage(0).trim(),'Verifying error message');
        }
        testResellerAccount.BillingState ='New York';
        testResellerAccount.BillingStreet = 'Test Times Square Corner';
        primaryQuote.SBQQ__Status__c = 'Draft';
        primaryQuote.SBQQ__EndDate__c = Date.today()+90;
        primaryQuote.SBQQ__Primarycontact__c=testContact.Id;
        Account testAccount = [SELECT ID, BillingState,ShippingStreet,ShippingCity,ShippingCountry FROM Account WHERE ID=:testOpportunity.AccountId LIMIT 1];
        testAccount.ShippingStreet='test street';
        testAccount.ShippingCity='New York';
        testAccount.ShippingCountry='United States';
        update testAccount;
        update primaryQuote;
        update testResellerAccount;
        update testOpportunity;
        System.assert(true,'No error occurred test passed!!');
        //checking account billing address
        testOpportunity.StageName = 'Pending';
        update testOpportunity;
        delete agreement;
        delete testResellerAccount;
        testAccount.BillingCity='';
        update testAccount;
        Contact testContact2 = new Contact(LastName = 'LastName2', Email = 'test@test2.com',AccountId=testAccount.Id);
        insert testContact2;
        primaryQuote.SBQQ__Status__c = 'Draft';
        primaryQuote.SBQQ__PrimaryContact__c=testContact2.Id;
        primaryQuote.SBQQ__Distributor__c=null;
        update primaryQuote;
        testOpportunity.StageName = System.Label.FinalQuote;
        try {
            update testOpportunity;
            System.assert(false,'Control will not reach here');
        } catch (DMLException dmlex) {
            String message = '';
            message = message  + OpportunityTriggerHandler.formatMessage('Billing',System.Label.FinalQuoteAccountAddressError);
            System.assertEquals(message,dmlex.getDmlMessage(0).trim(),'Verifying error message');
        }
        Test.stopTest();
    }
}