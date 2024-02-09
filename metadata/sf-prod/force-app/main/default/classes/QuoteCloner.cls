public with sharing class QuoteCloner {

    public class FlowInput {
        @InvocableVariable(label='Quote ID' required=true)
        public Id quoteId;
    }
    
    public class FlowOutput {
        @InvocableVariable(label='Cloned Quote ID')
        public Id clonedQuoteId;
    }

    @InvocableMethod(label='Clone CPQ Quote with Line Items' 
        description='Clones a CPQ Quote along with its line items, including bundled line items')
    public static List<FlowOutput> cloneQuote(List<FlowInput> inputs) {
        List<FlowOutput> outputs = new List<FlowOutput>();
        for (FlowInput input : inputs) {
            FlowOutput output = new FlowOutput();
            output.clonedQuoteId = cloneQuoteWithLineItems(input.quoteId).Id;
            outputs.add(output);
        }
        return outputs;
    }

    private static String getQueryWithAllFields(String objectName, String whereClause) {
        Map<String, Schema.SObjectField> fieldMap = 
            Schema.getGlobalDescribe().get(objectName).getDescribe().fields.getMap();
        List<String> accessibleFields = new List<String>();
        for (String fieldName : fieldMap.keySet()) {
            Schema.DescribeFieldResult field = fieldMap.get(fieldName).getDescribe();
            if (field.isAccessible()) {
                accessibleFields.add(fieldName);
            }
        }
        return 'SELECT ' + String.join(accessibleFields, ',') + ' FROM ' + objectName + ' WHERE ' + whereClause;
    }

    public static SBQQ__Quote__c cloneQuoteWithLineItems(Id quoteId) {
        // Step 1: Retrieve the original Quote
        SBQQ__Quote__c originalQuote = Database.query(getQueryWithAllFields('SBQQ__Quote__c', 'Id = \'' +
            quoteId + '\' LIMIT 1'));
        // Clean expiration date as will be set in Quote_SetExpiryDate flow which has a formula to set the expiration
        originalQuote.SBQQ__ExpirationDate__c = null;

        // Step 2: Clone the Quote
        SBQQ__Quote__c clonedQuote = originalQuote.clone(false, true);
        insert clonedQuote;

        // Step 3: Retrieve all original Quote Line Items
        List<SBQQ__QuoteLine__c> originalLineItems = Database.query(
            getQueryWithAllFields('SBQQ__QuoteLine__c', 'SBQQ__Quote__c = \'' + quoteId + '\''));
        
        // Step 4: Organize the line items by their parent bundle
        Map<Id, List<SBQQ__QuoteLine__c>> lineItemsByParent = new Map<Id, List<SBQQ__QuoteLine__c>>();
        for (SBQQ__QuoteLine__c lineItem : originalLineItems) {
            if (!lineItemsByParent.containsKey(lineItem.SBQQ__RequiredBy__c)) {
                lineItemsByParent.put(lineItem.SBQQ__RequiredBy__c, new List<SBQQ__QuoteLine__c>());
            }
            lineItemsByParent.get(lineItem.SBQQ__RequiredBy__c).add(lineItem);
        }

        // Step 5: Clone the Quote Line Items with recursion
        Map<Id, Id> idMap = new Map<Id, Id>(); // to keep track of old and new Ids
        cloneLineItems(lineItemsByParent, null, clonedQuote.Id, null, idMap);

        return clonedQuote;
    }

    private static void cloneLineItems(Map<Id, List<SBQQ__QuoteLine__c>> lineItemsByParent, Id parentId,
        Id newQuoteId, Id newParentId, Map<Id, Id> idMap) {
        if (!lineItemsByParent.containsKey(parentId)) {
            return;
        }

        for (SBQQ__QuoteLine__c lineItem : lineItemsByParent.get(parentId)) {
            SBQQ__QuoteLine__c clonedLineItem = lineItem.clone(false, true);
            clonedLineItem.SBQQ__Quote__c = newQuoteId;
            clonedLineItem.SBQQ__RequiredBy__c = newParentId;
            insert clonedLineItem; // You might want to bulkify this insert operation
            idMap.put(lineItem.Id, clonedLineItem.Id);

            // Recursive call for nested bundles
            if (lineItem.SBQQ__Bundle__c == true) {
                cloneLineItems(lineItemsByParent, lineItem.Id, newQuoteId, clonedLineItem.Id, idMap);
            }
        }
    }
}