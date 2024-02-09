@TestVisible
public with sharing class QCTask {

    @TestVisible
    private class QCRuleResult {
        public String RuleName;
        public String Result;
        public String Reason;
    }

    @TestVisible
    private class QCScorecard {
        public List<QCRuleResult> ruleResults;
        public String GraderComment;
    }
    
    @InvocableMethod(label='QC a Task' description='Performs a quality check for a given task')
    public static void executeQualityCheck(List<Id> taskIds) {

        PromptBuilder promptBuilder = new PromptBuilder(new IPromptBuilder.PromptRegistryImpl());
        IUtils utils = new Utils();
        IAgent agent = new AgentOAI();

        QCTask qcer = new QCTask(promptBuilder, utils, agent);
        qcer.qcTasks(taskIds);
    }

    private IPromptBuilder m_promptBuilder;
    private IUtils m_utils;
    private IAgent m_agent;

    public QCTask(IPromptBuilder promptBuilder, IUtils utils, IAgent agent) {
        this.m_promptBuilder = promptBuilder;
        this.m_utils = utils;
        this.m_agent = agent;
    }

    public void qcTasks(List<Id> taskIds) {
        for (Id taskId : taskIds) {
            try {
                qcTaskSingle(taskId);
            } catch (Exception e) {
                m_utils.attachTxtFile2Rec(taskId, 'QC Task Exception ' + taskId, e.getMessage());
            }
        }
    }

    static final string FORMAT_DATETIME = 'yyyy-MM-dd\'T\'HH:mm:ss';
    private void qcTaskSingle(Id taskId) {

        IPromptBuilder.QCTaskPlatinumOfferPrompt qcPlatinumOfferPrompt = null;
        QCScorecard simpleRulesResult = null;
        IPromptBuilder.QCTaskPrompt qcPrompt = null;
        Exception excpt = null;
        List<String> logEntries = new List<String>();
        logEntries.add(Datetime.now().format(FORMAT_DATETIME) + ': QC Started for ' + taskId);
        try {
            qcPrompt = m_promptBuilder.prepareQcTaskPrompt(taskId);
            if(qcPrompt != null) {
                simpleRulesResult = (QCScorecard)m_agent.runPrompt(qcPrompt.prompt, QCScorecard.class);
            }
            logEntries.add(Datetime.now().format(FORMAT_DATETIME) + 
                            ': QC completed for plain rules, task Id = ' + taskId);


            qcPlatinumOfferPrompt = m_promptBuilder.preparePromptsToQcPlatinumOffers(taskId);
            if(qcPlatinumOfferPrompt != null) {

                String combinedReason = '';
                String finalResult = 'Pass';
                Integer promptIndex = 0;
                Integer totalPrompts = qcPlatinumOfferPrompt.prompts.size();
                for (String prompt : qcPlatinumOfferPrompt.prompts) {

                    promptIndex++;
                    logEntries.add(Datetime.now().format(FORMAT_DATETIME) + 
                                    ': Running prompt for platinum offer ' + promptIndex + '/' + totalPrompts);

                    QCRuleResult individualResult = (QCRuleResult)m_agent.runPrompt(prompt, QCRuleResult.class);

                    logEntries.add(Datetime.now().format(FORMAT_DATETIME) + 
                                    ': Platinum offer prompt finished ' + promptIndex + '/' + totalPrompts);

                    combinedReason += individualResult.RuleName + ' / ' + individualResult.Result + '\n'
                                         + individualResult.Reason + '\n\n';
                    if (individualResult.Result == 'Fail') {
                        finalResult = 'Fail';
                    }
                }

                qcPlatinumOfferPrompt.ruleResult.Result__c = finalResult;
                qcPlatinumOfferPrompt.ruleResult.Grader_Comment__c = combinedReason.trim();
                update new List<QC_Rule_Result__c> { qcPlatinumOfferPrompt.ruleResult };
            }
        } catch (Exception e) {
            excpt = e;
            logEntries.add(Datetime.now().format(FORMAT_DATETIME) + ': Exception occurred - ' + e.getMessage());
            excpt.setMessage(String.join(logEntries, '\n'));
        }
        // save assets and re-throw the exception
        if(qcPlatinumOfferPrompt != null) {
            for (String prompt : qcPlatinumOfferPrompt.prompts) {
                m_utils.attachTxtFile2Rec(taskId, 'QC Platinum Offer Prompt for ' + taskId, prompt);
            }
        }
        if(qcPrompt != null) {
            m_utils.attachTxtFile2Rec(taskId, 'QC Prompt for ' + taskId, qcPrompt.prompt);
        }
        if(simpleRulesResult != null) {
            updateRuleResults(qcPrompt.ruleResults, simpleRulesResult.ruleResults);

            // Update the scorecard
            QC_Scorecard__c card = new QC_Scorecard__c();
            card.Id = qcPrompt.scorecardId;
            card.Grader_Comment__c = simpleRulesResult.GraderComment;
            update card;
        }

        if(excpt != null)
            throw excpt;
    }

    private void updateRuleResults(List<QC_Rule_Result__c> ruleResults, List<QCRuleResult> results) {
        List<QC_Rule_Result__c> ruleResultsToUpdate = new List<QC_Rule_Result__c>();
        for (QC_Rule_Result__c ruleResult : ruleResults) {
            for (QCRuleResult result : results) {
                if (ruleResult.QC_Rule__r.Name == result.RuleName) {
                    QC_Rule_Result__c r = new QC_Rule_Result__c();
                    r.Id = ruleResult.Id;
                    r.Result__c = result.Result;
                    r.Grader_Comment__c = result.Reason;
                    ruleResultsToUpdate.add(r);
                    break;
                }
            }
        }
        if (!ruleResultsToUpdate.isEmpty()) {
            update ruleResultsToUpdate;
        }
    }
}