trigger ContractTrigger on Contract (after update) {
  TriggerHandler handler = new TriggerHandler('Contract');
  if(handler.bypassTrigger()) {
      return;
  }

  if(Trigger.isAfter && Trigger.isUpdate){
    ContractTriggerHandler.updateContractsAndAccountsARR(Trigger.new, Trigger.oldMap);
  }
}