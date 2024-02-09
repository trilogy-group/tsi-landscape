public with sharing class ARRCalculatorBatch implements Database.Batchable<sObject> {
    public Database.QueryLocator start(Database.BatchableContext bc){
        return Database.getQueryLocator('SELECT Id, ARR__c, AccountId FROM Contract WHERE EndDate = Yesterday');
    }

    public void execute(Database.BatchableContext bc, List<sObject> contracts) {
        ARRCalculator.updateContractsAndAccountsARR(contracts);
    }

    public void finish(Database.BatchableContext bc){
    }
}