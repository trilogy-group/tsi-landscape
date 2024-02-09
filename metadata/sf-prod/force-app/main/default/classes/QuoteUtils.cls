public with sharing class QuoteUtils {
    private static final String READER = 'SBQQ.QuoteAPI.QuoteReader';
    private static final String CALCULATOR_CALL_BACK = 'CalculatorCallback';
    
    public static SBQQ__Quote__c createQuote(Opportunity opp, String quoteType, String billingFrequency) {
        SBQQ__Quote__c quote = new SBQQ__Quote__c (
                SBQQ__Type__c = quoteType,
                SBQQ__Opportunity2__c = opp.id,
                SBQQ__PricebookId__c = opp.SBQQ__QuotePricebookId__c,
                SBQQ__Account__c = opp.AccountId,
                SBQQ__PrimaryContact__c = opp.ContactId,                
                SBQQ__BillingFrequency__c = billingFrequency,
                SBQQ__StartDate__c = opp.Renewal_Date__c,
                CurrencyIsoCode = opp.CurrencyIsoCode, //Setting Quote currency to match opportunity currency
                SBQQ__SalesRep__c = opp.OwnerId
                
            );

        return quote;
    }

    public static Id getStandardPriceBook(){
        Id stdPriceBookId;
        if (Test.isRunningTest()) {
            stdPriceBookId = Test.getStandardPricebookId();
        } else {
            stdPriceBookId = [
                SELECT Id, Name
                FROM Pricebook2
                WHERE isStandard = True
                LIMIT 1
            ][0].Id;
        }
        return stdPricebookId;
    }

    public static void calculateQuote(SBQQ__Quote__c quote){
        // Calculate quote
        String quoteJSON = SBQQ.ServiceRouter.read(READER, quote.Id);
        Map<String, Object> q = (Map<String, Object>) JSON.deserializeUntyped(quoteJSON);
        QuoteCalculator calculator = new QuoteCalculator();
        calculator.calculate(q, CALCULATOR_CALL_BACK);
    }
}