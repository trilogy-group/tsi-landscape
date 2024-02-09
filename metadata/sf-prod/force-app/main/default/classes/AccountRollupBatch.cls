/**
 * @description: LAMBDA-63234 Batch to rollup ARR from Contract
 */
public class AccountRollupBatch implements Database.Batchable<sObject>,Schedulable {
    public String query ; 
    public Database.QueryLocator start(Database.BatchableContext bc) {
        if(query==null || query=='') {
            query = 'SELECT Id FROM Account Where Id IN' +
                    ' (SELECT AccountId FROM Opportunity WHERE ' +
                    ' Renewal_Date__c <= Today' + 
                    ' and isWon = true and Type!=\'Prime\' and RecordType.DeveloperName In (\'Sales\',\'New_Business\')) ' ;
        }
        return Database.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext bc, List<Account> scope) {
        Map<Id, Decimal> accountToARRMap = new Map<Id, Decimal>();
        Map<Id, Set<String>> accountToProductFamiliesMap = new Map<Id, Set<String>>();
        Map<Id,Account> mapAccountIds = new Map<Id, Account> (scope);
        Set<String> productFamilyActiveValues = new Set<String>();
        Map<Id, String> accountIdToHighestSuccessLevel = new Map<Id, String>();
        productFamilyActiveValues.addAll(getValidProductFamilies());
        for (Opportunity opp : [SELECT Id, AccountId, Product__c, Renewal_Date__c, Term_End_Date__c,
                                Arr__c,Success_Level__c
                               FROM Opportunity 
                               WHERE AccountId IN :mapAccountIds.keyset() AND 
                               Renewal_Date__c < Today   AND 
                               isWon=true ]) {
            Id accountId = opp.AccountId;
            Decimal opportunityARR = opp.Term_End_Date__c < Date.today()?0.0:opp.Arr__c;
            String productFamily = opp.Product__c;
            
            if (!accountToARRMap.containsKey(accountId)) {
                accountToARRMap.put(accountId, opportunityARR);
            } else {
                accountToARRMap.put(accountId, accountToARRMap.get(accountId) + opportunityARR);
            }
            
            if (productFamily != null) {
                if(!productFamilyActiveValues.contains(productFamily)) {
                    continue;
                }
                if (!accountToProductFamiliesMap.containsKey(accountId)) {
                    accountToProductFamiliesMap.put(accountId, new Set<String>{productFamily});
                } else {
                    accountToProductFamiliesMap.get(accountId).add(productFamily);
                }
            }
            Integer oppySLRank = getSuccessLevelRank(opp.Success_Level__c);                     
            if(!accountIdToHighestSuccessLevel.containsKey(opp.AccountId) || 
                oppySLRank > getSuccessLevelRank(accountIdToHighestSuccessLevel.get(opp.AccountId))) {
                String successLevel = opp.Term_End_Date__c < Date.today()?'':opp.Success_level__c;
                accountIdToHighestSuccessLevel.put(opp.AccountId, successLevel);
             }
        }
        
        List<Account> accountsToUpdate = new List<Account>();
        for (Account acc : scope) {
            acc.ARR__c = accountToARRMap.get(acc.Id);
            if (accountToProductFamiliesMap.containsKey(acc.Id)) {
                acc.Product_families__c = String.join(new List<String>(accountToProductFamiliesMap.get(acc.Id)), ';');
            } else {
                acc.Product_families__c = null; // Reset to null if no products found
            }
            if(accountIdToHighestSuccessLevel.containsKey(acc.Id)) {
                acc.Success_Level__c = accountIdToHighestSuccessLevel.get(acc.Id);
            } else {
                acc.Success_Level__c = '';//Reset to null if no success level found
            }
            accountsToUpdate.add(acc);
        }
        
        update accountsToUpdate;
    }

    public void finish(Database.BatchableContext bc){
    }
    private Set<String> getValidProductFamilies() {
        Set<String> pickListValuesList= new Set<String>();
        Schema.DescribeFieldResult fieldResult = Account.Product_families__c.getDescribe();
        List<Schema.PicklistEntry> ple = fieldResult.getPicklistValues();
        for( Schema.PicklistEntry pickListVal : ple) {
            pickListValuesList.add(pickListVal.getLabel());
        }     
        return pickListValuesList;
    }
    public void execute(SchedulableContext ctx) {
        AccountRollupBatch processor = new AccountRollupBatch();
        Database.executeBatch(processor, 50);
    }
    private static Integer getSuccessLevelRank(String successLevel) {
    Map<String, Integer> successLevelRankings = new Map<String, Integer>{
        'Legacy' => 1,
        'Standard' => 2,
        'Gold' => 3,
        'Platinum' => 4
    };
    
    return successLevelRankings.containsKey(successLevel) ? successLevelRankings.get(successLevel) : 0;
}

}