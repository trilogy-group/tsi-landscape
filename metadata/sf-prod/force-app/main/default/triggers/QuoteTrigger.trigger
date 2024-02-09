trigger QuoteTrigger on SBQQ__Quote__c (after update) {
  TriggerHandler handler = new TriggerHandler('SBQQ__Quote__c');
  if(handler.bypassTrigger()) {
      return;
  }

  // spilt below block to else if check once have more context
  if (Trigger.isAfter && Trigger.isUpdate) {
      QuoteTriggerHandler.generateFinalQuote(Trigger.oldMap, Trigger.new);
  } 
}