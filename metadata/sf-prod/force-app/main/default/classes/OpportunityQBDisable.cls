public with sharing class OpportunityQBDisable {
    //Adding a new setting with setup owner as the current user will disable the QBs only for the current user.
    @InvocableMethod(label='Disable opportunity quality bars for current user')
    public static void execute() {
        Id userId = UserInfo.getUserId();
        List<Quality_Bars_Configuration__c> qbConfigs = [SELECT Disabled_Opportunity_QBs__c 
            FROM Quality_Bars_Configuration__c WHERE SetupOwnerId = :userId];
        Quality_Bars_Configuration__c qbConfig;
        if (qbConfigs.size() == 0) {
            qbConfig = new Quality_Bars_Configuration__c();
            qbConfig.SetupOwnerId = userId;
        } else {
            qbConfig = qbConfigs[0];
        }
        qbConfig.Disabled_Opportunity_QBs__c = true;
        upsert qbConfig;
    }
}