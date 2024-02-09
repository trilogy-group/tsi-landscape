@isTest
public class UpdateOpportunitiesBatchTest {
    static final String TEST_EMAIL = 'test@trilogy.com';

    @isTest
    static void update_all_opportunites() {
        //Arrange
        TestData.createOppAndContract();
        Test.StartTest();
        List<Opportunity> opps = [SELECT Id, LastModifiedDate, Master_Products_Quantity__c 
                                  FROM Opportunity WHERE Master_Products_Quantity__c != 0];
        opps[0].Master_Products_Quantity__c = 0;
        opps[0].Opportunity_Term__c = 0;
        //Act
        update opps;
        UpdateOpportunitiesBatch batch = new UpdateOpportunitiesBatch(new String[] {TEST_EMAIL});
        Database.executeBatch(batch, 200);
        //Verify
        List<Opportunity> updatedOpp = [select Id, LastModifiedDate, Master_Products_Quantity__c, Opportunity_Term__c 
                                        From Opportunity];
        Test.StopTest();
        System.assert(updatedOpp[0].Master_Products_Quantity__c == 20.0, 
                        'Error Opportunity Master Products Quantitiy not updated');
        System.assert(updatedOpp[0].Opportunity_Term__c == 1, 'Error Opportunity Term not updated');
        
    }
}