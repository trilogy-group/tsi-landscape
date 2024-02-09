@isTest
public class SamePrimaryContactOppControllerTest {
  @isTest 
  static void testGetSamePrimaryContactOpp(){
    Opportunity opp = new Opportunity();
    opp.Name = 'Test Opp';
    opp.CloseDate = System.today();
    opp.Renewal_Date__c = System.today();
    opp.StageName = 'Pending';
    opp.Type = 'Renewal';
    opp.Product__c = 'Test';
    opp.Parent_Subscription_ID__c = 'Test';
    insert opp;

    Contact con = new Contact();
    con.FirstName = 'test first name';
    con.LastName = 'test last name';
    con.Email = 'test@test.com';
    insert con;

    OpportunityContactRole conRole = new OpportunityContactRole();
    conRole.OpportunityId = opp.Id;
    conRole.ContactId = con.Id;
    conRole.IsPrimary = true;
    insert conRole;


    Test.startTest();
    List<Opportunity> opps = SamePrimaryContactOppController.getSamePrimaryContactOpp(opp.Id);
    Assert.areEqual(0, opps.size(), 'Should be 0 opp');
    Test.stopTest();
  }    
}