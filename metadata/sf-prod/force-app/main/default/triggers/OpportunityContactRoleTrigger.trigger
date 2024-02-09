trigger OpportunityContactRoleTrigger on OpportunityContactRole (after insert, after update) {

  TriggerHandler handler = new TriggerHandler('OpportunityContactRole');
  if(handler.bypassTrigger()) {
      return;
  }

  if(Trigger.isAfter){
    if(Trigger.isInsert) {
      OpportunityContactRoleTriggerHandler.updatePrimaryContact(Trigger.new, Trigger.newMap, null, null);
    }

    if (Trigger.isUpdate) {
      OpportunityContactRoleTriggerHandler.updatePrimaryContact(Trigger.new, Trigger.newMap, 
        Trigger.old, Trigger.oldMap);
    }
  }

}