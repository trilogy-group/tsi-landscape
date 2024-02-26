@isTest
private class QCJobProcessorBatchTests {

    private static final String UNIQUE_JOB_ID_1 = 'unique-job-id-1';
    private static final String UNIQUE_JOB_ID_2 = 'unique-job-id-2';

    public class QCBackendMock_200 implements HttpCalloutMock {
        String id1;
        String id2;

        public QCBackendMock_200(String id1, String id2) {
            this.id1 = id1;
            this.id2 = id2;
        }

        public HTTPResponse respond(HTTPRequest req) {

            // Verify that no DML operations have been performed
            if (Limits.getDMLStatements() > 0) {
                String msg = 'QCBackendMock_200: DML operation detected before mock callout response.';
                CalloutException e = (CalloutException)CalloutException.class.newInstance();
                e.setMessage(msg);
                System.debug(msg);
                throw e; 
            }

            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
    
            if(req.getEndpoint().endsWith('/qcjob') && req.getMethod() == 'POST') {
                // Simulate response for creating a QC job
                res.setBody('{"jobID": "unique-job-id"}');
            } else if(req.getEndpoint().contains('/qcjob/') && req.getMethod() == 'GET') {
                String responseBody = '';
                if(req.getEndpoint().contains(id1)) {
                    // Simulate response for checking a QC job result
                    responseBody = '{"jobID": "' + id1 + '", "state": "succeeded",'
                        + '"status": "completed", "prompts": ['
                        + '{"Category": "Category 1", "PromptText": "Prompt 1"},'
                        + '{"Category": "Category 2", "PromptText": "Prompt 2"}],'
                        + '"result": {"GraderComment": "Excellent",' 
                        + '"RuleResults": [ {"RuleName": "Rule1", "Result": "Pass", "Reason": "Met criteria 1"},'
                        + '{"RuleName": "Rule2", "Result": "Pass", "Reason": "Met criteria 2"}]}}';
                } else if(req.getEndpoint().contains(id2)){
                    responseBody = '{"jobID": "' + id2 + '", "state": "succeeded",'
                        + '"status": "completed", "prompts": ['
                        + '{"Category": "Category 1", "PromptText": "Prompt 1"},'
                        + '{"Category": "Category 2", "PromptText": "Prompt 2"},'
                        + '{"Category": "Category 3", "PromptText": "Prompt 3"}],'
                        + '"result": {"GraderComment": "Excellent",' 
                        + '"RuleResults": [ {"RuleName": "Rule1", "Result": "Pass", "Reason": "Met criteria 1"},'
                        + '{"RuleName": "Rule2", "Result": "Pass", "Reason": "Met criteria 2"}]}}';
                } else {
                    String msg = 'QCBackendMock_200: Unexpected callout request: ' + req.getEndpoint();
                    CalloutException e = (CalloutException)CalloutException.class.newInstance();
                    e.setMessage(msg);
                    System.debug(msg);
                    throw e; 
                }
                res.setBody(responseBody);
            }
            return res;
        }
    }

    @isTest
    static void testBatchExecutionWithNoJobs() {
        Test.startTest();
        QCJobProcessorBatch batch = new QCJobProcessorBatch();
        Database.executeBatch(batch);
        Test.stopTest();
        
        // Assert no jobs are processed
        System.assertEquals(0, [SELECT Count() FROM QC_Job__c WHERE State__c IN ('failed', 'succeeded')]);
    }

    static List<QC_Rule__c> createQCRules() {
        // Create QC Rules
        QC_Rule__c r1 = new QC_Rule__c(Name = 'Rule1', 
                Context__c = 'Task', 
                Grading_Criteria__c = 'Grammar must be correct',
                Grader_Type__c = 'AutoAI', 
                Enforced_On__c = 'Renewal Call',
                Enforced__c = True);
        QC_Rule__c r2 = new QC_Rule__c(Name = 'Rule2', 
                Context__c = 'Task', 
                Grading_Criteria__c = 'No spelling errors allowed',
                Grader_Type__c = 'AutoAI', 
                Enforced_On__c = 'Renewal Call',
                Enforced__c = True);

        insert r1;
        insert r2;
        return new List<QC_Rule__c>{r1, r2};
    }

    static Task createTaskAndQCRecords(String taskSubject, List<QC_Rule__c> qcRules, String jobId) {
        QC_Summary__c testSummary = new QC_Summary__c(Name = taskSubject);
        insert testSummary;

        // Create a mock QC_Scorecard__c record
        QC_Scorecard__c testScorecard = new QC_Scorecard__c(QC_Summary__c = testSummary.Id);
        insert testScorecard;

        // Setup test data
        Task testTask = new Task(Subject = taskSubject, QC_Scorecard__c = testScorecard.Id);
        insert testTask;

        // Create related QC_Rule_Results
        List<QC_Rule_Result__c> qcRuleResults = new List<QC_Rule_Result__c>{
            new QC_Rule_Result__c(QC_Rule__c = qcRules[0].Id, QC_Scorecard__c = testScorecard.Id),
            new QC_Rule_Result__c(QC_Rule__c = qcRules[1].Id, QC_Scorecard__c = testScorecard.Id)
        };
        insert qcRuleResults;
    
        QC_Job__c job = new QC_Job__c(
            Job_ID__c = jobId,
            State__c = 'pending',
            Status__c = 'new',
            QC_Record_Type__c = 'Task',
            QC_Record_Id__c = testTask.Id
        );
        insert job;

        return testTask;
    }

    @isTest
    static void shouldProcessJobsAndAttachPromptsAsFilesToTask() {

        //checking happy path

        String id1 = UNIQUE_JOB_ID_1;
        String id2 = UNIQUE_JOB_ID_2;

        List<QC_Rule__c> qcRules = createQCRules();
        Task testTask1 = createTaskAndQCRecords('Test Task 1', qcRules, id1);
        Task testTask2 = createTaskAndQCRecords('Test Task 2', qcRules, id2);

        // Set mock callout
        Test.setMock(HttpCalloutMock.class, new QCBackendMock_200(id1, id2));
    
        Test.startTest();
        QCJobProcessorBatch batch = new QCJobProcessorBatch();
        Database.executeBatch(batch);
        Test.stopTest();
    
        // Query for the attached files (ContentDocumentLink) related to the Task
        List<ContentDocumentLink> attachedFiles1 = [
            SELECT ContentDocumentId, LinkedEntityId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :testTask1.Id
        ];
    
        List<ContentDocumentLink> attachedFiles2 = [
            SELECT ContentDocumentId, LinkedEntityId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :testTask2.Id
        ];

        // Assert that prompts are attached as files to the Task
        Assert.areEqual(2, attachedFiles1.size(), 'There must be two prompts attached to the task');
        Assert.areEqual(3, attachedFiles2.size(), 'There must be two prompts attached to the task');

        // Assert jobs are processed
        for (QC_Job__c job : [SELECT State__c, Status__c FROM QC_Job__c]) {
            System.assert(job.State__c == 'failed' || job.State__c == 'succeeded');
        }        
    }

    @isTest
    static void shouldNotBreakIfTwoQCJobForTheSameTask() {

        String id1 = UNIQUE_JOB_ID_1;
        String id2 = UNIQUE_JOB_ID_2;

        List<QC_Rule__c> qcRules = createQCRules();
        Task testTask1 = createTaskAndQCRecords('Test Task 1', qcRules, id1);
        createTaskAndQCRecords('Test Task 2', qcRules, id2);

        //Make both jobs for the same task
        QC_Job__c job = [SELECT Id, Job_ID__c  
                                 FROM QC_Job__c 
                                 WHERE Job_ID__c = :id2 LIMIT 1];
        job.QC_Record_Id__c = testTask1.Id;
        update job;
    
        // Set mock callout
        Test.setMock(HttpCalloutMock.class, new QCBackendMock_200(id1, id2));
    
        Boolean exceptionThrown = false;

        try {
            Test.startTest();
            QCJobProcessorBatch batch = new QCJobProcessorBatch();
            Database.executeBatch(batch);
            Test.stopTest();
        } catch (Exception e) {
            exceptionThrown = true;
        }

        //no exception should be thrown
        Assert.areEqual(false, exceptionThrown, 'No exception should be thrown when two jobs are for the same task');

    }    
}