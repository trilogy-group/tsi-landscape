public with sharing class ARRCalculator {
    public static void updateContractsAndAccountsARR(List<Contract> contracts) {
        if (contracts.size() == 0) {
            return;
        }
        
        Set<Id> contractIds = new Set<Id>();
        Set<Id> accountIds = new Set<Id>();
        for (Contract contract : contracts) {
            contractIds.add(contract.Id);
            accountIds.add(contract.AccountId);
        }

        updateContractsARR(contracts, contractIds);
        updateAccountsARR(accountIds);
    }

    private static void updateContractsARR(List<Contract> contracts, Set<Id> contractIds) {
        // calculates ARR looking the values in all subscriptions
        List<SBQQ__Subscription__c> subscriptions = [SELECT ARR__c,SBQQ__Contract__c FROM SBQQ__Subscription__c
                                                        WHERE SBQQ__Contract__c in :contractIds AND ARR__c != 0];
        Map<Id,Decimal> mapNewARR = new Map<Id,Decimal>();
        for (SBQQ__Subscription__c subscription : subscriptions) {
            Decimal mappedARR = mapNewARR.containsKey(subscription.SBQQ__Contract__c) ? 
                mapNewARR.get(subscription.SBQQ__Contract__c) : 0;
            mapNewARR.put(subscription.SBQQ__Contract__c, mappedARR + subscription.ARR__c);
        }

        // update if value is different
        List<Contract> toUpdate = new List<Contract>();
        for (Contract contract : contracts) {
            // Creating new contract because the contract from the trigger list can't be updated.
            Contract contractToUpdate = new Contract();
            contractToUpdate.Id = contract.Id;
            if (mapNewARR.containsKey(contract.Id)) {
                Decimal newARR = mapNewARR.get(contract.Id);
                if (newARR != contract.ARR__c) {
                    contractToUpdate.ARR__c = newARR;
                    toUpdate.add(contractToUpdate);
                } 
            } else if (contract.ARR__c != 0) {
                contractToUpdate.ARR__c = 0;
                toUpdate.add(contractToUpdate);
            }
        }
        update toUpdate;
    }

    private static void updateAccountsARR(Set<Id> accountIds) {
        // calculates ARR looking the values in all contracts
        Map<Id, Decimal> mapNewARR = new Map<Id, Decimal>();
        List<Contract> allContracts = [SELECT ARR__c, AccountId, SBQQ__ActiveContract__c FROM Contract 
                                        WHERE AccountId in :accountIds];
        for (Contract contract : allContracts) {
            Decimal mappedARR = mapNewARR.containsKey(contract.AccountId) ? mapNewARR.get(contract.AccountId) : 0;
            Decimal arr = contract.SBQQ__ActiveContract__c == 1 ? contract.ARR__c : 0;
            mapNewARR.put(contract.AccountId, mappedARR + arr);
        }

        // update if value is different
        List<Account> accounts = [SELECT ARR__c FROM Account WHERE Id in :accountIds];
        List<Account> toUpdate = new List<Account>();
        for (Account account : accounts) {
            if (mapNewARR.containsKey(account.Id)) {
                Decimal newARR = mapNewARR.get(account.Id);
                if (newARR != account.ARR__c) {
                    account.ARR__c = newARR;
                    toUpdate.add(account);
                } 
            } else if (account.ARR__c != 0) {
                account.ARR__c = 0;
                toUpdate.add(account);
            }
        }
        update toUpdate;
    }
}