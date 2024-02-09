public with sharing class OpportunityContactRoleTriggerHandler {
  public static void UpdatePrimaryContact(
    List<OpportunityContactRole> newRecords,
    Map<Id, OpportunityContactRole> newMap,  
    List<OpportunityContactRole> oldRecords,
    Map<Id, OpportunityContactRole> oldMap
  ) {
      List<Opportunity> opportunitiesToUpdate = new List<Opportunity>();
      List<Contact> contacts = new List<Contact>();
      Set<Id> contactIds = new Set<Id>(); // A set to filter out contact duplicates
      Set<Id> oppIds = new  Set<Id>();

      for (OpportunityContactRole r : newRecords) { // Get all the corresponding opportunities
        oppIds.add(r.OpportunityId);
      }

      Map<Id, Opportunity> mapOpps = new Map<Id, Opportunity>(
      [SELECT Id, Renewal_Date__c, Primary_Contact_Changed__c, Product__c, StageName 
        FROM Opportunity 
        WHERE Id IN :oppIds]
      );

      for (OpportunityContactRole r : newRecords) {
        if (r.IsPrimary) {
            Opportunity opp = mapOpps.get(r.OpportunityId);
            if(!contactIds.contains(r.ContactId)) { // Prevent duplication error                                
                Contact contact = new Contact(
                  Id = r.ContactId, 
                  Current_Renewal_Date__c = opp.Renewal_Date__c, 
                  Current_Product_Family__c = opp.Product__c, 
                  Current_Opportunity_Stage__c = opp.StageName);
                
                contacts.add(contact);
                contactIds.add(contact.Id);
            }
            if(oldMap != null){
                OpportunityContactRole oldRole = oldMap.get(r.Id);
                if(!oldRole.IsPrimary){
                    // The primary contact changed
                    opp.Primary_Contact_Changed__c = System.now();
                    opportunitiesToUpdate.add(opp);
                }
            }else{
                opp.Primary_Contact_Changed__c = System.now();
                opportunitiesToUpdate.add(opp);
            }
          }
      }
      update opportunitiesToUpdate;
      update contacts;

    // Update the Home_Product_Renewal_Contact__c field on the Account
    Map<Id, String> primaryContactNamesMap = new Map<Id, String>();
    Map<Id, Account> accountsToUpdateMap = new Map<Id, Account>();
    Set<Id> updatedOppIds = new Set<Id>();
    
    for (OpportunityContactRole role : newRecords) {
        if (role.IsPrimary) {
            updatedOppIds.add(role.OpportunityId);
        }
    }
        
    if (!updatedOppIds.isEmpty()) {
        for (OpportunityContactRole role : [SELECT Opportunity.AccountId,Opportunity.Term_End_Date__c,Contact.Name
                                            FROM OpportunityContactRole
                                            WHERE IsPrimary = true AND OpportunityId IN :updatedOppIds]) {
                                                primaryContactNamesMap.put(role.Opportunity.AccountId, role.Contact.Name);
                                            }
        
        for (Opportunity opp : [SELECT Id, AccountId,Term_End_Date__c FROM Opportunity WHERE Term_End_Date__c > TODAY AND Id IN :updatedOppIds]) {
            if (opp.AccountId != null && primaryContactNamesMap.containsKey(opp.AccountId)) {
                String primaryContactName = primaryContactNamesMap.get(opp.AccountId);
                Id accountId = opp.AccountId;
                // Check if the Account is already in the map
                if (accountsToUpdateMap.containsKey(accountId)) {
                    // If the Account is already in the map, update the Home_Product_Renewal_Contact__c field
                    Account acc = accountsToUpdateMap.get(accountId);
                    acc.Home_Product_Renewal_Contact__c = primaryContactName;
                } else {
                     // If the Account is not in the map, create a new Account with the updated Home_Product_Renewal_Contact__c field
                    Account acc = new Account(Id = accountId, Home_Product_Renewal_Contact__c = primaryContactName);
                    accountsToUpdateMap.put(accountId, acc);
                }       
            }
        }
        
        // Perform the update on the Account records
        if (!accountsToUpdateMap.isEmpty()) {
            update accountsToUpdateMap.values();
        }
    }
  }
}