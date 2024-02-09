@isTest
public with sharing class TriggerHandlerTest {
  @isTest
  public static void testEnableAllTriggers(){
    Test.startTest();

    Automation_Settings__c settings = new Automation_Settings__c();
    insert settings;
    
    TriggerHandler handler = new TriggerHandler('Account');
    
    System.assertEquals(false, handler.bypassTrigger(), 'All Triggers are enabled.');

    Test.stopTest();    
  }

  @isTest
  public static void testDisableAllTriggers(){
    Test.startTest();

    Automation_Settings__c settings = new Automation_Settings__c();
    settings.Disable_All_Triggers__c = true;
    insert settings;
    
    TriggerHandler handler = new TriggerHandler('Account;Opportunity');
    
    System.assertEquals(true, handler.bypassTrigger(), 'Triggers should be bypassed.');

    Test.stopTest();    
  }

  @isTest
  public static void testDisableSObjectTrigger(){
    Test.startTest();

    Automation_Settings__c settings = new Automation_Settings__c();
    settings.Disable_SObject_Trigger__c = 'Account;Opportunity';
    insert settings;
    
    TriggerHandler handler = new TriggerHandler('Account');
    
    System.assertEquals(true, handler.bypassTrigger(), 'Account Trigger should be bypassed.');

    Test.stopTest();    
  }
}