@isTest
private class TaskDispatchReportServiceTest {
    @isTest static void reportShouldBeSentInTime(){
        configureTest();
        ITaskDispatchReportService tdrService = Injector.getInstance().getTaskDispatchReportService();
        //configuration to send report now
        tdrService.configure(System.now().hourGmt(),80);
        arrange(tdrService);
        
        tdrService.sendReport();
        Integer invocations = Limits.getEmailInvocations();
        System.assertNotEquals(0, invocations, 'At least one email should be sent');
    }

    @isTest static void noReportSentWhenNotRightTime(){
        configureTest();
        ITaskDispatchReportService tdrService = Injector.getInstance().getTaskDispatchReportService();
        //configuration to send report in the following next hour
        tdrService.configure(System.now().hourGmt() + 2,20);
        arrange(tdrService);
        
        tdrService.sendReport();
        Integer invocations = Limits.getEmailInvocations();
        System.assertEquals(0, invocations, 'An email should not be sent');
    }

    @isTest static void reportShouldBeSentWhenUsingTaskDispatchReportServiceMock(){
        configureTest();
        Injector.getInstance().setConfig(Injector.TaskDispatchReportServiceName,'TaskDispatchReportServiceMock');
        ITaskDispatchReportService tdrService = Injector.getInstance().getTaskDispatchReportService();
        //configured no time
        tdrService.configure(0,0);
        arrange(tdrService);
        
        tdrService.sendReport();
        Integer invocations = Limits.getEmailInvocations();
        System.assertNotEquals(0, invocations, 'At least one email should be sent');
    }

    private static void arrange(ITaskDispatchReportService tdrService) {
        Id tdId = Id.valueOf('000000000000001');
        tdrService.addTaskDispatch(tdId, 'Task Dispatch Test');
        Id brId = Id.valueOf('000000000000002');
        tdrService.addBacklogReport(tdId, brId, 'Backlog Report Test');
        Id aId = Id.valueOf('000000000000003');
        tdrService.addAssignee(tdId, brId, aId);
        tdrService.addValueToAssignee(tdId, brId, aId, 'total', 10);
        tdrService.addValueToAssignee(tdId, brId, aId, 'ignored', 5);
    }

    private static void configureTest() {
        Injector.getInstance().useDefaultConfig();
        // sendReport method send to apex exception emails, in sandbox this normally is empty
        // using testconfig, we are getting one email address to send
        // Emails in unit tests are not actually sent
        Boolean isSandbox = [SELECT IsSandbox FROM Organization LIMIT 1].IsSandbox;
        if (isSandbox) {
            Injector.getInstance().setConfig(Injector.EmailServiceName,'EmailServiceMock');
        }
    }
}