@isTest
public with sharing class CreateCSMOpportunitiesTest {
    static final String TEST_EMAIL = 'test@trilogy.com';

    @isTest
    static void createCSMOpportunityTest(){
        // Arrange
        Test.startTest();
        TestData.ArrangeReturn data = TestData.createOppAndContract();
        String product = data.opportunity.Product__c;
        Test.stopTest();
        // Act

        // Assert
        List<Opportunity> csmOpps = [SELECT Id, ContractId, AccountId, Product__c, 
                                        CloseDate, Success_Level__c, Owner.Name
                                        FROM Opportunity WHERE Type = 'CSM'];
        System.assertEquals(1, csmOpps.size(), 'Should exist one CSM Opportunity.');
        System.assertEquals(data.contract.Id, csmOpps[0].ContractId, 'ContractId should match Id from Contract.');
        System.assertEquals(data.opportunity.AccountId, csmOpps[0].AccountId, 
            'AccountId should match AccountId from opportunity that originated the contract.');
        System.assertEquals(product, csmOpps[0].Product__c, String.format('Product Family should be {0}', 
            new String[] {product}));
        System.assertEquals(data.contract.EndDate, csmOpps[0].CloseDate, 'CloseDate should match Contract EndDate.');
        //this test case is not valid anymore as the Flow has been updated to work on record type and not on type
        /*System.assertEquals(data.opportunity.Success_Level__c, csmOpps[0].Success_Level__c, 
            'Success level should match success level from opportunity that originated the contract.');*/
        
    }

    
}