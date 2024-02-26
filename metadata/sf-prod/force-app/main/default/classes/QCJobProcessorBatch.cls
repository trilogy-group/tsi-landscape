public with sharing class QCJobProcessorBatch 
    implements Database.Batchable<sObject>, Database.AllowsCallouts, Schedulable {

    private class AttachmentInfo {
        public String taskId;
        public String fileName;
        public String fileContent;
    }

    @TestVisible
    private inherited sharing class ProcessResult {
        public List<QC_Scorecard__c> scoreCards;
        public List<QC_Job__c> jobs;
        public List<QC_Rule_Result__c> ruleResults;
        public List<AttachmentInfo> attachments;

        public ProcessResult () {
            scoreCards = new List<QC_Scorecard__c>();
            jobs = new List<QC_Job__c>();
            ruleResults = new List<QC_Rule_Result__c>();
            attachments = new List<AttachmentInfo>();
        }

        public void cacheResult(QC_Job__c job) {
            jobs.add(job);
        }

        public void cacheResult(ProcessResult res) {
            if(res.scoreCards != null) {
                scoreCards.addAll(res.scoreCards);
            }
            if(res.jobs != null) {
                jobs.addAll(res.jobs);
            }                
            if(res.ruleResults != null) {
                ruleResults.addAll(res.ruleResults);
            }
            if(res.attachments != null) {
                attachments.addAll(res.attachments);
            }
        }

        public void persistResult() {
            if(!scoreCards.isEmpty()) {
                update scoreCards;
            }
            if(!jobs.isEmpty()) {
                update jobs;
            }
            if(!ruleResults.isEmpty()) {
                update ruleResults;
            }
            if(!attachments.isEmpty()) {
                IUtils utils = new Utils();
                for(AttachmentInfo attInfo : attachments) {
                    utils.attachTxtFile2Rec(attInfo.taskId, attInfo.fileName, attInfo.fileContent);
                }
            }            
        }

        public QC_Job__c findJobByQcRecordId(String recordId) {
            for(QC_Job__c job : jobs) {
                if(job.QC_Record_Id__c == recordId) {
                    return job;
                }
            }
            return null;
        }
    }

    private static final String QUERY = 
        'SELECT Id, Job_ID__c, QC_Record_Type__c, QC_Record_Id__c, State__c, Status__c ' +
        'FROM QC_Job__c ' + 
        'WHERE State__c NOT IN (\'failed\', \'succeeded\') ' + 
        'ORDER by CreatedDate desc';

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
        ExternalService.QCBackend qcSvc = new ExternalService.QCBackend();
        for(sObject obj : qcJobs) {
            QC_Job__c job = (QC_Job__c)obj;
            //check if the same record already QCed in the same batch (e.g. QC job executed twice for the same task)
            // if yes: take result from the already processed job
            // otherwise: process response
            QC_Job__c completedJob = allResult.findJobByQcRecordId(job.QC_Record_Id__c);
            if(completedJob != null) {
                job.State__c = completedJob.State__c;
                job.Status__c = completedJob.Status__c;
                allResult.cacheResult(job);
            } else {
                ProcessResult res = processJob(job, qcSvc);
                if(res != null) {
                    allResult.cacheResult(res);
                }
            }
        }
        allResult.persistResult();
    }

    @TestVisible
    private ProcessResult processJob(QC_Job__c job, ExternalService.QCBackend qcSvc) {

        //If the job is completed and succeeded - seach for the
        // rule results that are indirectly (via QC Scorecard) linked with the Task being QCed
        // update their details (result and grader comment)
        // update QC Scorecard grader comment
        // NOTE: DB is not updated, result is returned in the DS

        ProcessResult res = new ProcessResult();
        res.jobs = new List<QC_Job__c>();
        res.scoreCards = new List<QC_Scorecard__c>();
        res.ruleResults = new List<QC_Rule_Result__c>();
        res.attachments = new List<AttachmentInfo>();
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

        System.debug('Process response from QC Server');
        if(!tasks.isEmpty()) {
            Task task = tasks[0];

            //attach files
            for (ExternalService.QCBackend_PromptInfo prompt : qcResponse.code200.prompts) {
                String fileName = 'QC Prompt for ' + task.Id + '-' + prompt.Category;
                AttachmentInfo attInfo = new AttachmentInfo();
                attInfo.taskId = task.Id;
                attInfo.fileName = fileName;
                attInfo.fileContent = prompt.PromptText;
                res.attachments.add(attInfo);
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