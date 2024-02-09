/**
 * @description: LAMBDA-58199 Trigger handler for Task object
 */
public without sharing class TaskTriggerHandler {

    public static void validateTasks(List<Task> newRecords) {
        if(currentUserHasByPass()) {
            return;
        }
        validateRelatedOpportunities(newRecords, 'Renewal Call', System.Label.TaskRenewalCallMessage);
        validateRelatedOpportunities(newRecords, 'Price Reset Call', System.Label.TaskPriceResetCallMessage);
    }
    private static void validateRelatedOpportunities(List<Task> newRecords, string taskSubject, string errorMessage) {
        Set<Id> setRelatedOpportunityIds = new Set<Id>();
        Set<Task> setaffectedTasks = new Set<Task>();
        for(Task tsk : newRecords) {
            String whatId = (String)tsk.WhatId;
            if(whatId!=null && whatId.startsWithIgnoreCase('006') 
                && tsk.Subject.containsIgnoreCase(taskSubject) 
                && (tsk.Type=='Call' || tsk.Type==null)) {
                    setRelatedOpportunityIds.add(whatId);
                    setaffectedTasks.add(tsk);
            }
        }
        Map<Id,Opportunity> queriedOpportunities = fetchRelatedOpportunities(setRelatedOpportunityIds);
        addErrorMessage(queriedOpportunities,setaffectedTasks, errorMessage);
    }
    private static Map<Id,Opportunity> fetchRelatedOpportunities(Set<Id> setOpportunityId) {
        Map<Id,Opportunity> mapOpportunityToReturn = new Map<Id,Opportunity>();
        if(setOpportunityId!=null && !setOpportunityId.isEmpty()) {
            mapOpportunityToReturn = new Map<Id,Opportunity>([SELECT Id, 
            StageName, SBQQ__PrimaryQuote__c FROM Opportunity
            WHERE Id IN: setOpportunityId AND (SBQQ__PrimaryQuote__c=null OR  HasOpportunityLineItem=false)]);
        }
        return mapOpportunityToReturn;
    }
    private static void addErrorMessage(Map<Id,Opportunity> mapQueriedOppys,
      Set<Task> setaffectedTasks,string errorMessage) {
        if(setaffectedTasks.isEmpty() || mapQueriedOppys==null || mapQueriedOppys.isEmpty()) {
            return;
        }
        //add messages to non-eligible tasks
        for(Task tsk : setaffectedTasks) {
            if(mapQueriedOppys.containsKey(tsk.WhatId)) {
                tsk.addError(errorMessage);
            }
        }
    }
    public static boolean currentUserHasByPass() {
        Quality_Bars_Configuration__c qualityBars = Quality_Bars_Configuration__c.getInstance();
        if(qualityBars!=null && qualityBars.Disabled_Opportunity_QBs__c) {
            return true;
        }
        return false;
    }
}