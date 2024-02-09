@IsTest
private class TaskDispatchSchedulerV2Test {
    @IsTest
    static void testExecute() {
        Test.startTest();
        TaskDispatchSchedulerV2 scheduler = new TaskDispatchSchedulerV2();
        String jobId = System.schedule('Test Job', '0 0 23 * * ?', scheduler);
        Test.stopTest();
        // Verify that the batch job was scheduled
        List<CronTrigger> cronTriggers = [SELECT Id, CronExpression, TimesTriggered, NextFireTime FROM CronTrigger WHERE Id = :jobId];
        System.assertEquals(1, cronTriggers.size());
        System.assertEquals('0 0 23 * * ?', cronTriggers[0].CronExpression);
    }
}