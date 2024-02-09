@isTest
private class QCJobProcessorBatchTests {

    public class QCBackendMock_200 implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
    
            if(req.getEndpoint().endsWith('/qcjob') && req.getMethod() == 'POST') {
                // Simulate response for creating a QC job
                res.setBody('{"jobID": "unique-job-id"}');
            } else if(req.getEndpoint().contains('/qcjob/') && req.getMethod() == 'GET') {
                // Simulate response for checking a QC job result
                String responseBody = '{"jobID": "unique-job-id", "state": "succeeded",'
                    + '"status": "completed", "prompts": ['
                    + '{"Category": "Category 1", "PromptText": "Prompt 1"},'
                    + '{"Category": "Category 2", "PromptText": "Prompt 2"}],'
                    + '"result": {"GraderComment": "Excellent",' 
                    + '"RuleResults": [ {"RuleName": "Rule1", "Result": "Pass", "Reason": "Met criteria 1"},'
                    + '{"RuleName": "Rule2", "Result": "Pass", "Reason": "Met criteria 2"}]}}';
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

    @isTest
    static void testBatchExecutionWithJobs() {
        // Setup test data
        List<QC_Job__c> jobs = new List<QC_Job__c>{
            new QC_Job__c(Job_ID__c = 'Job1', State__c = 'pending', Status__c = 'new', 
                    QC_Record_Type__c = 'Task', QC_Record_Id__c = '12345'),
            new QC_Job__c(Job_ID__c = 'Job2', State__c = 'in_progress', Status__c = 'running', 
                    QC_Record_Type__c = 'Task', QC_Record_Id__c = '54321')
        };
        insert jobs;

        // Set mock callout
        Test.setMock(HttpCalloutMock.class, new QCBackendMock_200());

        Test.startTest();
        QCJobProcessorBatch batch = new QCJobProcessorBatch();
        Database.executeBatch(batch);
        Test.stopTest();

        // Assert jobs are processed
        for (QC_Job__c job : [SELECT State__c, Status__c FROM QC_Job__c]) {
            System.assert(job.State__c == 'failed' || job.State__c == 'succeeded');
        }
    }

    @isTest
    static void ShouldAttachPromptsAsFilesToTask() {
      
        QC_Summary__c testSummary = new QC_Summary__c(Name = 'ExampleSummary');
        insert testSummary;

        // Create a mock QC_Scorecard__c record
        QC_Scorecard__c testScorecard = new QC_Scorecard__c(QC_Summary__c = testSummary.Id);
        insert testScorecard;

        // Setup test data
        Task testTask = new Task(Subject = 'Test Task', QC_Scorecard__c = testScorecard.Id);
        insert testTask;

        // Create QC Rules
        List<QC_Rule__c> qcRules = new List<QC_Rule__c>{
            new QC_Rule__c(Name = 'Rule1', 
                Context__c = 'Task', 
                Grading_Criteria__c = 'Grammar must be correct',
                Grader_Type__c = 'AutoAI', 
                Enforced_On__c = 'Renewal Call',
                Enforced__c = True),
            new QC_Rule__c(Name = 'Rule2', 
                Context__c = 'Task', 
                Grading_Criteria__c = 'No spelling errors allowed',
                Grader_Type__c = 'AutoAI', 
                Enforced_On__c = 'Renewal Call',
                Enforced__c = True)
        };
        insert qcRules;

        // Create related QC_Rule_Results
        List<QC_Rule_Result__c> qcRuleResults = new List<QC_Rule_Result__c>{
            new QC_Rule_Result__c(QC_Rule__c = qcRules[0].Id, QC_Scorecard__c = testScorecard.Id),
            new QC_Rule_Result__c(QC_Rule__c = qcRules[1].Id, QC_Scorecard__c = testScorecard.Id)
        };
        insert qcRuleResults;

    
        QC_Job__c job = new QC_Job__c(
            Job_ID__c = 'unique-job-id',
            State__c = 'pending',
            Status__c = 'new',
            QC_Record_Type__c = 'Task',
            QC_Record_Id__c = testTask.Id
        );
        insert job;
    
        // Set mock callout
        Test.setMock(HttpCalloutMock.class, new QCBackendMock_200());
    
        Test.startTest();
        QCJobProcessorBatch batch = new QCJobProcessorBatch();
        Database.executeBatch(batch);
        Test.stopTest();
    
        // Query for the attached files (ContentDocumentLink) related to the Task
        List<ContentDocumentLink> attachedFiles = [
            SELECT ContentDocumentId, LinkedEntityId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :testTask.Id
        ];
    
        // Assert that prompts are attached as files to the Task
        Assert.areEqual(2, attachedFiles.size(), 'There must be two prompts attached to the task');
    }
}