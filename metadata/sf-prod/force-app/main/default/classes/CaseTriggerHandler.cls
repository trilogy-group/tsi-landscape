/**
 * Author: Paras Dhingra
 * Creation Date: 2023-10-04
 * Description: This class contains the logic for processing Salesforce Case records. It includes methods for extracting key values from Case descriptions,
 * dynamically querying related Contacts and Opportunities based on those key values, and updating Case records with related Contact and Opportunity information.
 * The class also handles the extraction and cleaning of JSON strings from Case descriptions and dynamically constructs SOQL queries based on extracted data.
 */
public With Sharing class CaseTriggerHandler {
    /**
     * Processes a list of Case records by extracting key values, querying related Contacts and Opportunities, and updating Cases accordingly.
     * @param cases The list of Case records to process.
     */
    public static List<String> lstAdmins;
    public static final string ADDITIONALFIELDS = 'AccountId';
    public static final string SELFSERVEPG = SYSTEM.LABEL.SelfServePG;
    public static void processCases(List<Case> cases) {
        // Retrieve the RecordTypeId for 'Self_Serve_Queries' using the GeneralUtility class
        String selfServeQueriesRecordTypeId = GeneralUtility.getRecordTypeIdByName('Case', 'Self_Serve_Queries');

        Set<String> emails = new Set<String>();
        Set<String> subscriptionIds = new Set<String>();
        // Filter cases by RecordTypeId before processing
        for (Case caseRecord : cases) {
            if (caseRecord.RecordTypeId == selfServeQueriesRecordTypeId) {
                emails.addAll(extractKeyValues(new List<Case>{caseRecord},'email'));
                subscriptionIds.addAll(extractKeyValues(new List<Case>{caseRecord},'subscriptionId'));
            }
        }

        Map<String, Object> emailToContactMap = getDynamicMap(cases,'Contact','email',emails);
        Map<String, Object> subscriptionIdToOpportunityMap = getDynamicMap(cases,'Opportunity','netsuite_Id__c',subscriptionIds);

        for (Case caseRecord : cases) {
            if (caseRecord.RecordTypeId == selfServeQueriesRecordTypeId) {
                processCaseRecord(caseRecord, emailToContactMap, subscriptionIdToOpportunityMap);
            }
        }
        System.debug('==exiting process cases==');
    }
    /**
     * Processes a single Case record by updating it with related Contact and Opportunity information based on extracted data from the Case description.
     * @param caseRecord The Case record to process.
     * @param emailToContactMap A map of email addresses to Contact records.
     * @param subscriptionIdToOpportunityMap A map of subscription IDs to Opportunity records.
     */
    private static void processCaseRecord(Case caseRecord, Map<String, Object> emailToContactMap, Map<String, Object> subscriptionIdToOpportunityMap) {
        String jsonString = extractJsonString(caseRecord.Description);
        try {
            if (jsonString != null) {
                Map<String, Object> jsonMap = (Map<String, Object>) JSON.deserializeUntyped(jsonString);
                String email = (String)jsonMap.get('email');
                String subscriptionId = String.valueOf(jsonMap.get('subscriptionId'));
                caseRecord.SuppliedEmail =email;
                Contact contact = (Contact)emailToContactMap.get(email);
                Opportunity opportunity =(Opportunity)subscriptionIdToOpportunityMap.get(subscriptionId);

                if (contact != null) {  
                    caseRecord.ContactId = contact.Id;
                }
                if (opportunity != null) {
                    caseRecord.Self_Serve_Opportunity__c = opportunity.Id; // Assuming you have a lookup from Case to Opportunity
                    caseRecord.AccountId = opportunity.AccountId;
                }
                List<String> missingItems = new List<String>();
                if (!emailToContactMap.containsKey(email)) {
                    missingItems.add('contact');
                }
                if (!subscriptionIdToOpportunityMap.containsKey(subscriptionId)) {
                    missingItems.add('opportunity');
                }
                if (!missingItems.isEmpty()) {
                    String systemMessage = 'SYSTEM ' + Date.today().format() + ': ' + String.join(missingItems, ', ') + ' not found';
                    caseRecord.Description = + systemMessage + '\n\n'+caseRecord.Description;
                }
            } 
        } catch(Exception ex) {
            String message = 'Case Handler failed while processing case JSON:'+jsonString +' Error Message='+ex.getMessage();
            postErrorToPG(message);
        }

    }

    /**
     * Dynamically constructs and executes a SOQL query to retrieve SObject records based on specified criteria.
     * @param cases The list of Case records to process.
     * @param objectName The name of the SObject to query.
     * @param idFieldName The field name to use in the query's WHERE clause.
     * @param idValues The set of values to include in the query's IN clause.
     * @return A map of ID field values to SObject records.
     */
    private static Map<String, SObject> getDynamicMap(List<Case> cases,String objectName, 
                                                        String idFieldName, Set<String> idValues) {
        Map<String, SObject> dynamicMap = new Map<String, SObject>();
        if(idValues==null || idValues.isEmpty()) {
            return dynamicMap;
        }
        // Construct the SOQL query dynamically
        String query = 'SELECT Id, ' + idFieldName+','+AdditionalFields+ ' FROM ' + objectName + ' WHERE ' + idFieldName + ' IN :idValues'
                           +' AND ' +idFieldName+'!=null ';
        // Execute the dynamic query
        List<SObject> sObjects = Database.query(query);
        for (SObject sObj : sObjects) {
            if (sObj.get(idFieldName) != null) {
                dynamicMap.put((String)sObj.get(idFieldName), sObj);
            }
        }
        return dynamicMap;
    }

    /**
     * Extracts a set of key values from a list of Case records based on a specified key.
     * @param cases The list of Case records to extract key values from.
     * @param key The key to extract from the Case records.
     * @return A set of extracted key values.
     */
    private static Set<String> extractKeyValues(List<Case> cases, String key) {
        Set<String> setKeyValues = new Set<String>();
        for (Case caseRecord : cases) {
            String jsonString = extractJsonString(caseRecord.Description);
            if (jsonString != null) {
                Map<String, Object> jsonMap = (Map<String, Object>) JSON.deserializeUntyped(jsonString);
                String keyValue = String.valueOf(jsonMap.get(key));
                if (keyValue != null) {
                    setKeyValues.add(keyValue);
                }
            }
        }
        return setKeyValues;
    }

    
    /**
     * Extracts a JSON string from a Case description and validates it.
     * @param description The Case description to extract a JSON string from.
     * @return The extracted and validated JSON string.
     */
    private static String extractJsonString(String description) {
        Integer startIndex = description.indexOf('{');
        Integer endIndex = description.lastIndexOf('}');

        if (startIndex != -1 && endIndex != -1 && endIndex > startIndex) {
            String potentialJson = description.substring(startIndex, endIndex + 1);
            // Clean the extracted JSON string
            String cleanedJson = cleanJsonString(potentialJson);
            try {
                JSON.deserializeUntyped(cleanedJson);
                return cleanedJson; // Return the cleaned and validated JSON string
            } catch (Exception ex) {
                String message = 'Case Handler failed while extracting JSON' +'Error Message='+ex.getMessage();
                GeneralUtility.postToRecord(lstAdmins[0], lstAdmins, message);
            }
        }
        return null;
    }

    /**
     * Cleans a JSON string by removing newlines and carriage returns.
     * @param jsonString The JSON string to clean.
     * @return The cleaned JSON string.
     */
    private static String cleanJsonString(String jsonString) {
        String cleanedString = jsonString.replaceAll('\n','').replaceAll('\r','');
        return cleanedString;
    }
    private static void postErrorToPG(String message) {
        GeneralUtility.postToRecord(SELFSERVEPG, new List<String>{SELFSERVEPG}, message); 
    }
}