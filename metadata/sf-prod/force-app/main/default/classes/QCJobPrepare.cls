@TestVisible
public with sharing class QCJobPrepare {

    public class QCJobRequestWrapper {
        @InvocableVariable
        public ExternalService.QCBackend_QCJobRequest jobRequest;
    }    

    @InvocableMethod(label='Prep DS for QC Job' description='Prepares a data structure to QC a record')
    public static List<QCJobRequestWrapper> prepareJobDS(List<Id> recordIds) {
        PromptBuilder promptBuilder = new PromptBuilder(new IPromptBuilder.PromptRegistryImpl());
        return internalPrepareJobDS(recordIds, promptBuilder);
    }
    
    @TestVisible
    private static List<QCJobRequestWrapper> internalPrepareJobDS(List<Id> recordIds, IPromptBuilder promptBuilder) {
        List<QCJobRequestWrapper> jobRequestWrappers = new List<QCJobRequestWrapper>();
        for (Id recId : recordIds) {
            IPromptBuilder.QCJobDS qcJobDS = promptBuilder.prepareQCJobDS(recId);
            if (qcJobDS != null) {
                ExternalService.QCBackend_QCJobRequest jobRequest = mapQCJobDSToQCBackendQCJobRequest(qcJobDS);
                QCJobRequestWrapper wrapper = new QCJobRequestWrapper();
                wrapper.jobRequest = jobRequest;
                jobRequestWrappers.add(wrapper);
            }
        }
        return jobRequestWrappers;
    }

    private static ExternalService.QCBackend_QCJobRequest 
                            mapQCJobDSToQCBackendQCJobRequest(IPromptBuilder.QCJobDS ds) {
        ExternalService.QCBackend_QCJobRequest jobRequest = new ExternalService.QCBackend_QCJobRequest();
        jobRequest.promptPrefix = ds.promptPrefix;
        jobRequest.qcRules = new List<ExternalService.QCBackend_QCRule>();
        for (IPromptBuilder.QCRuleDS qcRuleDS : ds.qcRules) {
            ExternalService.QCBackend_QCRule qcRule = new ExternalService.QCBackend_QCRule();
            qcRule.category = qcRuleDS.category;
            qcRule.name = qcRuleDS.name;
            qcRule.context = qcRuleDS.context;
            qcRule.gradingCriteria = qcRuleDS.gradingCriteria;
            jobRequest.qcRules.add(qcRule);
        }
        jobRequest.workData = ds.workData;
        
        jobRequest.QCCategories = new List<ExternalService.QCBackend_QCCategory>();
        for (IPromptBuilder.QCCategoryDS qcCategoryDS : ds.qcCategories) {
            ExternalService.QCBackend_QCCategory category = new ExternalService.QCBackend_QCCategory();
            category.name = qcCategoryDS.name;
            category.prompt = qcCategoryDS.prompt;
            jobRequest.QCCategories.add(category);
        }
        return jobRequest;
    }
}