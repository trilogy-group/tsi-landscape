@isTest
public with sharing class MigrationQuoteCreationBatchTest {
    @isTest
    public static void e2eTest(){
        arrange(15.00, 20, 1, null);
        Test.startTest();
        Database.executeBatch(new MigrationQuoteCreationBatch('Sococo'), 1);
        Test.stopTest();
        LIST<SBQQ__Quote__c> quotes = [SELECT ID, CreatedDate, CreatedBy.Name
        FROM SBQQ__Quote__c];
        System.assert(quotes.size() > 0, 'Quotes should be created.');
    }

    @isTest
    public static void e2eForOneOppTest(){
        arrange(15.00, 20, 1, null);
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Test.startTest();
        Database.executeBatch(new MigrationQuoteCreationBatch(opp.Id), 1);
        Test.stopTest();
        LIST<SBQQ__Quote__c> quotes = [SELECT ID, CreatedDate, CreatedBy.Name, CurrencyIsoCode
                                        FROM SBQQ__Quote__c];
        System.assert(quotes.size() == 1, 'A Quote should be created.');
    }

    @isTest
    public static void e2eForEuroOppTest(){
        arrange(15.00, 20, 1, 'EUR');
        Opportunity opp = [SELECT Id, CurrencyIsoCode FROM Opportunity LIMIT 1];
        Test.startTest();
        Database.executeBatch(new MigrationQuoteCreationBatch(opp.Id), 1);
        Test.stopTest();
        LIST<SBQQ__Quote__c> quotes = [SELECT ID, CreatedDate, CreatedBy.Name, CurrencyIsoCode
                                        FROM SBQQ__Quote__c];
        System.assert(quotes.size() == 1, 'A Quote should be created.');
        System.assert(quotes[0].CurrencyIsoCode == opp.CurrencyIsoCode, 
                        'Quote currency should match Opportunity currency');
    }

    @isTest
    public static void notRenewalOpportunitiesShouldNotBeProcessed(){
        arrange(15.00, 20, 1, null);
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        opp.type = 'New Business';
        update opp;
        Test.startTest();
        Database.executeBatch(new MigrationQuoteCreationBatch(opp.Id), 1);
        List<SBQQ__Quote__c> quotes = [SELECT Id,SBQQ__Opportunity2__c 
                                        FROM SBQQ__Quote__c LIMIT 10];
        Test.stopTest();
        
        // Assert
        System.assert(quotes.size() == 0, 'A Quote should not be generated for non renewal opportunities');
    }

    static void arrange(Decimal unitPrice, Integer quantity, Integer term, String currencyIsoCode){
        Account acct = new Account(Name='Test Account');
        insert acct;
        // Product2
        Product2 product;
            product = new Product2(    Name = 'Sococo:Standard:Standard:0:49:Monthly',
                                       CanUseRevenueSchedule = false,
                                       IsActive = true,
                                       Product__c = 'Sococo',
                                       ProductCode = 'starter',
                                       Subscription_Terms__c = '1',
                                       Min_Quantity__c = 1,
                                       SBQQ__SubscriptionTerm__c=12);
        insert product;
        Product2 productDb = [SELECT Id FROM Product2];
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
        
        PriceBookEntry priceBookDb = [SELECT Id FROM PriceBookEntry];

        if (currencyIsoCode != null) {
            CurrencyType currencyType = [SELECT ConversionRate, Id, IsActive, IsoCode 
                                            FROM CurrencyType where isoCode = :currencyIsoCode
                                        ];
            PriceBookentry currencyEntry = new PricebookEntry(
            Pricebook2Id = idPricebook,
            Product2Id = productDb.Id,
            UnitPrice = unitPrice * currencyType.ConversionRate,
            CurrencyIsoCode = currencyIsoCode,
            IsActive = true);
            insert currencyEntry;

            priceBookDb = [SELECT Id FROM PriceBookEntry WHERE CurrencyIsoCode = :currencyIsoCode];
        }


        // Product_Configuration__c
        Subsidiary__c subsidiary = new Subsidiary__c();
        insert subsidiary;
        Product_Configuration__c prodConfig = TestData.createProductConfiguration(subsidiary.Id, null, 'Sococo');
        Product_Configuration__c prodConfigDb = [SELECT Id FROM Product_Configuration__c];
        // Opportunity
        Opportunity opp = new Opportunity(Name=acct.Name + ' Opportunity',
                                       StageName='Prospecting',
                                       CloseDate=System.today().addMonths(1),
                                       AccountId=acct.Id,
                                       Product_Configuration__c = prodConfigDb.Id,
                                       Type = 'Renewal',
                                       Product__c = 'Sococo',
                                       Renewal_Date__c = system.today(),
                                       Parent_Subscription_ID__c = 'A-S00000000',
                                       CurrencyIsoCode = (currencyIsoCode == null ? 'USD' : currencyIsoCode));
        insert opp;
        Opportunity oppDb = [SELECT Id FROM Opportunity];
        // OpportunityLineItem       
        OpportunityLineItem lineItem = new OpportunityLineItem(Product2Id = productDb.Id,
                                                              Quantity = quantity,
                                                              PricebookEntryId = priceBookDb.Id,
                                                              OpportunityId = oppDb.Id,
                                                              UnitPrice = unitPrice,
                                                              Subscription_Term__c = term);
        insert lineItem;
    }
}