public with sharing class SetupRenewalOpportunity {
    private static String RENEWAL_TYPE = 'Renewal';
    private static String NOT_RENEWAL_TYPE_ERROR_MESSAGE = 'Non Renewal Opportunities exist in the input Id';

    public class SeatPriceRaise{ // Pricing information with raise since the previous subscription
        public Decimal seatPrice;
        public Decimal annualRaise;
    }

    // Set of criteria which can be applied to find a product
    private class SearchCriteria{
        public String productFamily = null;
        public String product = null;
        public String successLevel = null;
        public String productEdition = null;
        public String productEditionLabel = null;
        public Decimal maxSeats = -1;
    }

    @InvocableMethod
    public static void setRenewalProductAndPricing(List<Id> opIds) {
        RenewalOpportunitiesProcessor processor = new RenewalOpportunitiesProcessor();
        processor.processOpportunities(opIds);
    }

    public with sharing class RenewalOpportunitiesProcessor{
        List<Opportunity> oppsList; // All oportunities being processed
        List<SBQQ__QuoteLine__c> linesList = new List<SBQQ__QuoteLine__c>(); // QuoteLine items inserted
        List<SBQQ__Quote__c> quotesList = new List<SBQQ__Quote__c>(); // All quotes inserted
        List<Contact> newContactsList = new List<Contact>(); // Contacts inserted
        List<Contact> contactsToUpdateList = new List<Contact>(); // Contacts updated
        List<OpportunityContactRole> ocrsList = new List<OpportunityContactRole>(); // Opportunity-to-Contact items created
        Map<String, Contact> contactsMap; // Get contacts for the opportunities
        Set<String> emailsDuplicated = new Set<String>();
        
        ID stdPriceBookId = QuoteUtils.getStandardPriceBook();
        // All active products
        List<Product2> allProducts = [
                SELECT Id, Name, Family, Product_Edition__c, Product__c, Product_Edition_Label__c, IsActive,
                    Min_Quantity__c, Max_Quantity__c, Success_Level__c
                FROM Product2
                WHERE IsActive = true
        ];

        Map<Id, PricebookEntry> pricebookMap = getPricebookMap(); // All active pricebook entries

        public void processOpportunities(List<Id> opIds)
        {
            oppsList = [SELECT Id, Name, Type, ContactId, Renewal_Date__c, 
                        Product__c, Current_Product__c, Current_Product_Edition__c,
                        Current_Product_Edition_Label__c, Current_Success_Level__c, 
                        Current_Billing_Term__c, Current_Term__c, Current_Seats__c, 
                        Current_ARR__c, Current_Primary_Contact_Email__c, Current_Addons__c, 
                        Current_Addons_ARR__c, AccountId, OwnerId, 
                        Description, StageName, CurrencyIsoCode
                        FROM Opportunity
                        WHERE Id IN :opIds
                        AND opportunity.Current_Product__c != null
                        AND opportunity.Current_Product_Edition__c != null
                        AND opportunity.Current_Product_Edition_Label__c != null
                        AND opportunity.Current_Success_Level__c != null  
                        AND opportunity.Current_Billing_Term__c != null
                        AND opportunity.Current_Term__c != null
                        AND opportunity.Current_Seats__c != null
                        AND opportunity.Current_ARR__c != null
                        AND opportunity.Current_Primary_Contact_Email__c != null
                        AND opportunity.Current_Addons__c != null
                        AND opportunity.Current_Addons_ARR__c != null
                        AND opportunity.type = :RENEWAL_TYPE
                       ];
            contactsMap = getContactsMap(oppsList);

            for (Opportunity opportunity : oppsList) {
                opportunity.SBQQ__QuotePricebookId__c = stdPriceBookId; // this is important for autosync Quote and Opportunity

                Product2 productDb = getMainProduct(opportunity);
                if (productDb == null){
                    System.debug('Product not found during Setup Renewal Opportunity (CPQ)');
                    ErrorReporting.notifyViaEmail('Opportunity Setup: Product not found',
                        ' Opportunity Name: ' + opportunity.Name);
                    continue;
                }

                Contact primaryContact = setPrimaryContact(opportunity); // Set primary contact

                //Not creating quote for EVERGREEN opportunities
                if (opportunity.Current_Term__c == 0){
                    continue;
                }
                
                SBQQ__Quote__c quote = insertQuote(opportunity);
                quotesList.add(quote);

                PriceBookEntry priceBookMain = null;
                if(pricebookMap.containsKey(productDb.Id)) priceBookMain = pricebookMap.get(productDb.Id);

                if (priceBookMain == null) {
                    System.debug('priceBookList is empty');
                    ErrorReporting.notifyViaEmail('Opportunity Setup: PricebookList is empty',
                        ' Opportunity Name: ' + opportunity.Name + ', Product: ' + productDb.Name);
                    return;
                }

                SeatPriceRaise priceInfo = getSeatPrice(opportunity,priceBookMain, productDb);
                Decimal seats = Math.max(opportunity.Current_Seats__c, productDb.Min_Quantity__c);

                Decimal subscriptionTerm = getSubscriptionTerm(opportunity);
                SBQQ__QuoteLine__c quoteLine = new SBQQ__QuoteLine__c(
                    SBQQ__Product__c = productDb.Id,
                    SBQQ__Quantity__c = seats,
                    SBQQ__Quote__r = quote,
                    SBQQ__PricebookEntryId__c = priceBookMain.Id,
                    SBQQ__SubscriptionTerm__c = subscriptionTerm,
                    SBQQ__PriceEditable__c = true,
                    SBQQ__Number__c = 1,
                    SBQQ__SpecialPrice__c = priceInfo.seatPrice,
                    SBQQ__SpecialPriceType__c = 'Custom'
                );

                System.debug('First quote line: ' + quoteLine);
                System.debug('List price: ' + priceInfo.seatPrice);
                System.debug('Subscription term: ' + subscriptionTerm);
                System.debug('Unit price: ' + priceBookMain.UnitPrice);

                linesList.add(quoteLine);

                if (opportunity.Current_Addons__c > 0) {
                    createAddonLine(opportunity, quote, priceInfo);
                }
                if(primaryContact != null){
                    quote.SBQQ__PrimaryContact__c = primaryContact.Id;
                }
            }
            // Make bulk insert/updates to objects
            insert newContactsList;
            update contactsToUpdateList;
            for (OpportunityContactRole c : ocrsList) {
                if(c.ContactId == null) {
                    c.ContactId = c.Contact.Id;
                }
            }
            insert ocrsList; // Insert contact roles
            update oppsList;
            insert quotesList;
            // Fill quote ids now
            for (SBQQ__QuoteLine__c line : linesList){ // Some strange problem with saving using the relationship
                line.SBQQ__Quote__c = line.SBQQ__Quote__r.Id;
                line.SBQQ__Quote__r = null;
            }
            insert linesList;

            for (SBQQ__Quote__c quote : quotesList){
                QuoteUtils.calculateQuote(quote); // Update pricing
                // Create an opportunity now.
                quote.SBQQ__Primary__c = true;
            }
            update quotesList;
        }

        void createAddonLine(Opportunity opportunity, SBQQ__Quote__c quote, SeatPriceRaise priceInfo){
            SearchCriteria productCriteria = new SearchCriteria();
            productCriteria.productFamily = opportunity.Product__c;
            productCriteria.product = 'Collaborators';
            Product2 addonProductDb = searchProduct(productCriteria);
            PricebookEntry priceBookCollaborators = pricebookMap.get(addonProductDb.Id);
            Decimal addonUnitPrice = (opportunity.Current_Addons_ARR__C * priceInfo.annualRaise / opportunity.Current_Addons__c) / 12;
            addonUnitPrice = addonUnitPrice.setScale(2); // 2 decimal places only

            System.debug(String.format('addonUnitPrice: {0}, Current_Addons_ARR__C: {1}, annualRaise: {2}, Current_Addons__c: {3}',
            new String[]{String.valueOf(addonUnitPrice), String.valueOf(opportunity.Current_Addons_ARR__C), String.valueOf(priceInfo.annualRaise), String.valueOf(opportunity.Current_Addons__c)}));
            Decimal subscriptionTerm = getSubscriptionTerm(opportunity);
            SBQQ__QuoteLine__c quoteLine2 = new SBQQ__QuoteLine__c(
                SBQQ__Product__c = addonProductDb.Id,
                SBQQ__Quantity__c = opportunity.Current_Addons__c,
                SBQQ__Quote__r = quote,
                SBQQ__PricebookEntryId__c = priceBookCollaborators.Id,
                SBQQ__SubscriptionTerm__c = subscriptionTerm,
                SBQQ__PriceEditable__c = true,
                SBQQ__SpecialPrice__c = addonUnitPrice,
                SBQQ__SpecialPriceType__c = 'Custom',
                SBQQ__Number__c = 2
            );

            System.debug('Second line ' + quoteLine2);
            linesList.add(quoteLine2);
        }

        Contact setPrimaryContact(Opportunity opportunity){
            Contact primaryContact = null;
            String emailAddress = opportunity.Current_Primary_Contact_Email__c;
            if(emailAddress!=null) { emailAddress = emailAddress.toLowerCase(); }

            if (emailsDuplicated.contains(emailAddress)) {
                opportunity.Description = String.format('{0}{1} System: {2}({3}) {4}. {5}.', new String[] {
                    String.isBlank(opportunity.Description) ? '' : opportunity.Description + '\n',
                    DateTime.now().formatGmt('MM/dd/yy'),
                    'We encountered duplicate contacts with the same email address',
                    emailAddress,
                    'and therefore could not automatically set the Primary Contact',
                    'Please set the Primary Contact and resolve any duplicates'
                });
                return null;
            }

            if(contactsMap.containsKey(emailAddress)){
                primaryContact = contactsMap.get(emailAddress);
            }
            System.debug('Primary contact: ' + primaryContact);
            if (primaryContact == null) {
                System.debug('Primary contact not found...');
                Contact contact = new Contact(LastName = opportunity.Current_Primary_Contact_Email__c,
                    Email = opportunity.Current_Primary_Contact_Email__c,
                    Current_Product_Family__c = opportunity.Product__c,
                    Current_Renewal_Date__c = opportunity.Renewal_Date__c,
                    AccountId = opportunity.AccountId,
                    OwnerId = opportunity.OwnerId
                );
                contactsMap.put(emailAddress, contact); // Save this email for future opportunities
                newContactsList.add(contact);
                primaryContact = contact;

                ErrorReporting.notifyViaEmail('Opportunity Setup: Primary Contact was created',
                    String.format('Email: {0} Opportunity Name: {1}', new List<String> {opportunity.Current_Primary_Contact_Email__c, opportunity.Name}));
            } else {
                if (!contactsToUpdateList.contains(primaryContact)) {
                    primaryContact.Current_Product_Family__c = opportunity.Product__c;
                    primaryContact.Current_Renewal_Date__c = opportunity.Renewal_Date__c;
                    primaryContact.OwnerId = opportunity.OwnerId;
                    contactsToUpdateList.add(primaryContact);
                }

                String dateStr = Date.today().format();
                if (primaryContact.HasOptedOutOfEmail) {
                    opportunity.Description = String.format(
                        '{0}: The Primary Contact ({1}) has Opted Out of email communication. Use alternate means to engage or identify an alternate contact.',
                        new List<String> {dateStr, opportunity.Current_Primary_Contact_Email__c});
                }
            }
            OpportunityContactRole ocr = new OpportunityContactRole(Contact = primaryContact, ContactId = primaryContact.Id, IsPrimary = true, OpportunityId = opportunity.Id, Role='Decision Maker');
            if(primaryContact != null) {
                ocrsList.add(ocr);
            }

            return primaryContact;
        }



        SeatPriceRaise getSeatPrice(Opportunity opportunity, PricebookEntry pricebookEntry, Product2 productDb){
            SeatPriceRaise priceInfo = new SeatPriceRaise();
            priceInfo.annualRaise = 1.00;
            Decimal seatsARR = opportunity.Current_ARR__c - opportunity.Current_Addons_ARR__c;
            Decimal seatPrice = (seatsARR / opportunity.Current_Seats__c)/12;
            priceInfo.seatPrice = seatPrice;
            System.debug(String.format('seatsArr: {0}, quantity: {1}, seatPrice: {2}',
            new String[]{String.valueof(seatsARR),  String.valueof(opportunity.Current_Seats__c), String.valueof(seatPrice)}));
            if(opportunity.Current_Product__c != 'OnDemand') {
                if (seatPrice < pricebookEntry.UnitPrice) {
                    switch on opportunity.Current_Success_Level__c {
                        when 'Standard' {
                            priceInfo.annualRaise = 1.25;
                        }
                        when 'Gold' {
                            priceInfo.annualRaise = 1.35;
                        }
                        when 'Platinum' {
                            priceInfo.annualRaise = 1.45;
                        }
                        when else {
                            priceInfo.annualRaise = 1.25;
                        }
                    }

                    priceInfo.seatPrice = priceInfo.seatPrice * priceInfo.annualRaise;
                    priceInfo.seatPrice = priceInfo.seatPrice.setScale(2); // 2 decimal places only
                    if (priceInfo.seatPrice > pricebookEntry.UnitPrice) {
                        priceInfo.annualRaise = pricebookEntry.UnitPrice/priceInfo.seatPrice;
                        priceInfo.seatPrice = pricebookEntry.UnitPrice;
                    }
                }
                System.debug('Annual rise: ' + String.valueof(priceInfo.annualRaise));
                System.debug('Unit price: ' +  String.valueof(pricebookEntry.UnitPrice));
            }
            System.debug('priceInfo: ' + priceInfo);
            return priceInfo;
        }

        // Get editions higher then the given. The order is None->Standard->Professional->Enterprise
        List<String> getEditionList(String productEdition) {
            List<String> productEditionsList = new List<String>();
            if(productEdition == null) productEdition = 'None';
            if (productEdition.equals('Standard')) {
                productEditionsList.add('Enterprise');
                productEditionsList.add('Professional');
            } else if (productEdition.equals('Professional')) {
                productEditionsList.add('Enterprise');
            } else {
                productEditionsList.add('Standard');
                productEditionsList.add('Enterprise');
                productEditionsList.add('Professional');
            }
            return productEditionsList;
        }


        public Decimal getSubscriptionTerm(Opportunity opportunity){
            Decimal subscriptionTerm = 12;
            if (opportunity.Current_Billing_Term__c == 'Monthly' || opportunity.Current_Billing_Term__c == 'Yearly') {
                subscriptionTerm = opportunity.Current_Term__c;
            }
            if(opportunity.Current_Product__c == 'OnDemand') { // Convert OnDemand to 1 month
                subscriptionTerm = 1;
                System.debug('OnDemand subscription should be one month only');
            }
            return subscriptionTerm;
        }

        public SBQQ__Quote__c insertQuote(Opportunity opportunity){
            Date startDate = opportunity.Renewal_Date__c;
            Decimal subscriptionTerm = getSubscriptionTerm(opportunity);
            Date endDate = startDate.addMonths((Integer)subscriptionTerm)-1;
            String billingFrequency = opportunity.Current_Billing_Term__c == 'Yearly'?'Annual':'Monthly';
            if(opportunity.Current_Product__c == 'OnDemand') { // Convert OnDemand to Monthly
                billingFrequency = 'Monthly';
                endDate = null;
            }

            SBQQ__Quote__c quote = QuoteUtils.createQuote(opportunity, RENEWAL_TYPE, billingFrequency);
            quote.SBQQ__EndDate__c = endDate;

            return quote;
        }

        public Map<String, Contact> getContactsMap(List<Opportunity> opps){
            Set<String> emails = new Set<String>();
            Map<String, Contact> result = new Map<String, Contact>();
            for(Opportunity opp : opps){
                if(opp.Current_Primary_Contact_Email__c != null) {
                    emails.add(opp.Current_Primary_Contact_Email__c.toLowerCase());
                }
            }
            List<Contact> contacts = [
                SELECT Id, HasOptedOutOfEmail, Email
                FROM Contact
                WHERE Email IN :emails
            ];

            for(Contact c : contacts){
                String emailAddress = c.Email.toLowerCase();
                if(result.containsKey(emailAddress)){
                    System.debug('[Warning] Primary contact ambiguity. Several contacts have the same email: ' + emailAddress);
                    ErrorReporting.notifyViaEmail('Opportunity Setup: Primary contact ambiguity',
                        'Several contacts have the same email: ' + emailAddress);
                    emailsDuplicated.add(emailAddress);
                } else {
                    result.put(emailAddress,c);
                }
            }

            return result;
        }

        public Product2 searchProduct(SearchCriteria criteria){ // Return the first product matching the criteria
            for(Product2 prod : allProducts){
                if(criteria.productFamily != null && criteria.productFamily != prod.Family){ continue; }
                if(criteria.product != null && criteria.product != prod.Product__c){ continue; }
                if(criteria.successLevel != null && criteria.successLevel != prod.Success_Level__c){ continue; }
                if(criteria.productEdition != null && criteria.productEdition != prod.Product_Edition__c){ continue; }
                if(criteria.productEditionLabel != null && criteria.productEditionLabel != prod.Product_Edition_Label__c){ continue; }
                if(criteria.maxSeats != -1 && prod.Max_Quantity__c != null && criteria.maxSeats > prod.Max_Quantity__c){ continue; }
                return prod; // All conditions are met
            }
            return null;
        }

        public Product2 getMainProduct(Opportunity opportunity){
            String productFamily = opportunity.Product__c;
            String product = opportunity.Current_Product__c;
            String successLevel = opportunity.Current_Success_Level__c;
            String productEditionLabel = opportunity.Current_Product_Edition_Label__c == 'Inbox'
                                            ? 'Growth'
                                            : opportunity.Current_Product_Edition_Label__c;

            // Get the appropriate product for this Opportunity
            SearchCriteria productCriteria = new SearchCriteria();
            productCriteria.productFamily = opportunity.Product__c;
            productCriteria.product = opportunity.Current_Product__c;
            productCriteria.successLevel = opportunity.Current_Success_Level__c;
            productCriteria.productEdition = opportunity.Current_Product_Edition__c;
            productCriteria.productEditionLabel = productEditionLabel;
            productCriteria.maxSeats = opportunity.Current_Seats__c;
            Product2 productDb = searchProduct(productCriteria);
            System.debug('Search criteria: ' + productCriteria);
            System.debug('Product found: ' + productDb);

            if (productDb == null) { // We haven't found the exact product. Let's try to search for a product of higher editions
                String productEdition = opportunity.Current_Product_Edition__c;
                List<String> productEditionsList = getEditionList(productEdition); // Get higher production editions
                productCriteria.productEditionLabel = null; // we do not use this anymore
                for (String edition : productEditionsList) {
                    productCriteria.productEdition = edition;
                    productDb = searchProduct(productCriteria);
                    System.debug('Search criteria (additional): ' + productCriteria);
                    System.debug('Product found  (additional): ' + productDb);
                    if (productDb != null) {
                        break;
                    }
                }
            }
            return productDb;
        }

        // Creates mapping between ProductId and PricebookEntry
        public Map<Id, PricebookEntry> getPricebookMap(){
            List<PriceBookEntry> priceBookList = [
                SELECT Id, UnitPrice, Product2Id, Product2.Id, Product2.Name
                FROM PriceBookEntry
                WHERE PriceBook2.isStandard = true
                AND IsActive = true];
            Map<Id, PricebookEntry> result = new Map<Id, PricebookEntry>();
            for(PricebookEntry entry : priceBookList){
                result.put(entry.Product2Id, entry);
            }
            return result;
        }
    }
}