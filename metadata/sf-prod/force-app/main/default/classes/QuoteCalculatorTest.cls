@IsTest
public class QuoteCalculatorTest {
    @IsTest
    static void calculatorTest() {
      //Arrange
    	TestData.QuoteWithLineItems testData = TestData.createQuoteWithLineItems('Monthly', 15.00, 20, '1');

      //Act
      SBQQ__Quote__c quote = [SELECT Id FROM SBQQ__Quote__c WHERE Id =: testData.quoteId];
      String quoteJSON = SBQQ.ServiceRouter.read('SBQQ.QuoteAPI.QuoteReader', testData.quoteId);
      Map<String, Object> q = (Map<String, Object>) JSON.deserializeUntyped(quoteJSON);
      QuoteCalculator calculator = new QuoteCalculator();
      calculator.calculate(q, 'CalculatorCallback');

      quote.SBQQ__Opportunity2__c = testData.opportunityId;
      quote.SBQQ__Primary__c = True;

      update quote;

      quote = [SELECT SBQQ__NetAmount__c FROM SBQQ__Quote__c WHERE Id =: testData.quoteId];
      //Assert
      System.assertEquals(300.0, quote.SBQQ__NetAmount__c);
    }

}