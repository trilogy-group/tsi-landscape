/*
- Used in the process of migrating opportunities from Central SF to TSI
to Create Quote for the migrated opportunities.
- Generated Quotes are not set as primary
https://docs.google.com/document/d/1f8lIeIrMDAiP2vMgl9h-L3NIRnhcnSLeXjoQmGBGBwM/edit#
*/
public class MigrationQuoteCreationBatch implements Database.Batchable<SObject>, Database.Stateful {
    public Id singleOpportunityId = null;
    public string product;
    private static String NOT_RENEWAL_TYPE_ERROR_MESSAGE = 'Non Renewal Opportunities exist in the input Id';
    private static String RENEWAL_TYPE = 'Renewal';
    private static String BILLING_FREQ = 'Annual';
    
    public MigrationQuoteCreationBatch(String productToProcess) { 
        product = productToProcess;
    } 
    public MigrationQuoteCreationBatch(Id singleOpportunityRun) { // Process one single opportunity
        singleOpportunityId = singleOpportunityRun;
    }

    public void execute(Database.BatchableContext batchableContext, List<Opportunity> opps) {
        List<SBQQ__Quote__c> quotes = new List<SBQQ__Quote__c>();
        List<SBQQ__QuoteLine__c> lines = new List<SBQQ__QuoteLine__c>();
        Id stdPriceBookId = QuoteUtils.getStandardPriceBook();
        System.debug('Processing oppportunitites: ' + opps.size());
        for (Opportunity o : opps) {
            System.debug('Processing opportunity: ' + o);
            o.SBQQ__QuotePricebookId__c = stdPriceBookId;
            SBQQ__Quote__c quote = QuoteUtils.createQuote(o, RENEWAL_TYPE, BILLING_FREQ);
            quotes.add(quote);
            Integer lineNumber = 1;            
            for (OpportunityLineItem lineItem : o.OpportunityLineItems) {                
                Product2 newProduct = lineItem.Product2;
                System.debug('----');
                System.debug('lineItem: ' + lineItem);
                System.debug('lineItem.Subscription_Term__c: ' + lineItem.Subscription_Term__c);
                System.debug('lineItem.Product2: ' + lineItem.Product2);
                System.debug('lineItem.Product2.SBQQ__SubscriptionTerm__c: ' + lineItem.Product2.SBQQ__SubscriptionTerm__c);
                Decimal termsCoef = 1;
                if(lineItem.Subscription_Term__c != 0 && lineItem.Subscription_Term__c != null
                && lineItem.Product2.SBQQ__SubscriptionTerm__c != null && lineItem.Product2.SBQQ__SubscriptionTerm__c != 0) {
                    termsCoef = lineItem.Subscription_Term__c/lineItem.Product2.SBQQ__SubscriptionTerm__c;
                }
                Decimal seatPrice = lineItem.UnitPrice / termsCoef;
                SBQQ__QuoteLine__c quoteLine = new SBQQ__QuoteLine__c(
                    SBQQ__Quantity__c = lineItem.Quantity,
                    SBQQ__Quote__r = quote,
                    SBQQ__Product__c = newProduct.Id,
                    SBQQ__Number__c = lineNumber++,
                    SBQQ__SubscriptionTerm__c = lineItem.Subscription_Term__c,
                    SBQQ__Description__c = '',
                    SBQQ__PriceEditable__c = true, 
                    SBQQ__SpecialPrice__c = seatPrice,
                    SBQQ__SpecialPriceType__c = 'Custom'
                );
                lines.add(quoteLine);

            }
        }
        update opps;

        insert quotes;
        System.debug('Quotes inserted: ' + quotes.size());
        List<SBQQ__QuoteLine__c> extraLines = [SELECT Id FROM SBQQ__QuoteLine__c WHERE SBQQ__Quote__c IN :quotes];
        System.debug('Delete the automatically created lines ' + extraLines.size());        
        delete extraLines; // Remove the autocreated lines. We will insert our filled lines.

        for (SBQQ__QuoteLine__c line : lines) { // Some strange problem with saving using the relationship
            line.SBQQ__Quote__c = line.SBQQ__Quote__r.Id;
            line.SBQQ__Quote__r = null;
        }
        insert lines;
        System.debug('Lines inserted: ' + lines.size());

        for (SBQQ__Quote__c quote : quotes) {
            QuoteUtils.calculateQuote(quote);
        }
    }

    public void finish(Database.BatchableContext param1) {
    }

    public Iterable<SObject> start(Database.BatchableContext bc) {
        List<SObject> result = null;
        if(this.singleOpportunityId!=null) {
            result = [
            SELECT Id, AccountId, ContactId, OwnerId, Name, Renewal_Date__c, CurrencyIsoCode,
            (
                SELECT Id, OpportunityId, Product2.Name, Quantity, TotalPrice,
                    Subscription_Term__c, Product2.SBQQ__SubscriptionTerm__c,
                    PricebookEntry.UnitPrice, UnitPrice
                FROM OpportunityLineItems
                ORDER BY Opportunity.Name
            )
            FROM Opportunity
            WHERE Id=:this.singleOpportunityId AND 
                  type = :RENEWAL_TYPE];
            
        } else {
            result = [
            SELECT Id, AccountId, ContactId, OwnerId, Name, Renewal_Date__c, CurrencyIsoCode,
            (
                SELECT Id, OpportunityId, Product2.Name, Quantity, TotalPrice,
                    Subscription_Term__c, Product2.SBQQ__SubscriptionTerm__c,
                    PricebookEntry.UnitPrice, UnitPrice
                FROM OpportunityLineItems
            )
            FROM Opportunity
            WHERE Product__c=:this.product
            AND SBQQ__PrimaryQuote__c = null AND 
            type = :RENEWAL_TYPE];
        }
        System.debug('Starting processing opportunities: ' + result.size());
        return result;
    }

}