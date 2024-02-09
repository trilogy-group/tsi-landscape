public with sharing class QuoteLineTriggerHandler {
    public static void updateQuoteLinesEndDates(List<SBQQ__QuoteLine__c> oldRecords) {
      for (SBQQ__QuoteLine__c line : oldRecords) {
        // Call the subflow to update end dates
        Flow.Interview flow = new Flow.Interview.UpdateQuoteLinesEndDates(new map<String,Object> 
                {'TargetQuote' => line.SBQQ__Quote__r});
        flow.start();
      }
    }
}