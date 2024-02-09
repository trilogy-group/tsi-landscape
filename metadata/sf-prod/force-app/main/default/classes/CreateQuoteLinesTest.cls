@isTest
public class CreateQuoteLinesTest {
    @isTest static void testCreateQuoteFromProductAndSubscriptionItems() {
        String subscriptionTerm = '12;36;60';
        // Prepare test data
        Product2 prod = new Product2(
            Name = 'Main Product',
            ProductCode='PR1-PR2-PR3-STA-SIL',
            Min_Quantity__c = 1,
            Product__c = 'Test Main Product',
            Subscription_Terms__c = subscriptionTerm
        );
        insert prod;
        Product2 prod2 = new Product2(
            Name = 'Option Bundle Product',
            ProductCode='PR1-PR2-PR3-ADD-SIL',
            Min_Quantity__c = 1,
            Product__c = 'Test Option Bundle Product',
            Subscription_Terms__c = subscriptionTerm
        );
        insert prod2;
        Product2 prod3 = new Product2(
            Name = 'Option Product Item',
            ProductCode='PR1-PR2-PR3-AD1',
            Min_Quantity__c = 1,
            Product__c = 'Test Option Product Item',
            Subscription_Terms__c = subscriptionTerm
        );
        insert prod3;
        Product2 prod4 = new Product2(
            Name = 'Option Support Item',
            ProductCode='PR1-PR2-PR3-SIL',
            Min_Quantity__c = 1,
            Product__c = 'Test Option Support Item',
            Subscription_Terms__c = subscriptionTerm
        );
        insert prod4;
        Product2 prod5 = new Product2(
            Name = 'Option Support Item',
            ProductCode='PR1-PR2-PR3-ADD',
            Min_Quantity__c = 1,
            Product__c = 'Test Bundle Option Product Item',
            Subscription_Terms__c = subscriptionTerm
        );
        insert prod5;

        SBQQ__ProductOption__c productOption = new SBQQ__ProductOption__c(
            SBQQ__Number__c = 1,
            SBQQ__ConfiguredSKU__c = prod.Id,
            SBQQ__OptionalSKU__c = prod2.Id,
            SBQQ__Bundled__c = false
        );
        insert productOption;
        productOption = new SBQQ__ProductOption__c(
            SBQQ__Number__c = 2,
            SBQQ__ConfiguredSKU__c = prod.Id,
            SBQQ__OptionalSKU__c = prod3.Id,
            SBQQ__Bundled__c = false
        );
        insert productOption;
        productOption = new SBQQ__ProductOption__c(
            SBQQ__Number__c = 3,
            SBQQ__ConfiguredSKU__c = prod.Id,
            SBQQ__OptionalSKU__c = prod4.Id,
            SBQQ__Bundled__c = false
        );
        insert productOption;
        productOption = new SBQQ__ProductOption__c(
            SBQQ__Number__c = 1,
            SBQQ__ConfiguredSKU__c = prod2.Id,
            SBQQ__OptionalSKU__c = prod5.Id,
            SBQQ__Bundled__c = true
        );
        insert productOption;

        Account acc = new Account(Name = 'Test Account');
        insert acc;
        SBQQ__Quote__c quote = new SBQQ__Quote__c(SBQQ__Account__c = acc.Id);
        insert quote;
        SBQQ__QuoteLine__c quoteLine = new SBQQ__QuoteLine__c(
            SBQQ__Quote__c = quote.Id    
        );

        CreateQuoteLines.CreateQuoteInput input = new CreateQuoteLines.CreateQuoteInput();
        input.productId = prod.Id;
        input.quoteId = quote.Id;
        input.currencyIsoCode = 'USD';
        input.subscriptionTerm = 12;
        input.mainProductLineId = quoteLine.Id;
        input.newSuccessLevel = 'SIL';
        input.nextBundledQuoteLineNumber = 1;

        SubscriptionItem subItem = new SubscriptionItem();
        subItem.isMainItem = true;
        input.subscriptionItems = new List<SubscriptionItem>{subItem};

        subItem = new SubscriptionItem();
        subItem.code = 'PR1-PR2-PR3-ADD';
        subItem.bundleCode = prod2.ProductCode;
        subItem.quantity = 1;
        subItem.isMainItem = false;
        input.subscriptionItems.add(subItem);

        subItem = new SubscriptionItem();
        subItem.code = 'PR1-PR2-PR3-AD1';
        subItem.supportCode = 'PR1-PR2-PR3-SIL';
        subItem.bundleCode = 'PR1-PR2-PR3-AD1-SIL';
        subItem.quantity = 1;
        subItem.isMainItem = false;
        input.subscriptionItems.add(subItem);

        Test.startTest();

        // Execute method
        List<String> quoteLineIdsString = CreateQuoteLines.createQuoteFromProductAndSubscriptionItems(
            new List<CreateQuoteLines.CreateQuoteInput>{input});

        Test.stopTest();

        // Verify results
        System.assertNotEquals(null, quoteLineIdsString);
        System.assertEquals(1, quoteLineIdsString.size());

        // Verify that a new quote line was created
        List<string> quoteLineIds = quoteLineIdsString[0].replace('QuoteLineIds created: ','').split(' - ');
        System.assertEquals(4, quoteLineIds.size());
        SBQQ__QuoteLine__c quoteLineResult = [SELECT Id, SBQQ__Quote__c, SBQQ__Product__c
                                                FROM SBQQ__QuoteLine__c WHERE Id = :quoteLineIds[0]];
        System.assertEquals(quote.Id, quoteLineResult.SBQQ__Quote__c);
        System.assertEquals(prod2.Id, quoteLineResult.SBQQ__Product__c);
    }
}