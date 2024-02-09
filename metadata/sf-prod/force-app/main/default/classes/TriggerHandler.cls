public with sharing class TriggerHandler {
  public String sobjectAPIName { get; private set; } 
  public Boolean disableAllTriggers { get; private set; }
  public Boolean disableSObjectTrigger { get; private set; }
  
  public TriggerHandler(String sobjectAPIName) {
    this.sobjectAPIName = sobjectAPIName;

    Automation_Settings__c settings = Automation_Settings__c.getInstance(UserInfo.getUserId());
    this.disableAllTriggers = settings.Disable_All_Triggers__c;
    this.disableSObjectTrigger = getDisableSObjectTrigger(settings);
  }

  private Boolean getDisableSObjectTrigger(Automation_Settings__c settings) {
    if(String.isBlank(settings.Disable_SObject_Trigger__c)) {
      return false;
    }

    return settings.Disable_SObject_Trigger__c.replace(' ', '').split(';').contains(this.sobjectAPIName);
  }

  public Boolean bypassTrigger() {
    return this.disableAllTriggers || this.disableSObjectTrigger;
  }
}