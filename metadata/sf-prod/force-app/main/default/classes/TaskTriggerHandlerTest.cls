@isTest
public  class TaskTriggerHandlerTest {
    static string completedStatus = 'Completed - Evaluating';
    static string assertNotReachFlag = 'Controll will not reach here';
    @isTest
    static void testTaskCreation() {
        //test task creation
        Test.startTest();
        Task testTask1 = new Task(Subject = 'Test', Type='Call', Status = completedStatus);
        insert testTask1;
        System.assert(true,'Control will reach here as there will be no exception');
        Test.stopTest();
    }
    @isTest
    static void testTaskCreationWithValidOpportunity() {
        TestData.ArrangeReturn data = TestData.createOppAndContract();

        Opportunity testOppy = [SELECT Id, Name FROM Opportunity WHERE Id=: data.opportunity.Id LIMIT 1];
        Test.startTest();
        Task testTask1 = new Task(Subject ='Renewal Call - Test', 
                                Type='Call',Status=completedStatus,
                                WhatId = testOppy.Id);
        insert testTask1;
        System.assert(true, AssertNotReachFlag);
        Test.stopTest();
    }
    @isTest
    static void testTaskCreationWithInValidOpportunity() {
        TestData.createOpportunityForCPQDocument('Renewal', 'NorthPlains');
        Opportunity testOppy = [SELECT Id, Name FROM Opportunity LIMIT 1];
        Test.startTest();
        Task testTask1 = new Task(Subject ='Renewal Call - Test', 
                                Type='Call',Status=completedStatus,
                                WhatId = testOppy.Id);
        try {
            insert testTask1;
            System.assert(false,'Control will not reach here due to validation');
        } catch(Exception ex) {
            System.assertEquals(ex.getDmlMessage(0), System.Label.TaskRenewalCallMessage,'checking exception');
        }
        System.assert(true, AssertNotReachFlag);
        Test.stopTest();
    }
    @isTest
    static void testPriceResetTaskCreationWithValidOpportunity() {
        TestData.ArrangeReturn data = TestData.createOppAndContract();

        Opportunity testOppy = [SELECT Id, Name FROM Opportunity WHERE Id=: data.opportunity.Id LIMIT 1];
        Test.startTest();
        Task testTask1 = new Task(Subject ='Price Reset Call - Test', 
                                Type='Call',Status=completedStatus,
                                WhatId = testOppy.Id);
        insert testTask1;
        System.assert(true, AssertNotReachFlag);
        Test.stopTest();
    }
    @isTest
    static void testPriceResetTaskCreationWithInValidOpportunity() {
        TestData.createOpportunityForCPQDocument('Renewal', 'NorthPlains');
        Opportunity testOppy = [SELECT Id, Name FROM Opportunity LIMIT 1];
        Test.startTest();
        Task testTask1 = new Task(Subject ='Price Reset Call - Test', 
                                Type='Call',Status=completedStatus,
                                WhatId = testOppy.Id);
        try {
            insert testTask1;
            System.assert(false,'Control will not reach here due to validation');
        } catch(Exception ex) {
            System.assertEquals(ex.getDmlMessage(0), System.Label.TaskPriceResetCallMessage,'checking exception');
        }
        System.assert(true, AssertNotReachFlag);
        Test.stopTest();
    }
}