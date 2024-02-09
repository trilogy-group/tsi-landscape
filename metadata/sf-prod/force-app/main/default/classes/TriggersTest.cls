@isTest
public with sharing class TriggersTest {
    public static final String PRODUCT_FAMILY = 'Kayako';
    public static final String OPPORTUNITY_TYPE = 'New Business';
    public static final String OPPORTUNITY_STAGE = 'Outreach';
    public static final String CONTACT_ROLE = 'Decision Maker';
    @isTest
    public static void updatePrimaryContactTriggerTest() { 
        // Change the Primary contact and check that the Primary Contact Changed field is filled by the trigger
        Account testAccount = createTestAccount();
        Opportunity testOpportunity = new Opportunity(AccountId = testAccount.Id,
            Account = testAccount, 
            Product__c = PRODUCT_FAMILY, 
            Name = 'Test Opportunity', 
            StageName = OPPORTUNITY_STAGE, 
            CloseDate =  DateTime.now().addDays(5).date(), 
            Type=OPPORTUNITY_TYPE);
        insert testOpportunity;
        Contact contact = new Contact(
            LastName = 'Lastname1',
            Email = 'email1@email.com',
            Current_Product_Family__c = PRODUCT_FAMILY,
            AccountId = testAccount.Id
        );
        insert contact;
        Contact contact2 = new Contact(
            LastName = 'Lastname2',
            Email = 'emai2@email.com',
            Current_Product_Family__c = PRODUCT_FAMILY,
            AccountId = testAccount.Id
        );
        insert contact2;
        OpportunityContactRole ocr = new OpportunityContactRole(ContactId = contact.Id, 
            IsPrimary = true, 
            OpportunityId = testOpportunity.Id, 
            Role = CONTACT_ROLE);
        insert ocr;
        OpportunityContactRole ocr2 = new OpportunityContactRole(ContactId = contact2.Id, 
            IsPrimary = false, 
            OpportunityId = testOpportunity.Id, 
            Role = CONTACT_ROLE);
        insert ocr2;

        ocr.IsPrimary = false;
        update ocr;
        ocr2.IsPrimary = true;
        update ocr2;
        // Check that the Primary Contact Changed date is not null
        testOpportunity = [SELECT Id, Primary_Contact_Changed__c FROM Opportunity WHERE Id =: testOpportunity.Id];
        System.assertNotEquals(null, testOpportunity.Primary_Contact_Changed__c, 
        'The Primary_Contact_Changed__c field should be filled.');
    }


    @isTest
    public static void updatePrimaryContactTriggerTest2opportunities() { 
    // Check if the trigger works when we insert the same primary contact into 2 opportunities
        Account testAccount = createTestAccount();
        Opportunity testOpportunity1 = new Opportunity(AccountId = testAccount.Id, 
            Account = testAccount, 
            Product__c = PRODUCT_FAMILY, 
            Name = 'Test Opportunity1',
            StageName = OPPORTUNITY_STAGE, 
            CloseDate =  DateTime.now().addDays(5).date(),
            Type=OPPORTUNITY_TYPE);
        insert testOpportunity1;
        Opportunity testOpportunity2 = new Opportunity(AccountId = testAccount.Id,
            Account = testAccount,
            Product__c = PRODUCT_FAMILY,
            Name = 'Test Opportunity2', 
            StageName = OPPORTUNITY_STAGE,
            CloseDate =  DateTime.now().addDays(5).date(),
            Type=OPPORTUNITY_TYPE);
        insert testOpportunity2;
        Contact contact = new Contact(
            LastName = 'Lastname',
            Email = 'email@email.com',
            Current_Product_Family__c = PRODUCT_FAMILY,
            AccountId = testAccount.Id
        );
        insert contact;
        OpportunityContactRole ocr = new OpportunityContactRole(ContactId = contact.Id, 
            IsPrimary = true, 
            OpportunityId = testOpportunity1.Id, 
            Role = CONTACT_ROLE);
        OpportunityContactRole ocr2 = new OpportunityContactRole(ContactId = contact.Id,
            IsPrimary = true,
            OpportunityId = testOpportunity2.Id,
            Role = CONTACT_ROLE);
        insert new OpportunityContactRole[]{ocr, ocr2};
        // Check that the Primary Contact Changed date is not null
        testOpportunity1 = [SELECT Id, Primary_Contact_Changed__c FROM Opportunity WHERE Id =: testOpportunity1.Id];
        System.assertNotEquals(null, testOpportunity1.Primary_Contact_Changed__c,
        'The Primary_Contact_Changed__c field should be filled.');
        contact = [SELECT Id, Current_Product_Family__c FROM Contact WHERE Id =: contact.Id];
        System.assertNotEquals(null, contact.Current_Product_Family__c,
        'Primary contact should have the Current_Product_Family__c field filled.');
    }

    public static Account createTestAccount() {
        Account testAccount = new Account(Id = null, Name = 'Test account', BillingCountry = 'USA', BillingCity = 'New York');
        insert testAccount;
        Subsidiary__c subsidiary = new Subsidiary__c();
        insert subsidiary;
        Product_Configuration__c prodConfig = TestData.createProductConfiguration(subsidiary.Id, null, PRODUCT_FAMILY);
        return testAccount;
    }
    
    @isTest
    public static void recallQuoteApprovalProcessTriggerTest() { 
        
        Opportunity opp = TestData.createOpportunityForCPQDocument();
        // Change to the Final Quote stage to create an approval process
        opp.Addresses_Validated__c = true;
        opp.StageName = 'Final Quote';
        update opp;
        List<ProcessInstanceWorkitem> processes = [SELECT Id, ProcessInstanceId, ProcessInstance.TargetObjectId
                                                    FROM ProcessInstanceWorkitem 
                                                    WHERE ProcessInstance.TargetObjectId = :opp.SBQQ__PrimaryQuote__c];
        System.assertEquals(1, processes.size(), 'Should have one approval process for the quote.');

        // Change the opportunity back to Proposal to recall the approval process
        opp.StageName = 'Proposal';
        update opp;
        processes = [SELECT Id, ProcessInstanceId, ProcessInstance.TargetObjectId
                        FROM ProcessInstanceWorkitem 
                        WHERE ProcessInstance.TargetObjectId = :opp.SBQQ__PrimaryQuote__c];
        System.assertEquals(0, processes.size(), 'Should not have one approval process for the quote.');        
    }
}