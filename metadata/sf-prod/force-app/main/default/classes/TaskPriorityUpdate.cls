public with sharing class TaskPriorityUpdate implements Database.Batchable<sObject>, Schedulable {
    public void execute(SchedulableContext sc) {
        Database.executeBatch(this);
    }
	public List<String> lstIdString ;
    public Database.QueryLocator start(Database.BatchableContext bc) {
        String query = 'SELECT Id, SLA_Based_Priority__c, Priority ' +
                       'FROM Task ' +
                       'WHERE Status = \'Open\' ' +
                       'AND One_Day_Expire__c = TRUE';
        return Database.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext bc, List<Task> scope) {
        List<Task> updatedTasks = new List<Task>();
        Set<Id> queryTaskIds = new Set<Id>();
        for( Task t : scope ) {
            queryTaskIds.add(t.Id); 
        }
        for (Task t : [SELECT Id, SLA_Based_Priority__c, Priority From Task
                      	WHERE Status ='Open' AND One_Day_Expire__c = TRUE
                       AND Id In:queryTaskIds FOR UPDATE ]) {
            if(t.Priority != t.SLA_Based_Priority__c) {
                t.Priority = t.SLA_Based_Priority__c;
                updatedTasks.add(t);
            }
        }
        update updatedTasks;
    }

    public void finish(Database.BatchableContext bc) {
        System.debug('Priorities are updated.');
    }
}