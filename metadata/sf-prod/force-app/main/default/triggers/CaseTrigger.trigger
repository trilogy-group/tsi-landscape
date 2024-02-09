trigger CaseTrigger on Case (before insert) {
    TriggerHandler handler = new TriggerHandler('Case');
    if(handler.bypassTrigger()) {
        return;
    }
    if (Trigger.isBefore && Trigger.isInsert) {
       System.debug('==entering process cases==');
       CaseTriggerHandler.processCases(Trigger.new);
    }
  }