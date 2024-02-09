/**
 * LAMBDA-63540 Test class for QuoteEnable and Disable Method
 */
@isTest
public  class TestQuoteEnableDisable {
    @isTest
    public static void testCPQToggle() {
        Test.startTest();
        QuoteSBQQDisable.disableCPQTriggers();
        Assert.areEqual(false,SBQQ.TriggerControl.isEnabled(),'Checking CPQ Trigger disabled');
        QuoteSBQQEnable.enableCPQTriggers();
        Assert.areEqual(true,SBQQ.TriggerControl.isEnabled(),'Checking CPQ Trigger enabled');
        Test.stopTest();
    }
    
}