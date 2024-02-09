public with sharing class OpportunityQBEnable {
    //Deleting the setting for the current user and current user will use org default settings.
    @InvocableMethod(label='Enable opportunity quality bars for current user')
    public static void execute() {
        Id userId = UserInfo.getUserId();
        List<Quality_Bars_Configuration__c> qbConfigs = [SELECT Disabled_Opportunity_QBs__c 
            FROM Quality_Bars_Configuration__c WHERE SetupOwnerId = :userId];
        if (qbConfigs.size() != 0) {
            delete qbConfigs[0];
        }
    }
}