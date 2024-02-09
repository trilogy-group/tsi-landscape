@isTest
public class SetupRenewalOpportunityTest {
    public class ArrangeParams{
        String productName = 'Kayako';
        String productEdition;
        String productEditionLabel = 'Growth';
        String productSuccessLevel = 'Standard';
        String email = 'test@test.com';
        Integer minQuantity = 1;
        Integer maxQuantity = 49;
        String billingTerm = 'Annual';
        Decimal unitPrice = 15.00;
        Integer quantity = 20;
        String term = '1';
        Decimal currentARR;
        String currentProduct;
        String currentProductEdition;
        String currentProductEditionLabel;
        String currentSuccessLevel;
        Decimal currentAddonsARR;
        Integer currentTerm;
        public ArrangeParams(String productEdition, Decimal currentARR, 
                             String currentProduct, String currentProductEdition,
                             String currentProductEditionLabel, String currentSuccessLevel, 
                             Decimal currentAddonsARR){
            this(productEdition, currentArr, currentProduct, currentProductEdition, currentProductEditionLabel,
                currentSuccessLevel, currentAddonsARR, 1);
        }
        public ArrangeParams(String productEdition, Decimal currentARR, 
                             String currentProduct, String currentProductEdition,
                             String currentProductEditionLabel, String currentSuccessLevel, 
                             Decimal currentAddonsARR, Integer currentTerm){
            this.productEdition = productEdition;
            this.currentARR = currentARR;
            this.currentProduct = currentProduct;
            this.currentProductEdition = currentProductEdition;
            this.currentProductEditionLabel = currentProductEditionLabel;
            this.currentSuccessLevel = currentSuccessLevel;
            this.currentAddonsARR = currentAddonsARR;
            this.currentTerm = currentTerm;
        }
    }

    public class TestResults{
        List<OpportunityLineItem> lineItems;
        SBQQ__Quote__c quote;
        List<SBQQ__QuoteLine__c> quoteLines;
        TestResults(List<OpportunityLineItem> lineItems, SBQQ__Quote__c quote, List<SBQQ__QuoteLine__c> quoteLines){
            this.lineItems = lineItems;
            this.quote = quote;
            this.quoteLines = quoteLines;
        }
    }
    
    @isTest 
    static void verifyNoQuoteCreationForEvergreen() {
        Test.startTest();
        //EVERGREEN have currentTerm = 0
        ArrangeParams params = new ArrangeParams('Standard', 300.00, 'OnDemand', 'Standard', 'Growth', 'Standard', 
            0.00, 0);
        arrange(params);
        Test.stopTest();

        // Assert
        List<Opportunity> oppList = [SELECT Id, Type, Current_Success_Level__c
                                     FROM Opportunity];
        System.assertEquals(1, oppList.size(), 'Expects 1 opportunity to be returned');
        List<AggregateResult> countQuotes = [SELECT Count(Id) cnt
                                             FROM SBQQ__Quote__c
                                             WHERE SBQQ__Opportunity2__c = :oppList[0].Id];
        System.assert((Integer)countQuotes[0].get('cnt') == 0, 'No quote lines should be created.');
    }
    
    @isTest 
    static void verifyCurrentTermMatchesSent() {
        Test.startTest();
        ArrangeParams params = new ArrangeParams('Standard', 300.00, 'OnDemand', 'Standard', 'Growth', 'Standard', 
            0.00, 10);
        arrange(params);
        Test.stopTest();

        // Assert
        List<Opportunity> oppList = [SELECT Id, Type, Current_Term__c
                                     FROM Opportunity];
        System.assertEquals(1, oppList.size(), 'Expects 1 opportunity to be returned');
        System.assertEquals(oppList[0].Current_Term__c, params.currentTerm, 
            'Current Term should be equal current term sent.');
    }

    @isTest 
    static void given_Product_When_DefaultConfiguration_Verify_TypeAndSuccessLevelAndARR() {
        Test.startTest();
        arrange(new ArrangeParams('Standard', 300.00, 'Kayako', 'Standard', 'Growth', 'Standard', 0.00));
        Test.stopTest();

        // Assert
        List<Opportunity> oppList = [SELECT Id, Type, Current_Success_Level__c
                                     FROM Opportunity];
        TestResults results = getTestResults(oppList);
        doDefaultAssertions(oppList, results);
        System.assert(results.quoteLines.size() > 0, 'Quote lines should be created.');
    }

    @isTest 
    static void editionUpgradeTest() {        
        Test.startTest();
        arrange(new ArrangeParams('Enterprise', 300.00, 'Kayako', 'None', 'Growth', 'Standard', 0.00));
        Test.stopTest();

        // Assert
        List<Opportunity> oppList = [SELECT Type, Current_Success_Level__c
                                     FROM Opportunity];
        TestResults results = getTestResults(oppList);
        doDefaultAssertions(oppList, results);
        System.assert(results.quoteLines.size() == 1, 'One quote line should be created.');
    }

    @isTest 
    static void addonsTest() {        
        Test.startTest();
        arrange(new ArrangeParams('Enterprise', 0.00, 'Kayako', 'None', 'Growth', 'Standard', 100.00));
        Test.stopTest();

        // Assert
        List<Opportunity> oppList = [SELECT Type, Current_Success_Level__c
                                     FROM Opportunity];
        TestResults results = getTestResults(oppList);
        doDefaultAssertions(oppList, results);
        System.assert(results.quoteLines.size() == 2, 
                        'Quote lines for the main product and the add-on should be created.');
    }
    
    @isTest 
    static void given_OpportunityWithOptOutEmailContact_When_DefaultConfiguration_Verify_OppDescriptionAndStageNameCorrect() {
        Test.startTest();
        ArrangeParams params = new ArrangeParams('Standard', 300.00, 'Kayako', 'Standard', 'Growth', 'Standard', 0.00);
        Contact contact = new Contact(LastName = 'LastName', Email = params.email, HasOptedOutOfEmail = true);
        insert contact;
        arrange(params);
        Test.stopTest();
        
        // Assert
        List<Opportunity> oppList = [SELECT Type, Current_Success_Level__c, Description, StageName
                                     FROM Opportunity];
        String dateStr = Date.today().format();
        System.assertEquals(dateStr + ': The Primary Contact (' + params.email + ') has Opted Out of email communication. Use alternate means to engage or identify an alternate contact.', oppList[0].Description);
        System.assertEquals('Pending', oppList[0].StageName);
    }

    @isTest
    static void given_Product_And_ProductConfiguration_When_OpportunityWith_Null_CurrentProductData_Verify_Opportunity_Is_NotNull(){
        Test.startTest();
        arrange(new ArrangeParams('Enterprise', 300.00, null, null, null, null, 0.00));
        Test.stopTest();
    
        // Assert
        List<Opportunity> oppList = [SELECT Type, Current_Success_Level__c, Description, StageName
                                     FROM Opportunity];
        System.assert(oppList[0] != null);
        System.assertEquals('Pending', oppList[0].StageName);
        System.assertEquals('Renewal', oppList[0].Type);
    }

    @isTest
    static void given_Product_And_ProductConfiguration_When_OpportunityWith_Null_CurrentProductEdition_Verify_Opportunity_Is_NotNull(){
        Test.startTest();
        arrange(new ArrangeParams('Enterprise', 300.00, 'Kayako', null, 'Growth', 'Standard', 0.00));
        Test.stopTest();

        // Assert
        List<Opportunity> oppList = [SELECT Type, Current_Success_Level__c, Description, StageName
                                     FROM Opportunity];
        System.assert(oppList[0] != null);
        System.assertEquals('Pending', oppList[0].StageName);
        System.assertEquals('Renewal', oppList[0].Type);
    }

    static TestResults getTestResults(List<Opportunity> oppList){
        List<OpportunityLineItem> lineItems = [SELECT Quantity
                                               FROM OpportunityLineItem
                                               WHERE OpportunityId = :oppList[0].Id];
        SBQQ__Quote__c quote = [SELECT Id
                                FROM SBQQ__Quote__c
                                WHERE SBQQ__Opportunity2__c = :oppList[0].Id];
        List<SBQQ__QuoteLine__c> quoteLines = [SELECT Id, SBQQ__Quote__c, SBQQ__Quantity__c
                                               FROM SBQQ__QuoteLine__c];
        return new TestResults(lineItems, quote, quoteLines);
    }

    static void doDefaultAssertions(List<Opportunity> oppList, TestResults results){
        System.assertEquals('Renewal', oppList[0].Type, 'Renewal opportunity type should be set.');
        System.assertEquals('Standard', oppList[0].Current_Success_Level__c,
            'Success Level should be set for the opportunity');
        System.assertEquals(20, results.lineItems[0].Quantity, 'Quantity should be set');
        System.assert(results.quote != null, 'Quote should be created.');
    }

    public static void arrange(ArrangeParams arrangeParams){
        Account acct = new Account(Name='Test Account');
        insert acct;
        List<Contact> cont = [SELECT Id,AccountId from Contact WHERE Email=:arrangeParams.email];
        if(cont!=null && !cont.isEmpty()) {
			cont[0].AccountId = acct.Id;
            update cont;            
        }

        Id idPricebook = Test.getStandardPricebookId();
        // Product2
        Product2 productDb = new Product2(Name = 'Kayako:Standard:Standard:0:49:Yearly', CanUseRevenueSchedule = false,
            IsActive = true, Product__c = arrangeParams.productName, ProductCode = 'starter',
            Family = arrangeParams.productName, Success_Level__c = arrangeParams.productSuccessLevel,
            Product_Edition__c = arrangeParams.productEdition,
            Product_Edition_Label__c = arrangeParams.productEditionLabel, Min_Quantity__c = arrangeParams.minQuantity,
            Max_Quantity__c = arrangeParams.maxQuantity, Subscription_Terms__c = '1;12;24');
        insert productDb;

        // Product2
        Product2 productAddon = new Product2(Name = 'Kayako:Collaborators', CanUseRevenueSchedule = false,
            IsActive = true, Product__c = 'Collaborators', ProductCode = 'starter1',
            Family = arrangeParams.productName, Success_Level__c = arrangeParams.productSuccessLevel,
            Product_Edition__c = arrangeParams.productEdition,
            Product_Edition_Label__c = arrangeParams.productEditionLabel, Min_Quantity__c = arrangeParams.minQuantity,
            Max_Quantity__c = arrangeParams.maxQuantity, Subscription_Terms__c = '1;12;24');
        insert productAddon;

        Id userId = TestData.getUser('System Administrator').Id;
        // Pricebook
        Pricebook2 standardPricebook = new Pricebook2(Id = idPricebook, IsActive = true);
        update standardPricebook;
        // PriceBookEntry
        PriceBookEntry priceBook = new PriceBookEntry(UnitPrice = arrangeParams.unitPrice, Product2Id = productDb.Id, IsActive = true, PriceBook2Id = idPricebook, UseStandardPrice = false);
        insert priceBook;
        PriceBookEntry priceBookAddons = new PriceBookEntry(UnitPrice = arrangeParams.unitPrice, Product2Id = productAddon.Id, IsActive = true, PriceBook2Id = idPricebook, UseStandardPrice = false);
        insert priceBookAddons;

        Subsidiary__c subsidiary = new Subsidiary__c();
        insert subsidiary;
        Product_Configuration__c prodConfigDb = TestData.createProductConfiguration(subsidiary.Id, null, arrangeParams.productName);
        String netSuiteId = arrangeParams.productName == 'Kayako' ? '' :
            String.valueOf(Integer.valueof((Math.random() * 1000000000)));
        String parentSubscriptionId = 'A-S00000000';
        Opportunity opp = new Opportunity(Name = acct.Name + ' Opportunity', StageName = 'Pending', Type = 'Renewal',
            CloseDate = System.today().addMonths(1), AccountId = acct.Id, OwnerId = userId,
            Product_Configuration__c = prodConfigDb.Id, Product__c = arrangeParams.productName,
            Current_Product__c = arrangeParams.currentProduct,
            Current_Product_Edition__c = arrangeParams.currentProductEdition,
            Current_Product_Edition_Label__c = arrangeParams.currentProductEditionLabel,
            Current_Success_Level__c = arrangeParams.currentSuccessLevel,
            Current_Billing_Term__c = arrangeParams.billingTerm, Current_Term__c = arrangeParams.currentTerm,
            Current_ARR__c = arrangeParams.currentARR, Current_Seats__c = arrangeParams.quantity,
            Current_Primary_Contact_Email__c = arrangeParams.email, Renewal_Date__c = Date.today(),
            Current_Addons__c = arrangeParams.currentAddonsARR == 0.0 ? 0 : 1,
            Current_Addons_ARR__c = arrangeParams.currentAddonsARR,
            NetSuite_ID__c = netSuiteId,
            Parent_Subscription_ID__c = parentSubscriptionId);
        insert opp;
    }
    
}