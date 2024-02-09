public with sharing abstract class IPromptBuilder {

    public static final String PLATINUM_OFFER_RULE_NAME = 'Platinum Discovery - Dynamic';
    private static final String QC_TASK_PROMPT_PREFIX_NAME = 'QC_Task_Prompt';
    private static final String QC_TASK_PLATINUM_OFFER_PROMPT_PREFIX_NAME = 'QC_Task_PlatinumOffer_Prompt';

    public interface IPromptRegistry {
        String getQCTaskPromptPrefix();
        String getQCTaskPlatinumOfferPromptPrefix();
    }

    public class PromptRegistryImpl implements IPromptRegistry {

        private String getPromptTextByDeveloperName(String developerName) {
            List<Prompt__mdt> prompts = [SELECT Id, Text__c FROM Prompt__mdt 
                                            WHERE DeveloperName = :developerName LIMIT 1];
            return prompts.isEmpty() ? null : prompts[0].Text__c;
        }

        public String getQCTaskPromptPrefix() {
            return getPromptTextByDeveloperName(QC_TASK_PROMPT_PREFIX_NAME);
        }

        public String getQCTaskPlatinumOfferPromptPrefix()  {
            return getPromptTextByDeveloperName(QC_TASK_PLATINUM_OFFER_PROMPT_PREFIX_NAME);
        }
    }

    public class NoTranscriptFoundException extends Exception {}    

    @TestVisible
    public class QCTaskPrompt {
        public String prompt;
        public Id scorecardId;
        public List<QC_Rule_Result__c> ruleResults;
    }

    public class QCRuleDS {
        public String category;
        public String name;
        public String context;
        public String gradingCriteria;
    }

    public class QCCategoryDS {
        public String name;
        public String prompt;
    }

    public class QCJobDS {
        public String promptPrefix;
        public List<QCRuleDS> qcRules;
        public List<QCCategoryDS> qcCategories;
        public String workData;
    }

    public class QCTaskPlatinumOfferPrompt {
        public String[] prompts;
        public QC_Rule_Result__c ruleResult;
    }
    public abstract QCJobDS prepareQCJobDS(Id recordId);
    public abstract QCTaskPrompt prepareQcTaskPrompt(Id taskId);
    public abstract QCTaskPlatinumOfferPrompt preparePromptsToQcPlatinumOffers(Id taskId);
}