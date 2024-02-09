@isTest 
private class MultiPicklistToTextTests {
    static testMethod void MultiPicklistToText() {
       // This test is there for code coverage of MultiPicklistToText
	   // Salesforce internally represents picklists and multiselect picklists as strings just doesn't make it available to flows
	   // The MultiPicklist just gets the value as string list and returns it back without doing any processing. 
	   // The test therefore also does the same.
       QC_Rule__c qc_rule = new QC_Rule__c(Name='Test Rule', Enforced_On__c='a:b:c:d'); 
       System.debug('QC Rule Enforced On : ' + qc_rule.Enforced_On__c);
        List<String> strPicklist = MultiPicklistToText.convertPickListToText(new List<string>{qc_rule.Enforced_On__c});
       System.assertEquals(strPicklist[0], qc_rule.Enforced_On__c);
    }
}