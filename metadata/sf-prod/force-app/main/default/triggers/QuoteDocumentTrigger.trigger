trigger QuoteDocumentTrigger on SBQQ__QuoteDocument__c (after insert) {
  TriggerHandler handler = new TriggerHandler('SBQQ__QuoteDocument__c');
  if(handler.bypassTrigger()) {
      return;
  }

  // spilt below block to else if check once have more context
  if (Trigger.isAfter && Trigger.isInsert) {
      QuoteSigningQueuable.EnqueueSigningTasks(Trigger.new); // Create a signing agreement and send it to the customer
  } 
}