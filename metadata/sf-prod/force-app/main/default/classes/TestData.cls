@IsTest
public with sharing class TestData {

    public static final String NON_USA_PROVIDER_NAME = 'ESW Technologies FZ-LLC (distributor of Kayako software)';
    public static final String USA_PROVIDER_NAME = 'DNN Corp (distributor of Kayako Software)';
    public static final String USA_PROVIDER_NAME_SOCOCO = 'DNN Corp (distributor of Sococo Software)';
    public static final String LAST_NAME = 'Last Name';
    public static final String TEST_COMPANY = 'Test Company';
    public static final String PRODUCT_NAME = 'Product 1';
    public static final String PRODUCT_NAME_2 = 'Product 2';
    public static final String PRODUCT_CODE = 'starter';
    public static final String PRODUCT_FAMILY = 'Kayako';
    public static final String PRODUCT_SUCCESS_LEVEL = 'Standard';
    public static final String PRODUCT_EDITION = 'Standard';
    public static final String PRODUCT_EDITION_LABEL = 'Growth';
    public static final String EMAIL_1 = 'email1@domain.com';
    public static final String EMAIL_2 = 'email2@domain.com';
    static final Id DMITRY_BAKAEV_ID = [SELECT Id FROM User WHERE Name='Dmitry Bakaev'].Id;


    static Integer idNum = 1;
    // Get a fake identifier for the given object type
    public static Id getFakeId(Schema.sObjectType objectType)
    {
        String result = String.valueOf(idNum++);
        return (Id) (objectType.getDescribe().getKeyPrefix() +
            '0'.repeat(12-result.length()) + result);
    }

    public static void createLead(String companyName, String leadLastName, String productName, Decimal tierSeatsLower) {
        Subsidiary__c subsidiary = new Subsidiary__c();
        insert subsidiary;
        //Product Configuration
        Product_Configuration__c prodConfig = new Product_Configuration__c(Product__c = productName,
                US_Provider_Name__c = USA_PROVIDER_NAME,
                Non_US_Provider_Name__c = NON_USA_PROVIDER_NAME,
                Contracting_Entity_US_and_AE__c = subsidiary.Id,
                Contracting_Entity_Other__c = subsidiary.Id);
        insert prodConfig;
        // Product2
        Product2 product = new Product2(
                Name = 'Kayako:Standard:Standard:0:49:Yearly',
                CanUseRevenueSchedule = false,
                IsActive = true,
                Product__c = productName,
                ProductCode = 'starter',
                Family = productName,
                Success_Level__c = 'Standard',
                Product_Edition__c = '',
                Product_Edition_Label__c = '',
                Min_Quantity__c = tierSeatsLower,
                Max_Quantity__c = 50,
                Subscription_Terms__c = '0;1;2;3;4;5');
        insert product;

        Id idPricebook = Test.getStandardPricebookId();
        Pricebook2 standardPricebook = new Pricebook2(
                Id = Test.getStandardPricebookId(),
                IsActive = true
        );
        update standardPricebook;
        // PriceBookEntry
        PriceBookEntry priceBookEntry = new PriceBookEntry(UnitPrice = 15.00,
                Product2Id = product.Id,
                IsActive = true,
                PriceBook2Id = idPricebook,
                UseStandardPrice = false);
        insert priceBookEntry;

        Lead newLead =
                new Lead(Company = companyName, LastName = leadLastName, Status = 'Open', Product__c = productName,
                        Incoming_Type__c = 'SQL');
        insert newLead;
    }
    public static void createLead(String companyName, String leadLastName, String productName) {
        TestData.createLead(companyName, leadLastName, productName, 0);
    }

    public static Opportunity createOpportunityForCPQDocument(){
            return createOpportunityForCPQDocument('New Business', 'Kayako');
    }
        
    // Create an opportunity with SBQQ__QuotePricebookId__clink set
    public static Opportunity createOpportunityForCPQDocument(String oppType, String productFamily){ 
        Pricebook2 standardPricebook = new Pricebook2(
                Id = Test.getStandardPricebookId(),
                IsActive = true
        );
        update standardPricebook;

        User user = TestData.getUser('System Administrator');
        user.echosign_dev1__EchoSign_Allow_Delegated_Sending__c = true;
        user.echosign_dev1__EchoSign_Email_Verified__c = true;
        update user;

        TestData.updateUserRole(user, 'System Administrator');

        Account testAccount = new Account(Id = null, Name = 'Test account', BillingCountry = 'USA', BillingCity = 'New York',
                                BillingState ='New York',BillingStreet = 'Test Times Square Corner',
                                ShippingCountry='USA',ShippingStreet='Test Times Square Corner',ShippingCity='New York');
        insert testAccount;
        Subsidiary__c subsidiary = new Subsidiary__c();
        subsidiary.Name='Skyvera, LLC';
        subsidiary.City__c	='New York';
        subsidiary.State__c = 'NY';
        subsidiary.Country__c = 'United States';
        subsidiary.Street__c ='Test Broadway and fifth';
        insert subsidiary;
        Product_Configuration__c prodConfig = createProductConfiguration(subsidiary.Id, user.Id,productFamily);
        String netSuiteId = productFamily == 'Kayako' ? '' : 
                String.valueOf(Integer.valueof((Math.random() * 1000000000)));
        String parentSubscriptionId = oppType == 'Renewal' ? 'A-S00000000' : '';
        Opportunity testOpportunity = new Opportunity(
                AccountId = testAccount.Id,
                Account = testAccount,
                Product__c = productFamily,
                Name = 'Test Opportunity',
                StageName = 'Proposal',
                CloseDate =  DateTime.now().addDays(5).date(), 
                Type=oppType,
                OwnerId = user.Id,
                SBQQ__QuotePricebookId__c = standardPricebook.Id,
                Current_ARR__c = 1000,
                Current_Term__c = 12,
                Current_Success_Level__c = 'Standard',
                NetSuite_ID__c = netSuiteId,
                //Quoting_Entity__c = 'Aclate',
                Parent_Subscription_ID__c = parentSubscriptionId,
            	CurrentContractHasAutoRenewalClause__c = 'No'
            );

        Date oppRenewalDate = Date.today();
        if (oppType == 'Renewal') {
                oppRenewalDate = Date.today().addDays(30);
                testOpportunity.Renewal_Date__c = oppRenewalDate;
        }

        insert testOpportunity;

        Contact contact = new Contact(
            LastName = 'Lastname',
            Email = 'email@email.com',
            Current_Product_Family__c = productFamily,
            AccountId = testAccount.Id,
            OwnerId = testOpportunity.OwnerId
        );
        insert contact;

        SBQQ__Quote__c quote = new SBQQ__Quote__c(
                SBQQ__Type__c = 'Quote',
                SBQQ__Status__c = 'Draft',
                SBQQ__SubscriptionTerm__c = 1,
                SBQQ__PricebookId__c = testOpportunity.SBQQ__QuotePricebookId__c,
                SBQQ__Opportunity2__c = testOpportunity.Id,
                SBQQ__Primary__c = True,
                SBQQ__PrimaryContact__c = contact.Id,
                SBQQ__ExpirationDate__c = Date.today() + 4,
                SBQQ__StartDate__c = oppRenewalDate,
                SBQQ__EndDate__c = oppRenewalDate.addDays(1),
                SBQQ__SalesRep__c = TestData.getUser('System Administrator').Id,
                SBQQ__BillingStreet__c = 'Test BillingStreet',
                SBQQ__BillingCity__c = 'Test BillingCity',
                SBQQ__BillingName__c = 'Test BillingName',
                SBQQ__BillingCountry__c = 'Test BillingCountry',
                SBQQ__ShippingStreet__c = 'Test ShippingStreet',
                SBQQ__ShippingCity__c = 'Test ShippingCity',
                SBQQ__ShippingName__c = 'Test ShippingName',
                SBQQ__ShippingCountry__c = 'Test ShippingCountry'
        );
        insert quote;

        OpportunityContactRole ocr = new OpportunityContactRole(ContactId = contact.Id, IsPrimary = true, OpportunityId = testOpportunity.Id, Role = 'Decision Maker');
        insert ocr;
        testOpportunity.SBQQ__PrimaryQuote__r = quote;
        testOpportunity.SBQQ__PrimaryQuote__c = quote.Id;
        update testOpportunity;
        testOpportunity = [SELECT Id, OwnerId, AccountId, Product__c, Name, StageName, CloseDate, Type, Owner.Email,
            Owner.Name, Owner.ManagerId, ContactId, SBQQ__QuotePricebookId__c, SBQQ__PrimaryQuote__c
            FROM Opportunity Where Id=:testOpportunity.Id];
        return testOpportunity;
    }

    public static SBQQ__QuoteDocument__c createCpqQuoteDocument(Opportunity testOpportunity, String documentName){  // Create a record for CPQ Quote document
        SBQQ__Quote__c quote = new SBQQ__Quote__c(
                SBQQ__Type__c = 'Quote',
                SBQQ__Status__c = 'Draft',
                SBQQ__SubscriptionTerm__c = 1,
                SBQQ__PricebookId__c = testOpportunity.SBQQ__QuotePricebookId__c,
                SBQQ__Opportunity2__c = testOpportunity.Id,
                SBQQ__Primary__c = True
        );
        insert quote;

        SBQQ__QuoteDocument__c doc = new SBQQ__QuoteDocument__c(SBQQ__Opportunity__c = testOpportunity.Id,
                SBQQ__DocumentId__c = TestData.getFakeId(Document.getSObjectType()),
                Name = documentName + '.pdf',
                SBQQ__Quote__c = quote.Id,
                SBQQ__Opportunity__r = testOpportunity
        );
        insert doc;        
        return doc;
    }

    public static QuoteWithLineItems createQuoteWithLineItems(String chargeType, Decimal unitPrice,
                                                                Integer quantity, String term) {
        QuoteWithLineItems out = new QuoteWithLineItems();
        Account acct = new Account(Name = 'Test Account', Success_Level__c = 'Standard');
        insert acct;
        out.accountId = acct.Id;
        // Product2
        Product2 product;
        if (chargeType.equals('One-Time')) {
            product = new Product2(
                Name = 'Sococo:Standard:Standard:0:49:Monthly',
                CanUseRevenueSchedule = false,
                IsActive = true,
                Product__c = 'Sococo',
                ProductCode = 'starter',
                Min_Quantity__c = 10,
                SBQQ__ChargeType__c = chargeType,
                SBQQ__BillingFrequency__c = null,
                Subscription_Terms__c = '12;24;36;48;60',
                Success_Level__c = 'Standard'
            );
        } else {
            product = new Product2(
                Name = 'Sococo:Standard:Standard:0:49:Monthly',
                CanUseRevenueSchedule = false,
                IsActive = true,
                Product__c = 'Sococo',
                ProductCode = 'starter',
                Min_Quantity__c = 10,
                SBQQ__SubscriptionTerm__c = 1,
                SBQQ__PricingMethod__c = 'List',
                SBQQ__SubscriptionPricing__c = 'Fixed Price',
                SBQQ__ChargeType__c = 'Recurring',
                SBQQ__BillingType__c = 'Advance',
                Subscription_Terms__c = '1;12;24;36;48;60',
                Success_Level__c = 'Standard'
            );
        }
  
        insert product;
        out.productId = product.Id;

        // PriceBook2
        PriceBook2 pb2 = new PriceBook2(
            Name = 'Standard Price Book',
            IsActive = true
        );
        insert pb2;
        Id idPricebook = Test.getStandardPricebookId();
        // PriceBookEntry
        PriceBookEntry priceBook = new PriceBookEntry(
            UnitPrice = unitPrice,
            Product2Id = product.Id,
            IsActive = true,
            PriceBook2Id = idPricebook,
            UseStandardPrice = false
        );
        insert priceBook;
                                                                   
        // Product_Configuration__c
        Subsidiary__c subsidiary = new Subsidiary__c();
        insert subsidiary;
        Product_Configuration__c prodConfig = createProductConfiguration(subsidiary.Id, null,'Sococo');
        // Opportunity
        Opportunity opp = new Opportunity(
            Name = acct.Name + ' Opportunity',
            StageName = 'Pending',
            CloseDate = System.today().addMonths(1),
            AccountId = acct.Id,
            Product_Configuration__c = prodConfig.Id,
            Product__c = 'Sococo',
            Type = 'New Business',
            Renewal_Date__c = System.today().addMonths(1),
            NetSuite_ID__c = String.valueOf(Integer.valueof((Math.random() * 1000000000))),
            CurrentContractHasAutoRenewalClause__c = 'No'
            //Quoting_Entity__c = 'DNN Corp.'
        );
        insert opp;
        out.opportunityId = opp.Id;
  
        Integer subscriptionTerm = Integer.valueOf(term);
        // Quote
        SBQQ__Quote__c quote = new SBQQ__Quote__c(
            SBQQ__Type__c = 'Quote',
            SBQQ__SubscriptionTerm__c = subscriptionTerm,
            SBQQ__PricebookId__c = idPricebook
        );
  
        insert quote;
        out.quoteId = quote.Id;
        // QuoteLineItem
  
        SBQQ__QuoteLine__c lineItem = new SBQQ__QuoteLine__c(
            SBQQ__Product__c = product.Id,
            SBQQ__Quantity__c = quantity,
            SBQQ__PricebookEntryId__c = priceBook.Id,
            SBQQ__SubscriptionTerm__c = subscriptionTerm,
            SBQQ__Quote__c = quote.Id,
            SBQQ__BillingFrequency__c = chargeType == 'One-Time' ? null : 'Monthly'
        );
        insert lineItem;

        // Insert a corresponding opportunity line
        OpportunityLineItem oppLineItem = new OpportunityLineItem(Product2Id = product.Id,
                Quantity = quantity,
                PricebookEntryId = priceBook.Id,
                OpportunityId = opp.Id,
                UnitPrice = unitPrice,
                Subscription_Term__c = subscriptionTerm);
        insert oppLineItem;

        out.quoteLineItemId = lineItem.Id;
        return out;
    }

    public class QuoteWithLineItems {
        public Id accountId;
        public Id productId; 
        public Id opportunityId;
        public Id quoteId; 
        public Id quoteLineItemId;
    }

    /*
        get Product certificate of an active user of the specified role
    */
    public static String getProductNameFromActiveRoleUser(String roleName) {
        List<User> users = [SELECT Product_Certifications__c FROM User 
                            WHERE IsActive = true AND Product_Certifications__c != '' AND UserRole.Name = :roleName 
                            LIMIT 1];
        if (users.size() == 0){
            throw new InvalidOperationException('No active users in UserRole ISR with Product Certifications set. ' +
                                                'Setup at least one user to run the tests.');
        }
        //return first
        return users[0].Product_Certifications__c.substringBefore(';');
    }

    public static ArrangeReturn createOppAndContract() {
        SBQQ.TriggerControl.disable();        
        try {
            // Create opportunity with quotelines
            QuoteWithLineItems data = createQuoteWithLineItems('Monthly', 15.00, 20, '1');
            
            // Update quote to have start date to create contract
            SBQQ__Quote__c quote = [SELECT Id, SBQQ__SubscriptionTerm__c FROM SBQQ__Quote__c WHERE Id = :data.quoteId];
            Date startDate = DateTime.now().addDays(-1).date();
            quote.SBQQ__StartDate__c = startDate;
            quote.SBQQ__EndDate__c = startDate.addDays(365);
            quote.SBQQ__Primary__c = true;
            quote.SBQQ__Opportunity2__c = data.opportunityId;
            quote.SBQQ__Status__c = 'Accepted';
            update quote;

            // Check if quoteLines and opportunity products exist
            List<SBQQ__QuoteLine__c> quoteLines = [SELECT SBQQ__StartDate__c, SBQQ__Product__c FROM SBQQ__QuoteLine__c 
                                                    WHERE SBQQ__Quote__c = :quote.Id];
            System.assert(quoteLines.size() > 0, 'Should exist at least one quote line before running test.');
            List<OpportunityLineItem> oppItems = [SELECT Id, Description 
                                                FROM OpportunityLineItem 
                                                WHERE OpportunityId = :data.opportunityId];
            System.assert(oppItems.size() > 0, 'Should exist at least one product before running test.');

            // Update the opportunity to closed won
            Opportunity opp = [SELECT Id, AccountId, Product__c, Success_Level__c 
                            FROM Opportunity 
                            WHERE Id = :data.opportunityId];
            opp.SBQQ__PrimaryQuote__c = quote.Id;
            opp.Purchase_Order__c = 'Not required';
            opp.O2C_Record__c = 'https://test.com';
            opp.Win_Type__c = 'PO Received';
            opp.StageName = 'Closed Won';
            opp.Renewal_Date__c = startDate;
            opp.Type = 'Renewal';
            opp.Parent_Subscription_ID__c = 'A-S00000000';
            
            // Can't create contract setting SBQQ__Contracted__c = true, because CPQ will schedule an apex job 
            // and will not execute before activation
            //opp.SBQQ__Contracted__c = true;
            update opp;

            // Create a contract
            Contract contract = new Contract();
            contract.AccountId = opp.AccountId;
            contract.ContractTerm = Integer.valueOf(quote.SBQQ__SubscriptionTerm__c);
            contract.SBQQ__Opportunity__c = opp.Id;
            contract.SBQQ__Quote__c = quote.Id;
            contract.SBQQ__RenewalTerm__c = quote.SBQQ__SubscriptionTerm__c;
            contract.StartDate = startDate;
            contract.EndDate = startDate.addMonths(Integer.valueOf(quote.SBQQ__SubscriptionTerm__c));
            insert contract;

            // Activate the contract
            List<Contract> contracts = [SELECT Id, EndDate, Status, Success_Level__c, AccountId, ARR__c FROM Contract
                                        WHERE SBQQ__Opportunity__c = :opp.Id];
            System.assertEquals(1, contracts.size(), 'Should exist one contract before running the test.');
            contracts[0].Status = 'Activated';
            update contracts;

            SBQQ__Subscription__c subscription = new SBQQ__Subscription__c();
            subscription.SBQQ__Account__c = contract.AccountId;
            subscription.SBQQ__BillingFrequency__c = 'Annual';
            subscription.SBQQ__ChargeType__c = 'Recurring';
            subscription.SBQQ__Contract__c = contract.Id;
            subscription.SBQQ__CustomerPrice__c = 10;
            subscription.SBQQ__Product__c = quoteLines[0].SBQQ__Product__c;
            subscription.SBQQ__Quantity__c = 10;
            insert subscription;

            return new ArrangeReturn(contracts[0], opp);
        } finally {
        SBQQ.TriggerControl.enable();
        }
    }

    public class ArrangeReturn{
        public Contract contract;
        public Opportunity opportunity;

        ArrangeReturn(Contract contract, Opportunity opp) {
            this.contract = contract;
            this.opportunity = opp;
        }
    }

    private static String getUniqueName(String orgId) {
        
        String dateString=String.valueof(Datetime.now()).replace(' ','').replace(':','').replace('-','') ;
        Integer randomId=Integer.valueOf(Math.rint(Math.random()*1000000));
        String uniqueName=orgId+dateString+randomId;
        return uniqueName;
    }

    public static User getUser(String profileName, User manager) {
        Profile pf = [Select Id
                      from profile
                      where Name = :profileName];
        String orgId=UserInfo.getOrganizationId();
        String uniqueName = getUniqueName(orgId);
        
        User user = new User(firstname = 'ABC', lastName = 'XYZ', email = uniqueName + '@test' + orgId + '.org', 
                             Username = uniqueName + '@test' + orgId + '.org', EmailEncodingKey = 'ISO-8859-1', 
                             Alias = uniqueName.substring(18, 23), TimeZoneSidKey = 'America/Los_Angeles', 
                             LocaleSidKey = 'en_US', LanguageLocaleKey = 'en_US', ProfileId = pf.Id,
                              isActive = true, managerId = manager.Id, Netsuite_Id__c = '007');
        insert user;
        return user;
        }

    public static User getUser(String profileName) {
        Profile pf = [Select Id
                      from profile
                      where Name = :profileName];
        String orgId=UserInfo.getOrganizationId();
        String uniqueName = getUniqueName(orgId);
        User user = new User(firstname = 'ABC', lastName = 'XYZ', email = uniqueName + '@test' + orgId + '.org', 
                             Username = uniqueName + '@test' + orgId + '.org', EmailEncodingKey = 'ISO-8859-1', 
                             Alias = uniqueName.substring(18, 23), TimeZoneSidKey = 'America/Los_Angeles', 
                             LocaleSidKey = 'en_US', LanguageLocaleKey = 'en_US', ProfileId = pf.Id,
                              isActive = true);
        insert user;
        return user;
        }

    public static void updateUserRole(User u, String roleName) {
        User dmitryUser = [select Id from User where id = :DMITRY_BAKAEV_ID];
        System.runAs(dmitryUser) {
        UserRole userRole = [SELECT id 
                        FROM UserRole 
                        WHERE name = :roleName];

        u.UserRoleId = userRole.Id;
        u.echosign_dev1__EchoSign_Allow_Delegated_Sending__c = true;
        u.echosign_dev1__EchoSign_Email_Verified__c = true;
        update u;
        }
   }

     public static User createTestUser(String userProfile, String userRole, String productCertification, User manager) {
        User user = null;
        if (manager == null) {
                user = TestData.getUser(userProfile);
        } else {
                user = TestData.getUser(userProfile, manager);
        }
        user.Mailbox_Synced__c =true;
        user.Product_Certifications__c = productCertification;
        update user;
        TestData.updateUserRole(user, userRole);
        return user;
        }
    public static Product_Configuration__c createProductConfiguration(String subsidiaryId, String userId,String productFamily) {
        Product_Configuration__c prodConfig = new Product_Configuration__c(Product__c =  productFamily,
                BU_Notification_Party__c = 'test@test.com',
                Fulfillment_Email__c = 'test@test.com',
                Additional_Notification_Party__c = 'test@test.com',
                Contracting_Entity_US_and_AE__c = subsidiaryId,
                Contracting_Entity_Other__c = subsidiaryId,
				Contacting_Entity_JP__c = subsidiaryId,
            	Contracting_Entity_DE_and_AT__c = subsidiaryId,
                New_Business_Enabled__c = true,
                Renewal_Enabled__c = true,
                Renewal_Cycle_Days__c = 180                                                           
        );
        if(userId!=null) {
            prodConfig.New_Business_Manager__c = userId;
            prodConfig.Renewal_Manager__c = userId;
        }
        insert prodConfig;
        return prodConfig;
    }
    public static EmailTemplate createDummyTemplate(Boolean shouldInsert) {
        EmailTemplate dummyEmailTemplate = new EmailTemplate();
        dummyEmailTemplate.isActive = true;
        dummyEmailTemplate.Name = 'name';
        dummyEmailTemplate.DeveloperName = 'unique_name_dummyyemplate';
        dummyEmailTemplate.TemplateType = 'text';
        dummyEmailTemplate.FolderId = UserInfo.getUserId();
        dummyEmailTemplate.Body = 'test body';
        System.runAs(new User(Id=Userinfo.getUserId())) {
            if(shouldInsert) {
            	insert dummyEmailTemplate;
        	}
        }
        return dummyEmailTemplate;
    }
    public static EmailTemplate createDummyTemplate(Boolean shouldInsert, String name, String developerName) {
        EmailTemplate dummyEmailTemplate = createDummyTemplate(false);
        dummyEmailTemplate.Name = name;
        dummyEmailTemplate.DeveloperName = developerName.trim().replace(' ','_');
        System.runAs(new User(Id=Userinfo.getUserId())) {
            if(shouldInsert) {
            	insert dummyEmailTemplate;
        	}
        }
        return dummyEmailTemplate;
    }
 }