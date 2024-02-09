public with sharing class SamePrimaryContactOppController {
  @AuraEnabled(cacheable=true)
  public static List<Opportunity> getSamePrimaryContactOpp(string opportunityId) {
      try {
          Opportunity oppty = [
          SELECT Id, (SELECT Id, ContactId FROM OpportunityContactRoles WHERE IsPrimary = TRUE) 
          FROM Opportunity 
          WHERE Id = :opportunityId];
          if (oppty.OpportunityContactRoles.isEmpty()) {
              return new List<Opportunity>();
          }
          Id primaryContactId = oppty.OpportunityContactRoles.get(0).ContactId;
          List<Opportunity> samePrimaryOpptys = [SELECT Id, Name, Type 
          FROM Opportunity 
          WHERE Primary_Contact__c = :primaryContactId 
          And IsClosed = false 
          AND Id != :opportunityId];
          return samePrimaryOpptys;
      } catch (Exception e) {
          throw new AuraHandledException(e.getMessage());
      }
  }
}