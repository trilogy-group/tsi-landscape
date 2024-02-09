public with sharing class ContractTriggerHandler {
  public static void updateContractsAndAccountsARR(List<Contract> records, Map<Id, Contract> oldMap) {
    List<Contract> contracts = new List<Contract>();
    for (Contract contract : records) {
        Contract oldContract = oldMap.get(contract.Id);
        if(oldContract.EndDate != contract.EndDate || oldContract.Status != contract.Status || 
            oldContract.SBQQ__Evergreen__c != contract.SBQQ__Evergreen__c) {
            contracts.add(contract);
        }
    }
    ARRCalculator.updateContractsAndAccountsARR(contracts);
  }
}