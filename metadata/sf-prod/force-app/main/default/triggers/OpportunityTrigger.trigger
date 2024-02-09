/**
 * @author: Paras Dhingra
 * @date: 06th Oct 2022
 * @description: LAMBDA-40414 Trigger for Opportunity object.
 */
trigger OpportunityTrigger on Opportunity (before update, after update) {
  TriggerHandler handler = new TriggerHandler('Opportunity');
  if(handler.bypassTrigger()) {
      return;
  }

  if (Trigger.isBefore && Trigger.isUpdate) {
      OpportunityTriggerHandler.oppyValidations(Trigger.newMap,Trigger.oldMap);
  } else if (Trigger.isAfter && Trigger.isUpdate) {
    // spilt this else if block once having after insert and after update logic
    OpportunityTriggerHandler.recallQuoteApprovalProcess(Trigger.new, Trigger.oldMap);
    OpportunityTriggerHandler.onOutreachSequenceTrigger(Trigger.oldMap,Trigger.newMap);
    OpportunityARPackageGenerator.generateARPackage(Trigger.new, Trigger.oldMap);
     
  }
}