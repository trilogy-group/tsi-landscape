@isTest
public class UpdateOpportunityMRRFromProductsTest {
    @isTest
    static void given_MonthlySubscription_When_MonthlyTerm_Verify_ARRandTCV() {
        //Arrange
        arrange('Recurring', 15.00, 20, '1');

        // Act
        Opportunity oppDb2 = [SELECT MRR__c FROM Opportunity];

        // Verify
        System.assertEquals(300.0, oppDb2.MRR__c);
    }

    @isTest
    static void given_YearlySubscription_When_SingleTerm_Then_ARRandTCVEqualsYearlyValue() {
        //Arrange
        arrange('Recurring', 15.00, 20, '12');

        // Act
        Opportunity oppDb2 = [SELECT MRR__c FROM Opportunity];

        // Verify
        System.assertEquals(300, oppDb2.MRR__c);
    }

    @isTest
    static void given_YearlySubscription_When_TwoYearsTerm_Then_TCVEqualsTwoYearValueARROneYearValue() {
        //Arrange
        arrange('Recurring', 15.00, 20, '24');

        // Act
        Opportunity oppDb2 = [SELECT MRR__c FROM Opportunity];

        // Verify
        System.assertEquals(300, oppDb2.MRR__c);
    }

    @isTest
    static void given_OneTimeSubscription_When_OneYearTerm_Then_TCVEqualsOneTimeFeeAndARRIsZero() {
        //Arrange
        arrange('One-Time', 15.00, 10, '12');

        // Act
        Opportunity oppDb2 = [SELECT MRR__c FROM Opportunity];

        // Verify
        System.assertEquals(0, oppDb2.MRR__c);
    }

    @isTest
    static void given_OneTimeSubscription_When_TwoYearTerm_Then_TCVAndARRNotChanged() {
        //Arrange
        arrange('One-Time', 15.00, 10, '24');

        // Act
        Opportunity oppDb2 = [SELECT MRR__c FROM Opportunity];

        // Verify
        System.assertEquals(0, oppDb2.MRR__c);
    }

    @isTest
    static void given_MonthlySubscription_When_OneMonthTerm_Then_TCVAndARRCalculated() {
        //Arrange
        arrange('Recurring', 12.99, 447, '1');

        // Act
        Opportunity oppDb2 = [SELECT MRR__c FROM Opportunity];

        // Verify
        System.assertEquals(5806.53, oppDb2.MRR__c);
    }

    public static void arrange(String chargeType, Decimal unitPrice, Integer quantity, String term) {
        // Calculate quote by default
        arrange(chargeType, unitPrice, quantity, term, true);
    }

    public static void arrange(String chargeType, 
        Decimal unitPrice, 
        Integer quantity, 
        String term, 
        Boolean calculateQuote) {

        TestData.QuoteWithLineItems testData = TestData.createQuoteWithLineItems(chargeType, unitPrice, quantity, term);
        SBQQ__Quote__c quote = [SELECT Id, SBQQ__Opportunity2__c, SBQQ__Primary__c FROM SBQQ__Quote__c 
                                WHERE Id =: testData.quoteId];
        
        // Calculate quote
        String quoteJSON = SBQQ.ServiceRouter.read('SBQQ.QuoteAPI.QuoteReader', testData.quoteId);
        Map<String, Object> q = (Map<String, Object>) JSON.deserializeUntyped(quoteJSON);
        QuoteCalculator calculator = new QuoteCalculator();
        if(calculateQuote) {
            calculator.calculate(q, 'CalculatorCallback');
        }

        quote.SBQQ__Opportunity2__c = testData.opportunityId;
        quote.SBQQ__Primary__c = True;
        update quote;
    }

}