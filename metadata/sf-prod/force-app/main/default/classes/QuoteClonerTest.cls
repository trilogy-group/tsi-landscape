@isTest
public class QuoteClonerTest {
    @isTest
    public static void testCloneQuoteWithLineItems() {
        // Create a test Quote with line items
        TestData.QuoteWithLineItems testData = TestData.createQuoteWithLineItems('Annually', 15.00, 20, '1');
        
        // Clone the Quote with line items
        QuoteCloner.FlowInput flowInput = new QuoteCloner.FlowInput();
        flowInput.quoteId = testData.quoteId;
        QuoteCloner.FlowOutput flowOutput = QuoteCloner.cloneQuote(new List<QuoteCloner.FlowInput>{flowInput})[0];
        
        // Verify that the cloned Quote and line items were created
        System.assertNotEquals(null, flowOutput.clonedQuoteId);
        List<SBQQ__QuoteLine__c> originalLineItems = [SELECT Id, SBQQ__Product__c, SBQQ__Quantity__c, SBQQ__ListPrice__c
            FROM SBQQ__QuoteLine__c WHERE SBQQ__Quote__c = :testData.quoteId];
        List<SBQQ__QuoteLine__c> clonedLineItems = [SELECT Id, SBQQ__Product__c, SBQQ__Quantity__c, SBQQ__ListPrice__c
            FROM SBQQ__QuoteLine__c WHERE SBQQ__Quote__c = :flowOutput.clonedQuoteId];        
        System.assertEquals(originalLineItems.size(), clonedLineItems.size());
        System.assertEquals(originalLineItems[0].SBQQ__Product__c, clonedLineItems[0].SBQQ__Product__c);
        System.assertEquals(originalLineItems[0].SBQQ__Quantity__c, clonedLineItems[0].SBQQ__Quantity__c);
        System.assertEquals(originalLineItems[0].SBQQ__ListPrice__c, clonedLineItems[0].SBQQ__ListPrice__c);
    }
}