/**
 * @description: LAMBDA-58199 Tasktrigger for Task object 
 */
trigger TaskTrigger on Task (before insert, before update) {
  TriggerHandler handler = new TriggerHandler('Task');
  if(handler.bypassTrigger()) {
      return;
  }

  if (Trigger.isBefore) {
    if (Trigger.isInsert) {
      TaskTriggerHandler.validateTasks(Trigger.new);
    }

    if (Trigger.isUpdate) {
      TaskTriggerHandler.validateTasks(Trigger.new);
    }
  } 
}