public with sharing class QCJobProcessorBatch 
    implements Database.Batchable<sObject>, Database.AllowsCallouts, Schedulable {

    @TestVisible
    private class ProcessResult {
        public List<QC_Scorecard__c> scoreCards;
        public List<QC_Job__c> jobs;
        public List<QC_Rule_Result__c> ruleResults;
    }  

    private static final String QUERY = 
        'SELECT Id, Job_ID__c, QC_Record_Type__c, QC_Record_Id__c, State__c, Status__c ' +
        'FROM QC_Job__c ' + 
        'WHERE State__c NOT IN (\'failed\', \'succeeded\')';

    public void execute(SchedulableContext ctx) {
        QCJobProcessorBatch processor = new QCJobProcessorBatch();
        Database.executeBatch(processor, 5);
    }
    
    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator(QUERY);
    }

    public void finish(Database.BatchableContext bc) {
    }

    public void execute(Database.BatchableContext bc, List<sObject> qcJobs) {
        internalExecute(qcJobs);
    }

    private void internalExecute(List<sObject> qcJobs) {
        
        ProcessResult allResult = new ProcessResult();
        allResult.scoreCards = new List<QC_Scorecard__c>();
        allResult.jobs = new List<QC_Job__c>();
        allResult.ruleResults = new List<QC_Rule_Result__c>();

        ExternalService.QCBackend qcSvc = new ExternalService.QCBackend();
        IUtils utils = new Utils();

        for(sObject obj : qcJobs) {
            QC_Job__c job = (QC_Job__c)obj;
            ProcessResult res = processJob(job, qcSvc, utils);
            if(res != null) {
                if(res.scoreCards != null) {
                    allResult.scoreCards.addAll(res.scoreCards);
                }
                if(res.jobs != null) {
                    allResult.jobs.addAll(res.jobs);
                }                
                if(res.ruleResults != null) {
                    allResult.ruleResults.addAll(res.ruleResults);
                }
            }
        }

        if(!allResult.scoreCards.isEmpty()) {
            update allResult.scoreCards;
        }
        if(!allResult.jobs.isEmpty()) {
            update allResult.jobs;
        }
        if(!allResult.ruleResults.isEmpty()) {
            update allResult.ruleResults;
        }
    }

    @TestVisible
    private ProcessResult processJob(QC_Job__c job, ExternalService.QCBackend qcSvc, IUtils utils) {

        //If the job is completed and succeeded - seach for the
        // rule results that are indirectly (via QC Scorecard) linked with the Task being QCed
        // update their details (result and grader comment)
        // update QC Scorecard grader comment
        // NOTE: DB is not updated, result is returned in the DS

        ProcessResult res = new ProcessResult();
        res.jobs = new List<QC_Job__c>();
        res.scoreCards = new List<QC_Scorecard__c>();
        res.ruleResults = new List<QC_Rule_Result__c>();
        res.jobs.add(job);

        ExternalService.QCBackend.getQcjobByJobID_Request request = 
            new ExternalService.QCBackend.getQcjobByJobID_Request();
        request.jobID = job.Job_ID__c;

        ExternalService.QCBackend.getQcjobByJobID_Response qcResponse = qcSvc.getQcjobByJobID(request);

        if(qcResponse.code200.state_set) {
            job.State__c = qcResponse.code200.state;
        }
        if(qcResponse.code200.status_set) {
            job.Status__c = qcResponse.code200.status;
        }
        if(qcResponse.responseCode != 200 || 
                (qcResponse.code200.state != 'succeeded' && qcResponse.code200.state != 'failed')) {
            return res;
        }

        //find related QC_Scorecard__c
        QC_Scorecard__c qcCard = null;
        List<QC_Rule_Result__c> ruleResults = new List<QC_Rule_Result__c>();

        // find task
        List<Task> tasks = [SELECT Id, QC_Scorecard__c FROM Task WHERE Id = :job.QC_Record_Id__c LIMIT 1];


        if(!tasks.isEmpty()) {
            Task task = tasks[0];

            //attach files
            for (ExternalService.QCBackend_PromptInfo prompt : qcResponse.code200.prompts) {
                String fileName = 'QC Prompt for ' + task.Id + '-' + prompt.Category;
                utils.attachTxtFile2Rec(task.Id, fileName, prompt.PromptText);
            }

            //find scorecard
            List<QC_Scorecard__c> cards = [
                    SELECT Id, Grader_Comment__c 
                    FROM QC_Scorecard__c 
                    where Id = :task.QC_Scorecard__c];

            if(!cards.isEmpty()) {
                qcCard = cards[0];

                //update grader comment
                if(qcResponse.code200.result.GraderComment_set) {
                    qcCard.Grader_Comment__c = qcResponse.code200.result.GraderComment;
                    res.scoreCards.add(qcCard);
                }

                //find rule results linked to the card
                ruleResults = [
                    SELECT Id, QC_Rule__r.Name, QC_Scorecard__c, Result__c, Grader_Comment__c 
                    FROM QC_Rule_Result__c 
                    WHERE QC_Scorecard__c = :qcCard.Id
                ];
            }
        }

        //update SF's rule results
        if(qcResponse.code200.result.RuleResults_set) {
            res.ruleResults.addAll(updateLocalRuleResults(ruleResults, qcResponse.code200.result.RuleResults));
        }
        return res;
    }

    private List<QC_Rule_Result__c> updateLocalRuleResults(List<QC_Rule_Result__c> localRuleResults, 
                                                           List<ExternalService.QCBackend_RuleResult> backendRuleResults) {
        List<QC_Rule_Result__c> updatedRuleResults = new List<QC_Rule_Result__c>();
        for(ExternalService.QCBackend_RuleResult backendRuleResult : backendRuleResults) {
            for(QC_Rule_Result__c localRuleResult : localRuleResults) {
                if(localRuleResult.QC_Rule__r.Name == backendRuleResult.RuleName) {
                    localRuleResult.Result__c = backendRuleResult.Result;
                    localRuleResult.Grader_Comment__c = backendRuleResult.Reason;
                    updatedRuleResults.add(localRuleResult);
                }
            }
        }
        return updatedRuleResults;
    }
}