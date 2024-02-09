@IsTest
private class AutoConvertLeadsCPQTest{
    static List<Id> LeadIds;
    static final String PRODUCT_NAME = 'Kayako';
    static final String USER_PROFILE = 'System Administrator';
    static final String USER_ROLE = 'ISR';
    static final String MANAGER_PROFILE = 'Team Manager';
    static final String MANAGER_ROLE = 'Manager New Sales';

    @isTest
    static void leadAssign_ShouldSilentlyIgnoresInvalidLeadIds(){
        // Given there is a list containing non existing lead ids
        LeadIds = new List<Id>{'001xa000003DIloAAG'};

        // When we convert the lead
        Test.startTest();
        Exception actualException = null;
        try{
            AutoConvertLeadsCPQ.leadAssign(leadIds);
        } catch (Exception dmx){
            actualException = dmx;
        }
        Test.stopTest();

        // Then the exception shouldn't be thrown
        System.assertEquals(null, actualException);
    }

    @isTest
    static void leadAssign_ShouldConvertTheLead(){
        User userManager = TestData.getUser(MANAGER_PROFILE);
        TestData.updateUserRole(userManager, MANAGER_ROLE);
        User user = TestData.createTestUser(USER_PROFILE, USER_ROLE, PRODUCT_NAME, userManager);
        arrange(true);

        Test.startTest();
        Exception actualException = null;
        try{
            SBQQ.TriggerControl.disable();
            try{
                // Given there is a lead
                Lead lead = new Lead(OwnerId = user.Id, Product__c = TestData.PRODUCT_FAMILY, Country = null,
                    PostalCode = null, LastName = TestData.LAST_NAME, Company = TestData.TEST_COMPANY, City = null,
                    Set_Google_Timezone__c = true, Status = 'MQL', IsConverted = false);
                insert lead;
                lead.Status = 'Engaged';
                update lead;
                //When creating Lead this method will be call in OnLeanUpdate Flow
                //AutoConvertLeadsCPQ.leadAssign(new List<Id>{lead.Id});
            } finally{
                SBQQ.TriggerControl.enable();
            }
        } catch (Exception dmx){
            actualException = dmx;
        }
        Test.stopTest();

        // Then the exception shouldn't be thrown
        System.assertEquals(null, actualException);

        // Then must have one opportunity created with Created from lead set
        List<Opportunity> opp = [SELECT Created_From_Lead__c FROM Opportunity];
        System.assertEquals(1,opp.size());
        System.assertEquals(true,opp[0].Created_From_Lead__c);
    }

    @isTest
    static void leadAssign_ShouldConvertLeadWithoutActiveProduct(){
        User userManager = TestData.getUser(MANAGER_PROFILE);
        TestData.updateUserRole(userManager, MANAGER_ROLE);
        User user = TestData.createTestUser(USER_PROFILE, USER_ROLE, PRODUCT_NAME, userManager);
        arrange(false);

        Test.startTest();
        Exception actualException = null;
        try{
            SBQQ.TriggerControl.disable();
            try{
                // Given there is a lead
                Lead lead = new Lead(OwnerId = user.Id, Product__c = TestData.PRODUCT_FAMILY, Country = null,
                    PostalCode = null, LastName = TestData.LAST_NAME, Company = TestData.TEST_COMPANY, City = null,
                    Set_Google_Timezone__c = true, Status = 'MQL', IsConverted = false,
                    Product_Edition__c = TestData.PRODUCT_EDITION_LABEL);
                insert lead;
                lead.Status = 'Engaged';
                update lead;
                //When creating Lead this method will be call in OnLeanUpdate Flow
                //AutoConvertLeadsCPQ.leadAssign(new List<Id>{lead.Id});
            } finally{
                SBQQ.TriggerControl.enable();
            }
        } catch (Exception dmx){
            actualException = dmx;
        }
        Test.stopTest();

        // Then the exception shouldn't be thrown
        System.assertEquals(null, actualException);

        // Then must have one opportunity created with Created from lead set
        List<Opportunity> opp = [SELECT Created_From_Lead__c FROM Opportunity];
        System.assertEquals(1,opp.size());
        System.assertEquals(true,opp[0].Created_From_Lead__c);
    }

    private static void arrange(Boolean productIsActive){
        Product2 product = new Product2(Name = String.format('{0}:Standard:Standard:0:49:Yearly',
            new String[]{AutoConvertLeadsCPQTest.PRODUCT_NAME}), CanUseRevenueSchedule = false,
            IsActive = productIsActive, Product__c = AutoConvertLeadsCPQTest.PRODUCT_NAME,
            ProductCode = TestData.PRODUCT_CODE, Family = TestData.PRODUCT_FAMILY,
            Success_Level__c = TestData.PRODUCT_SUCCESS_LEVEL, Product_Edition__c = TestData.PRODUCT_EDITION,
            Product_Edition_Label__c = TestData.PRODUCT_EDITION_LABEL, Min_Quantity__c = 1, Max_Quantity__c = 999,
            Subscription_Terms__c = '12;24');
        insert product;
        
        Subsidiary__c subsidiary = new Subsidiary__c();
        insert subsidiary;
        Product_Configuration__c productConfig = TestData.createProductConfiguration(subsidiary.Id, null, TestData.PRODUCT_FAMILY);

        id standardPBID = Test.getStandardPricebookId();
        PricebookEntry stdPBE = new PriceBookEntry(Product2Id = product.Id, Pricebook2Id = standardPBID,
            UnitPrice = 3000000.00, UseStandardPrice = false, IsActive = true);
        insert stdPBE;

        PriceBook2 customPriceBook = new PriceBook2();
        customPriceBook.Name = 'Custom Pricebook';
        customPriceBook.IsActive = true;
        insert customPriceBook;

        PricebookEntry cusPBE = new PriceBookEntry(Product2Id = product.Id, Pricebook2Id = customPriceBook.Id,
            UnitPrice = 5000000.00, UseStandardPrice = false, IsActive = true);
        insert cusPBE;
    }
}