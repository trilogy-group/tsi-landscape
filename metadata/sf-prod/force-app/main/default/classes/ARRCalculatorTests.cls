@isTest
private class ARRCalculatorTests {
    @isTest static void arrCalculatorTest() {
        TestData.ArrangeReturn data = TestData.createOppAndContract();
        List<Contract> contracts = new List<Contract>();
        contracts.add(data.contract);
        Test.startTest();
        ARRCalculator.updateContractsAndAccountsARR(contracts);
        contracts = [SELECT ARR__c, Account.ARR__c FROM Contract ORDER BY ContractNumber];
        Test.stopTest();
        System.assertEquals(1200,contracts[0].ARR__c,'ARR for contract should be 1200');
        System.assertEquals(1200,contracts[0].Account.ARR__c,'ARR for account should be 1200');
    }

    @isTest static void arrCalculatorBatchTest() {
        TestData.ArrangeReturn data = TestData.createOppAndContract();
        List<Contract> contracts = new List<Contract>();
        contracts.add(data.contract);
        
        Test.startTest();
        ARRCalculatorScheduler scheduler = new ARRCalculatorScheduler();
        scheduler.execute(null);
        

        contracts = [SELECT ARR__c, Account.ARR__c FROM Contract ORDER BY ContractNumber];
        Test.stopTest();
        //ARR should be 0 because scheduler is only calculating arr from contracts that ended yesterday
        System.assertEquals(0,contracts[0].ARR__c,'ARR for contract should be 0');
        System.assertEquals(0,contracts[0].Account.ARR__c,'ARR for account should be 0');
    }

    @isTest static void arrCalculatorSchedulerTest() {
        TestData.ArrangeReturn data = TestData.createOppAndContract();
        List<Contract> contracts = new List<Contract>();
        contracts.add(data.contract);
        
        Test.startTest();
        ARRCalculatorBatch batch = new ARRCalculatorBatch();
        Database.executeBatch(batch, 50);
        

        contracts = [SELECT ARR__c, Account.ARR__c FROM Contract ORDER BY ContractNumber];
        Test.stopTest();
        //ARR should be 0 because batch is only calculating arr from contracts that ended yesterday
        System.assertEquals(0,contracts[0].ARR__c,'ARR for contract should be 0');
        System.assertEquals(0,contracts[0].Account.ARR__c,'ARR for account should be 0');
    }
}