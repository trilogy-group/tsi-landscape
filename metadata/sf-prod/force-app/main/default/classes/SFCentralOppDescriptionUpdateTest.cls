@isTest
public without sharing class SFCentralOppDescriptionUpdateTest {
    private static String PRODUCT_FAMILY = 'Kayako';
    private static Integer QUANTITY_NO = 5;
    private static Integer UNIT_PRICE = 120; 
    private static String CENTRAL_PRD_NAME = 'Kayako_Central_Product_Name';
    private static String CENTRAL_PRD_CODE = 'Kayako_Central_Product_Code';
    
    static void arrange() {
        Account acct = new Account(Name='Test Account');
        insert acct;
        Id idPricebook = Test.getStandardPricebookId();
        // Product2
        Product2 productDb = new Product2(Name = 'Kayako:Standard:Standard:0:49:Yearly',
            IsActive = true, Product__c = PRODUCT_FAMILY, ProductCode = 'starter', 
            Family = PRODUCT_FAMILY, Success_Level__c = 'Standard', 
            Product_Edition__c = 'Standard', 
            Min_Quantity__c = 1, 
            Max_Quantity__c = 50, 
            Subscription_Terms__c = '1;12;24');
        insert productDb;
        Id userId = TestData.getUser('System Administrator').Id;
         // Pricebook
        Pricebook2 standardPricebook = new Pricebook2(Id = idPricebook, IsActive = true);
        update standardPricebook;
        // PriceBookEntry
        PriceBookEntry priceBook = new PriceBookEntry(UnitPrice = UNIT_PRICE, 
                                                      Product2Id = productDb.Id, 
                                                      IsActive = true, 
                                                      PriceBook2Id = idPricebook, 
                                                      UseStandardPrice = false);
        insert priceBook;
        Subsidiary__c subsidiary = new Subsidiary__c();
        insert subsidiary;
        Product_Configuration__c prodConfigDb = TestData.createProductConfiguration(subsidiary.Id, null, PRODUCT_FAMILY);
        Opportunity opp = new Opportunity(Name = acct.Name + ' Opportunity', StageName = 'Pending', Type = 'Renewal',
            CloseDate = System.today().addMonths(1), AccountId = acct.Id, OwnerId = userId, 
            Product_Configuration__c = prodConfigDb.Id, 
            Product__c = PRODUCT_FAMILY,
            Current_Product__c = 'Kayako Standard',
            Current_Product_Edition__c = 'Standard',
            Current_Success_Level__c = 'Standard',
            Current_Billing_Term__c = 'Annual', 
            Current_Term__c = 1,
            Current_ARR__c = 1500, 
            Current_Seats__c = 1,
            Current_Primary_Contact_Email__c = 'test@test.com', 
            Renewal_Date__c = Date.today(),
            Current_Addons__c = 0,
            Current_Addons_ARR__c = 0,
            //Quoting_Entity__c = 'Aclate',
            Parent_Subscription_ID__c = 'A-S00000000');
        insert opp;

        //create your opportunity line item. 
        OpportunityLineItem oli = new OpportunityLineItem(
            OpportunityId = opp.Id,
            Quantity = QUANTITY_NO,
            Subscription_Term__c = 12,
            PricebookEntryId = priceBook.Id,
            TotalPrice = QUANTITY_NO * priceBook.UnitPrice,
            Central_ProductName__c = CENTRAL_PRD_NAME,
            Central_ProductCode__c = CENTRAL_PRD_CODE
        );
        insert oli;

    }
    @isTest static void centralOpportunityDescUpdateBatchTest() {
        arrange();   

        Test.startTest();   
        SFCentralOppDescriptionUpdate sf = new SFCentralOppDescriptionUpdate(PRODUCT_FAMILY, 
                                                new String[] {'test@test.com'});    
        Database.executeBatch(sf,1);
        Test.stopTest();

        Opportunity opp = [Select ID, Description from Opportunity limit 1];
        System.assertEquals(getDescriptionFieldTestText(), 
                            opp.Description, 
                            'Error Generated Description is not Correct');
    }

    private static String getDescriptionFieldTestText() {
        List<Opportunity> opportunities = [SELECT Id, Description, CreatedDate from Opportunity];
        String description = '';
        for (Opportunity opp : opportunities) {
            description += String.format('{0}/{1}/{2} System: Opportunity migrated from Central SF:', 
                                    new String[]{ String.valueOf(opp.CreatedDate.month()), 
                                                  String.valueOf(opp.CreatedDate.day()), 
                                                  String.valueOf(opp.CreatedDate.year()).substring(2) });
            description += '\r\n';
            description += '----------------------------------------';
            description += '\r\n';
            List<OpportunityLineItem> lineItems = [SELECT Central_ProductName__c, Central_ProductCode__c, 
                                                          Id, Subscription_Term__c, Quantity, TotalPrice
                                                   FROM OpportunityLineItem
                                                   WHERE  OpportunityId = :opp.Id];
            Integer rowNumber = 1;
            for (OpportunityLineItem item: lineItems) {
                description += String.format('{0}- {1}  {2} T:{3} Q:{4} TP:{5}', 
                                        new String[] {String.valueOf(rowNumber),
                                                      item.Central_ProductName__c, 
                                                      item.Central_ProductCode__c, 
                                                      String.valueOf(item.Subscription_Term__c), 
                                                      String.valueOf(item.Quantity), 
                                                      String.valueOf(item.TotalPrice)});
                description += '\r\n';
                rowNumber += 1;
            }
            
            description += '----------------------------------------';
        }
        return description;
    }
}