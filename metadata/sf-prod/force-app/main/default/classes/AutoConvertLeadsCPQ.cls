public with sharing class AutoConvertLeadsCPQ {

    public static final Integer DEFAULT_QUANTITY = 2;

    //private static QuoteTemplateService quoteTemplateService = new QuoteTemplateService();

    @InvocableMethod
    public static void leadAssign(List<Id> leadIds) {
        List<Lead> leads = [
                SELECT Id, Status, Team_Size__c, Product__c, Product_Edition__c, OwnerId,
                    IsConverted, ConvertedAccountId, ConvertedContactId, ConvertedOpportunityId
                FROM Lead
                WHERE ID=:leadIds[0]
        ];

        // Get the appropriate product for this Lead
        if (leads.size() == 0) {
            return;
        }

        Lead lead = leads[0];

        List<Product2> products = new List<Product2>();
        if (String.isNotBlank(lead.Product_Edition__c)) {
            products = [
                    SELECT Id, Name, ProductCode, Family, SBQQ__DefaultQuantity__c, Min_Quantity__c, Max_Quantity__c, SBQQ__BillingFrequency__c
                    FROM Product2
                    WHERE Family = :lead.Product__c
                        AND Product_Edition_Label__c = :lead.Product_Edition__c
                        AND Success_Level__c = 'Standard'
                        AND isActive = true
            ];
        } else {
            products = [
                    SELECT Id, Name, ProductCode, Family, SBQQ__DefaultQuantity__c, Min_Quantity__c, Max_Quantity__c, SBQQ__BillingFrequency__c
                    FROM Product2
                    WHERE Family = :lead.Product__c
                        AND isActive = true
                        AND Product_Edition__c <> 'Add-On'
                        AND Success_Level__c = 'Standard'
                    ORDER BY Product_Edition__c
            ];
        }

        // Convert the Lead to Account, Opportunity, Contact
        System.debug('Convert the Lead to Account, Opportunity, Contact');

        Id convertedAccountId;
        Id convertedContactId;
        Id convertedOpportunityId;
        if (lead.IsConverted) {
            convertedAccountId = lead.ConvertedAccountId;
            convertedContactId = lead.ConvertedContactId;
            convertedOpportunityId = lead.ConvertedOpportunityId;
        } else {
            Database.LeadConvert leadConvert = new Database.LeadConvert();
            leadConvert.setLeadId(lead.Id);

            leadConvert.setConvertedStatus(lead.Status);
            Database.LeadConvertResult leadConverts = Database.convertLead(leadConvert);

            convertedAccountId = leadConverts.getAccountId();
            convertedContactId = leadConverts.getContactId();
            convertedOpportunityId = leadConverts.getOpportunityId();
        }

        ID stdPriceBookId;
        if (Test.isRunningTest()) {
            stdPriceBookId = Test.getStandardPricebookId();
        } else {
            stdPriceBookId = [
                    SELECT Id, Name
                    FROM Pricebook2
                    where isStandard = True
                    limit 1
            ][0].Id;
        }

        String noProductFoundMessage = null;
        if (products.size() ==  0){
            noProductFoundMessage = String.format('{0}/{1} {2}{3};{4} Success Level: Standard)',
                new String[]{
                    String.valueOf(Date.today().Month()),
                    String.valueOf(Date.today().Year()),
                    'System: Quote is not created - no active product found for (Family: ',
                    lead.Product__c,
                    String.isBlank(lead.Product_Edition__c) ? '' : 
                        String.format(' Edition: {0};', new String[]{lead.Product_Edition__c})
                });

            String emailMessage = String.format('{0}. OpportunityId: {1}', 
                new String[]{noProductFoundMessage, convertedOpportunityId});
            ErrorReporting.notifyViaEmail('No quote created in lead conversion', emailMessage);
        }

        // Setup the newly created opportunity
        System.debug('Setup the newly created opportunity');
        ID opId = convertedOpportunityId;
        Opportunity opportunity = [
                SELECT  Id, Name, Type, StageName, Win_Type__c, Product__c,
                        SBQQ__PrimaryQuote__c, SBQQ__QuotePricebookId__c,
                        Trial_End_Date__c, CloseDate, Description
                FROM Opportunity
                WHERE Id = :opId
        ][0];  

        if (lead.Status == 'Engaged') {
            opportunity.StageName = 'Engaged';
        } else {
            // Self Purchase
            opportunity.StageName = 'Closed Won';
            opportunity.Win_Type__c = 'Self-Serve';
            opportunity.Purchase_Order__c = 'Not Required';
        }

        if (opportunity.Trial_End_Date__c == null || opportunity.Trial_End_Date__c < Date.today()) {
            opportunity.CloseDate = Date.today() + 14;
        } else {
            opportunity.CloseDate = opportunity.Trial_End_Date__c + 7;
        }
        
        // this is important for autosync Quote and Opportunity
        opportunity.SBQQ__QuotePricebookId__c = stdPriceBookId;
        
        if (noProductFoundMessage != null){
            opportunity.Description = String.isBlank(opportunity.Description) ? noProductFoundMessage : 
                opportunity.Description + '\n' + noProductFoundMessage;
        }

        update opportunity;

        if (products.size() >  0){
            SBQQ__Quote__c quote = new SBQQ__Quote__c(
                SBQQ__Type__c = 'Quote',
                SBQQ__PricebookId__c = stdPriceBookId,
                SBQQ__Account__c = convertedAccountId,
                SBQQ__PrimaryContact__c = convertedContactId,
                SBQQ__SalesRep__c = lead.OwnerId,
                //SBQQ__PaymentTerms__c = 'Due on receipt',
                SBQQ__Opportunity2__c = opId
            );
            createDefaultPrimaryQuote(products[0], quote, lead);
        }
    }

    // Create Quote with products
    private static void createDefaultPrimaryQuote(Product2 product, SBQQ__Quote__c quote, Lead lead){
        Integer subscriptionTerm = 12;
        String billingFrequency = 'Annual';
        if (product.SBQQ__BillingFrequency__c != null) {
            billingFrequency = product.SBQQ__BillingFrequency__c;
        }

        quote.SBQQ__BillingFrequency__c = billingFrequency;
        insert quote;

        Decimal quantity = product.SBQQ__DefaultQuantity__c;

        if (String.isNotBlank(lead.Team_Size__c)) {
            List<String> parts = lead.Team_Size__c.split('(\\s*-\\s*)|(\\s*\\+)');
            Integer teamSize = Integer.valueOf(parts[0]);
            if (teamSize < product.Min_Quantity__c) {
                quantity = product.Min_Quantity__c;
            } else {
                quantity = teamSize;
            }
        }

        Integer lineNumber = 1; // Current line number (is used for correct order of the lines)
        List<SBQQ__QuoteLine__c> quoteLineList = new List<SBQQ__QuoteLine__c>();

        // Create Quote line for Main Subscription
        ID priceBookEntryId = [
                SELECT Id
                From PricebookEntry
                WHERE Pricebook2Id = :quote.SBQQ__PricebookId__c
                AND Product2Id = :product.Id
        ][0].Id;


        SBQQ__QuoteLine__c quoteLine = new SBQQ__QuoteLine__c(
                SBQQ__Product__c = product.Id,
                SBQQ__Quantity__c = quantity,
                SBQQ__Quote__c = quote.Id,
                SBQQ__PricebookEntryId__c = priceBookEntryId,
                SBQQ__SubscriptionTerm__c = subscriptionTerm,
                SBQQ__BillingFrequency__c = billingFrequency,
                SBQQ__Number__c = lineNumber++
        );
        quoteLineList.add(quoteLine);

        insert quoteLineList;

        // Calculate quote
        String quoteJSON = SBQQ.ServiceRouter.read('SBQQ.QuoteAPI.QuoteReader', quote.Id);
        Map<String, Object> q = (Map<String, Object>) JSON.deserializeUntyped(quoteJSON);
        QuoteCalculator calculator = new QuoteCalculator();
        calculator.calculate(q, 'CalculatorCallback');

        // Set Quote to Primary to have it sync lines to the Opportunity Products
        quote.SBQQ__Primary__c = True;
        update quote;
    }
}