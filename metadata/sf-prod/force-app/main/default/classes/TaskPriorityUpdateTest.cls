@isTest
public with sharing class TaskPriorityUpdateTest {
    @isTest static void testTaskPriorityUpdate() {
        // Create test data
        List<Task> tasks = new List<Task>();
        for (Integer i = 0; i < 10; i++) {
            tasks.add(new Task(
                Subject = 'Validate Opportunity',
                Status = 'Open',
                Priority = 'Normal',
                One_Day_Expire__c = true
            ));
        }

        insert tasks;
        // Get the formula field from DB
        tasks = [SELECT Id, Priority, SLA_Based_Priority__c FROM Task WHERE Id IN :tasks];

        // Test scheduler execution
        Test.startTest();
        
        TaskPriorityUpdate batch = new TaskPriorityUpdate(); 
        batch.execute(null, tasks);
        
        Test.stopTest();

        // Verify the results
        List<Task> updatedTasks = [SELECT Id, Priority FROM Task WHERE Id IN :tasks];
        for (Task t : updatedTasks) {
            System.assertNotEquals('Normal', t.Priority);
        }
    }

    @isTest static void testTaskPriorityUpdateScheduler() {
        // Test scheduler execution
        // Since it is a schedule batch the standard Salesforce approach does not work
        Test.startTest();
        
        TaskPriorityUpdate scheduler = new TaskPriorityUpdate();
        String jobId = System.schedule('Task Priority Update Job Test', '0 0 0/6 * * ?', scheduler);

        // Run the scheduled batch job
        CronTrigger ct = [SELECT Id, CronExpression, TimesTriggered, NextFireTime FROM CronTrigger WHERE id = :jobId];
        System.assertEquals(0, ct.TimesTriggered);
        Test.stopTest();

        // Clean up
        System.abortJob(jobId);
    }
}