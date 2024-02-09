trigger QuoteLineTrigger on SBQQ__QuoteLine__c (after delete) {
  TriggerHandler handler = new TriggerHandler('SBQQ__QuoteLine__c');
  if(handler.bypassTrigger()) {
      return;
  }

  // spilt below block to else if check once have more context
  if (Trigger.isAfter && Trigger.isDelete) {
      QuoteLineTriggerHandler.updateQuoteLinesEndDates(Trigger.old);
  } 
}