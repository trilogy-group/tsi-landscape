@isTest
private class TaskDispatchUnitTests {
    static final String MANAGER_PROFILE = 'Team Manager';
    static final String MANAGER_ROLE = 'Manager New Sales';
    static final String USER_PROFILE = 'System Administrator';

    @isTest static void taskWrapperTest() {
        String ASSERT_ERROR_MESSAGE = 'Tasks should be sorted according to their priority.';
        //Arrange
        List<TaskWrapper> toSortTaskWrapperList = new List<TaskWrapper>();
        Task t1 = new Task( Id = TestData.getFakeId(Task.getSObjectType()), Priority = '0');
        Task t2 = new Task( Id = TestData.getFakeId(Task.getSObjectType()), Priority = '2');
        Task t3 = new Task( Id = TestData.getFakeId(Task.getSObjectType()), Priority = '5');
        toSortTaskWrapperList = new TaskWrapper[]{new TaskWrapper(t1), new TaskWrapper(t2), new TaskWrapper(t3)};
        //Act
        toSortTaskWrapperList.sort();
        //Assert
        System.assert(toSortTaskWrapperList[0].tsk == t3, ASSERT_ERROR_MESSAGE);
        System.assert(toSortTaskWrapperList[1].tsk == t2, ASSERT_ERROR_MESSAGE);
        System.assert(toSortTaskWrapperList[2].tsk == t1, ASSERT_ERROR_MESSAGE);
    }

    @isTest static void taskDispatchSchedulerV2_E2E_Test() {
        //Arrange
        createTaskDispatcher();
        Opportunity testOpportunity = createOpportunityForTaskDispatcher();

        //Act
        Test.startTest();
        TaskDispatchSchedulerV2 scheduler = new TaskDispatchSchedulerV2(); // Just call the scheduler and wait for it's execution. It is better than the dummy 'i++' test
        scheduler.execute(null);
        Test.stopTest();

        //Assert
        List<Task> followUpTask = [SELECT Id, Subject FROM Task WHERE WhatId=:testOpportunity.Id];
        //tasks are not created out of working days
        Integer expected = TaskDispatchBatchV2.todayIsWorkingDay() ? 1 : 0;
        System.assertEquals(expected, followUpTask.size(), 'A tasks should be created.');
    }

    @isTest static void taskDispatchBatchV2_E2E_Test() {
        //Arrange
        createTaskDispatcher();
        Opportunity testOpportunity = createOpportunityForTaskDispatcher();

        //Act
        Test.startTest();
        TaskDispatchBatchV2 batch = new TaskDispatchBatchV2(); 
        Database.executeBatch(batch, 50);
        Test.stopTest();

        //Assert
        List<Task> followUpTask = [SELECT Id, Subject FROM Task WHERE WhatId=:testOpportunity.Id];
        //tasks are not created out of working days
        Integer expected = TaskDispatchBatchV2.todayIsWorkingDay() ? 1 : 0;
        System.assertEquals(expected, followUpTask.size(), 'A tasks should be created.');
    }
    
    @isTest static void taskDispatchBatchV2_E2E_Test_RoleBased() {
        //Arrange
        Task_Dispatcher__c taskDispatcher = createTaskDispatcher();
        taskDispatcher.Assign_to_Users_in_a_Role__c = true;
        update taskDispatcher;
        Opportunity testOpportunity = createOpportunityForTaskDispatcher();

        //Act
        Test.startTest();
        TaskDispatchBatchV2 batch = new TaskDispatchBatchV2(); 
        Database.executeBatch(batch, 50);
        Test.stopTest();

        //Assert
        List<Task> followUpTask = [SELECT Id, Subject FROM Task WHERE WhatId=:testOpportunity.Id];
        //tasks are not created out of working days
        Integer expected = TaskDispatchBatchV2.todayIsWorkingDay() ? 1 : 0;
        System.assertEquals(expected, followUpTask.size(), 'A tasks should be created.');
    }
    
    // Create an opportunity with the Next Follow Up Date = Today and an ISR as the Owner
    static Opportunity createOpportunityForTaskDispatcher() {
        Opportunity testOpportunity = TestData.createOpportunityForCPQDocument();
        User userManager = TestData.getUser(MANAGER_PROFILE);
        TestData.updateUserRole(userManager, MANAGER_ROLE);
        User user = TestData.getUser(USER_PROFILE, userManager);
        UserRole role = [SELECT ID, NAME 
                         FROM UserRole 
                         WHERE id IN ('00E2x000000cVXw','00E2x000000cXlE') 
                         LIMIT 1];
        user.Product_Certifications__c = testOpportunity.Product__c;
        update user;
        TestData.updateUserRole(user, role.name);
        testOpportunity.Next_Follow_Up_Date__c = Date.Today();
        testOpportunity.OwnerId = user.Id;
        testOpportunity.Description = 'ApexTest';
        update testOpportunity; 
        return testOpportunity;
    }

    static Task_Dispatcher__c createTaskDispatcher() {
        Task_Dispatcher__c taskDispatcher = new Task_Dispatcher__c(Name = 'Follow-Up Task Dispatcher', 
            Task_Timeout__c = 5, 
            User_Role_ID__c = '00E2x000000cVXw,00E2x000000cXlE');
        insert taskDispatcher;
        List<Cadence_Task_Configuration__c> reports = new List<Cadence_Task_Configuration__c>();
        reports.add(new Cadence_Task_Configuration__c(Name = 'a1', Task_Dispatcher__c = taskDispatcher.Id, 
            Report_ID__c = '00O2x000002BCj4EAG', SLA__c = 1));
        insert reports;
        return taskDispatcher;
    }
}