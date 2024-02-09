@IsTest
public with sharing class CalculateOpportunityTermTest {

    private static Account createAccount(String name) {
        Account acct = new Account(Name = name);
        insert acct;
        return acct;
    }

    private static Product2 createProduct(String name, String chargeType, String edition) {
        Product2 product;
        product = new Product2(
                Name = name,
                CanUseRevenueSchedule = false,
                IsActive = true,
                Product__c = 'Sococo',
                ProductCode = name,
                Min_Quantity__c = 1,
                SBQQ__SubscriptionTerm__c = 12,
                Subscription_Terms__c = '1;12;24',
                SBQQ__ChargeType__c = chargeType,
                Product_Edition__c = edition);

        if (chargeType == 'Recurring') {
                product.SBQQ__BillingType__c = 'Advance';
        }

        insert product;
        return product;

    }

    private static void createPriceBookEntry(Product2 productDb, Decimal unitPrice) {
        // PriceBook2
        PriceBook2 pb2 = new PriceBook2(Name = 'Standard Price Book',
                IsActive = true);
        insert pb2;
        Id idPricebook = Test.getStandardPricebookId();
        // PriceBookEntry
        PriceBookEntry priceBook = new PriceBookEntry(UnitPrice = unitPrice,
                Product2Id = productDb.Id,
                IsActive = true,
                PriceBook2Id = idPricebook,
                UseStandardPrice = false);
        insert priceBook;
    }

    private static void createProductConfiguration() {
        // Product_Configuration__c
        Subsidiary__c subsidiary = new Subsidiary__c();
        insert subsidiary;
        Product_Configuration__c prodConfig = TestData.createProductConfiguration(subsidiary.Id, null, 'Sococo');
    }

    private static void createOpportunity(Account acct, Product_Configuration__c prodConfigDb) {
        Opportunity opp = new Opportunity(Name = acct.Name + ' Opportunity',
                StageName = 'Prospecting',
                CloseDate = System.today().addMonths(1),
                AccountId = acct.Id,
                Product_Configuration__c = prodConfigDb.Id,
                Type = 'test',
                Product__c = 'Sococo');
        insert opp;
    }

    @isTest
    public static void opportunityTermIsMaxRecurringNonAddonLineItemsWithPriceGreaterThanZero() {
        Decimal term = 12;
        Decimal quantity = 5;
        Decimal unitPrice = 1500;
        Account acct = createAccount('Test Account');
        // Product2
        createProduct('Sococo:Standard:Standard:0:49:Monthly', 'Recurring','Standard');
        Product2 productDb = [SELECT Id,Product_Edition__c, SBQQ__ChargeType__c FROM Product2 
                              WHERE name = 'Sococo:Standard:Standard:0:49:Monthly'];
        
        createPriceBookEntry(productDb, unitPrice);
        PriceBookEntry priceBookDb = [SELECT Id FROM PriceBookEntry where Product2Id = :productDb.Id];
        createProductConfiguration();
        Product_Configuration__c prodConfigDb = [SELECT Id FROM Product_Configuration__c];
        // Opportunity
        createOpportunity(acct, prodConfigDb);
         
        Opportunity oppDb = [SELECT Id FROM Opportunity];
        // OpportunityLineItem       
        
        oppDb = [SELECT Id, Opportunity_Term__c FROM Opportunity];
        OpportunityLineItem lineItem = new OpportunityLineItem(Product2Id = productDb.Id,
                Quantity = quantity,
                PricebookEntryId = priceBookDb.Id,
                OpportunityId = oppDb.Id,
                UnitPrice = unitPrice,
                Subscription_Term__c = term);
        insert lineItem;

        oppDb = [SELECT Id, Opportunity_Term__c FROM Opportunity];
        createProduct('Sococo:Usage', 'Usage', 'Standard');
        productDb = [SELECT Id,Product_Edition__c, SBQQ__ChargeType__c FROM Product2 
                              WHERE name = 'Sococo:Usage'];
        createPriceBookEntry(productDb, unitPrice * 2);
        priceBookDb = [SELECT Id FROM PriceBookEntry where Product2Id = :productDb.Id];
        
        lineItem = new OpportunityLineItem(Product2Id = productDb.Id,
                Quantity = quantity,
                PricebookEntryId = priceBookDb.Id,
                OpportunityId = oppDb.Id,
                UnitPrice = unitPrice * 2,
                Subscription_Term__c = term * 2);
        insert lineItem;
       
        oppDb = [SELECT Id, Opportunity_Term__c FROM Opportunity];

        createProduct('Sococo:Add-On', 'Recurring', 'Add-On');
        productDb = [SELECT Id,Product_Edition__c, SBQQ__ChargeType__c FROM Product2 
                              WHERE name = 'Sococo:Add-On'];
        createPriceBookEntry(productDb, unitPrice * 5);
        priceBookDb = [SELECT Id FROM PriceBookEntry where Product2Id = :productDb.Id];
        
        lineItem = new OpportunityLineItem(
                Product2Id = productDb.Id,
                Quantity = quantity,
                PricebookEntryId = priceBookDb.Id,
                OpportunityId = oppDb.Id,
                UnitPrice = unitPrice * 5,
                Subscription_Term__c = term * 5);
        insert lineItem;

        oppDb = [SELECT Id, Opportunity_Term__c FROM Opportunity];
        System.assert(oppDb.Opportunity_Term__c == term, 'Opportunity term should be calculated ' +
                ' as max line item term of line items with unit price > 0 and charge type = ' +
                'rechange and edition != add on');

    }
}