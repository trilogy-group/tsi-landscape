public with sharing class PromptBuilder extends IPromptBuilder {
    private static final String NO_RULES_TO_QC_FOUND = 'PromptBuilder.cls: No rules to QC found';
    private static final String NO_TRANSCRIPT_FOUND = 'PromptBuilder.cls: No transcript found for task: ';

    @TestVisible
    private class DataRecord {
        public String prefixName;
        public Id recordId;
        public Object value;

        public DataRecord(String prefixName, Id recordId, Object value) {
            this.prefixName = prefixName;
            this.recordId = recordId;
            this.value = value;
        }
        public DataRecord(String prefixName, Id recordId) {
            this.prefixName = prefixName;
            this.recordId = recordId;
            this.value = null;
        }
    }

    private IPromptRegistry m_promptRegistry;
    public PromptBuilder(IPromptRegistry promptRegistry) {
        this.m_promptRegistry = promptRegistry;
    }

    @TestVisible
    //prepares data for placeholders replacement
    private static List<PromptBuilder.DataRecord> prepareDataRecords(Id taskId, Id platinumOfferId) {
        Task task = [SELECT WhatId, What.Type, WhoId, Who.Type FROM Task WHERE Id = :taskId LIMIT 1];

        List<PromptBuilder.DataRecord> dataRecords = new List<PromptBuilder.DataRecord> {
            new PromptBuilder.DataRecord('Record', taskId)
        };
        if(task.Who.Type != null) {
            dataRecords.add(new PromptBuilder.DataRecord(task.Who.Type, task.WhoId));
        }
        if(task.What.Type != null) {
            dataRecords.add(new PromptBuilder.DataRecord(task.What.Type, task.WhatId));
        }

        //special handling for the Platinum Offers
        if(platinumOfferId != null) {
            dataRecords.add(new PromptBuilder.DataRecord('Platinum_Offer_Item__c', platinumOfferId));
        } else {
            List<Id> platinumOfferIds = getPlatinumOfferIDs(taskId);
            if(!platinumOfferIds.isEmpty()) {
                Map<String, Object> valueMap = new Map<String, Object>{
                    '$Custom' => new Map<String, Object>{'Platinum_Offer_Item__r' => platinumOfferIds}
                };
                dataRecords.add(new PromptBuilder.DataRecord('$Custom', null, valueMap));
            }
        }
        return dataRecords;
    }

    public override IPromptBuilder.QCJobDS prepareQCJobDS(Id recordId) {
        IPromptBuilder.QCJobDS ds = new IPromptBuilder.QCJobDS();
        ds.promptPrefix = m_promptRegistry.getQCTaskPromptPrefix();
        
        List<QC_Rule_Result__c> ruleResults = getRuleResultsForTask(recordId);
        if (ruleResults.isEmpty()) {
            System.debug(NO_RULES_TO_QC_FOUND);
            return null;
        }

        //prepare placeholder data records
        List<PromptBuilder.DataRecord> dataRecords = prepareDataRecords(recordId, null);

        ds.QCRules = new List<IPromptBuilder.QCRuleDS>();
        for (QC_Rule_Result__c ruleResult : ruleResults) {
            IPromptBuilder.QCRuleDS qcRule = new IPromptBuilder.QCRuleDS();
            qcRule.category = ruleResult.QC_Rule__r.Category__r.Name;
            qcRule.name = ruleResult.QC_Rule__r.Name;
            qcRule.context = PromptBuilder.replacePlaceholders(dataRecords, ruleResult.QC_Rule__r.Context__c);
            qcRule.gradingCriteria = 
                PromptBuilder.replacePlaceholders(dataRecords, ruleResult.QC_Rule__r.Grading_Criteria__c);
            ds.QCRules.add(qcRule);
        }
        
        String transcript = getTranscriptForTask(recordId);
        if (transcript == null) {
            String msg = NO_TRANSCRIPT_FOUND + recordId;
            throw new IPromptBuilder.NoTranscriptFoundException(msg);
        }
        ds.workData = transcript;
        ds.qcCategories = getQCCategories();
        return ds;
    }

    private List<IPromptBuilder.QCCategoryDS> getQCCategories() {
        List<QC_Rule_Category__c> categories = [SELECT Id, Name, Prompt__c FROM  QC_Rule_Category__c];
        List<IPromptBuilder.QCCategoryDS> qcCategories = new List<IPromptBuilder.QCCategoryDS>();
        for (QC_Rule_Category__c category : categories) {
            IPromptBuilder.QCCategoryDS qcCategoryDS = new IPromptBuilder.QCCategoryDS();
            qcCategoryDS.name = category.Name;
            qcCategoryDS.prompt = category.Prompt__c;
            qcCategories.add(qcCategoryDS);
        }
        return qcCategories;
    }

    public override IPromptBuilder.QCTaskPrompt prepareQcTaskPrompt(Id taskId) {

        String qcPrompt = m_promptRegistry.getQCTaskPromptPrefix() + '\n';

        List<QC_Rule_Result__c> ruleResults = getRuleResultsForTask(taskId);
        if (!ruleResults.isEmpty()) {
            System.debug('PromptBuilder.cls: Number of rules to QC: ' + ruleResults.size());
        } else {
            System.debug(NO_RULES_TO_QC_FOUND);
            return null;
        }

        for (QC_Rule_Result__c ruleResult : ruleResults) {
            //ignore the platinum offer rule, there will be a separate prompt for that
            if (ruleResult.QC_Rule__r.Name.contains(IPromptBuilder.PLATINUM_OFFER_RULE_NAME)) {
                continue;
            }
            qcPrompt += '\n\nRule Name: ' + ruleResult.QC_Rule__r.Name;
            if(String.isNotBlank(ruleResult.QC_Rule__r.Context__c)) {
                qcPrompt += '\nContext: ' + ruleResult.QC_Rule__r.Context__c;
            }
            qcPrompt += '\nGrading Criteria: ' + ruleResult.QC_Rule__r.Grading_Criteria__c;
        }

        String transcript = getTranscriptForTask(taskId);
        if(transcript == null) {
            String msg = NO_TRANSCRIPT_FOUND + taskId;
            throw new IPromptBuilder.NoTranscriptFoundException(msg);
        }

        //prepare placeholder data records and do the replacement
        List<PromptBuilder.DataRecord> dataRecords = prepareDataRecords(taskId, null);
        qcPrompt = PromptBuilder.replacePlaceholders(dataRecords, qcPrompt);

        //add transcript
        qcPrompt += '\n\n=== TRANSCRIPT===\n' + transcript;

        //prepare result
        IPromptBuilder.QCTaskPrompt qcPromptRes = new IPromptBuilder.QCTaskPrompt();
        qcPromptRes.scorecardId = ruleResults[0].QC_Scorecard__c;
        qcPromptRes.prompt = qcPrompt;
        qcPromptRes.ruleResults = ruleResults;
        return qcPromptRes;
    }

    public override IPromptBuilder.QCTaskPlatinumOfferPrompt preparePromptsToQcPlatinumOffers(Id taskId) {
        String qcPrefix = m_promptRegistry.getQCTaskPlatinumOfferPromptPrefix() + '\n';

        String transcript = getTranscriptForTask(taskId);
        if(transcript == null) {
            String msg = NO_TRANSCRIPT_FOUND + taskId;
            throw new IPromptBuilder.NoTranscriptFoundException(msg);
        }

        List<QC_Rule_Result__c> ruleResults = getRuleResultsForTask(taskId);
        if (!ruleResults.isEmpty()) {
            System.debug('PromptBuilder.cls: Number of rules to QC: ' + ruleResults.size());
        } else {
            System.debug(NO_RULES_TO_QC_FOUND);
            return null;
        }

        IPromptBuilder.QCTaskPlatinumOfferPrompt qcPromptRes = new IPromptBuilder.QCTaskPlatinumOfferPrompt();
        qcPromptRes.prompts = new List<String>();

        String promptTemplate = null;
        for (QC_Rule_Result__c ruleResult : ruleResults) {
            //search for the platinum discovery rule
            if (ruleResult.QC_Rule__r.Name.contains(IPromptBuilder.PLATINUM_OFFER_RULE_NAME)) {
                promptTemplate = '';
                if(String.isNotBlank(ruleResult.QC_Rule__r.Context__c)) {
                    promptTemplate += '\nContext: ' + ruleResult.QC_Rule__r.Context__c;
                }
                promptTemplate += '\nGrading Criteria: ' + ruleResult.QC_Rule__r.Grading_Criteria__c;
                qcPromptRes.ruleResult = ruleResult;
                break;
            }
        }

        if(promptTemplate == null) {
            System.debug('PromptBuilder.cls: there is no rule for platinum offer discovery');
            return null;
        }

        List<String> offerPrompts = replacePlatinumOfferRulePlaceholders(taskId, promptTemplate);
        if(offerPrompts.isEmpty()) {
            System.debug('PromptBuilder.cls: there are no offer items for the task (or no opp?) ' + taskId);
            return null;
        }

        for (String prompt : offerPrompts) {
            qcPromptRes.prompts.add(qcPrefix + prompt + '\n\n=== TRANSCRIPT===\n' + transcript);
        }
        return qcPromptRes;
    }

    @TestVisible
    private static string replacePlaceholders(List<DataRecord> dataRecords, String template) {
        Pattern placeholderPattern = Pattern.compile('\\$\\{([^}]+)\\}');
        Set<String> uniquePlaceholders = new Set<String>();

        Matcher matcher = placeholderPattern.matcher(template);
        while (matcher.find()) {
            uniquePlaceholders.add(matcher.group(0));
        }

        for (String placeholder : uniquePlaceholders) {
            String placeholderWithoutBraces = placeholder.substring(2, placeholder.length() - 1);
            String[] parts = placeholderWithoutBraces.split('\\.');
            String prefix = parts[0];

            DataRecord matchedRecord = findMatchingDataRecord(dataRecords, prefix);
            if (matchedRecord != null) {
                Object resolvedValue = resolvePlaceholderValue2(matchedRecord, placeholderWithoutBraces);
                if (resolvedValue instanceof String) {
                    template = template.replace(placeholder, (String) resolvedValue);
                }
            }
        }

        // Iterate construct replacement
        Pattern iteratePattern = Pattern.compile('(?s)<%iterate:\\s*([^%]+)\\s*%>(.*?)<%iterate_end%>');
        Matcher iterateMatcher = iteratePattern.matcher(template);

        while (iterateMatcher.find()) {
            String iteratePlaceholder = iterateMatcher.group(0);
            String iteratePath = iterateMatcher.group(1);
            String iterateContent = iterateMatcher.group(2);

            DataRecord iterateDataRecord = findMatchingDataRecord(dataRecords, iteratePath.split('\\.')[0]);
            if (iterateDataRecord != null) {
                List<Id> recordIDs = (List<Id>) resolvePlaceholderValue2(iterateDataRecord, iteratePath);
                if (recordIDs != null) {
                    String replacement = '';
                    Integer index = 1;
                    for (Id itemRecordId : recordIDs) {
                        List<DataRecord> itemDataRecords = new List<DataRecord> {
                            new DataRecord('$item', itemRecordId),
                            new DataRecord('$index', null, String.valueOf(index))
                        };
                        String iterationValue = replacePlaceholders(itemDataRecords, iterateContent);
                        replacement += iterationValue;
                        index++;
                    }
                    template = template.replace(iteratePlaceholder, replacement);
                }
            }
        }
        return template;
    }

    private static DataRecord findMatchingDataRecord(List<DataRecord> dataRecords, String prefix) {
        for (DataRecord dataRecord : dataRecords) {
            if (dataRecord.prefixName.equals(prefix)) {
                return dataRecord;
            }
        }
        return null;
    }

    private static Object resolvePlaceholderValue2(DataRecord dataRecord, String placeholderWithoutBraces) {
        if (dataRecord.value == null) {
            return resolvePlaceholderValue(dataRecord, placeholderWithoutBraces);
        }

        Object value = dataRecord.value;
        String[] parts = placeholderWithoutBraces.split('\\.');
        if (parts.size() > 1) {
            for (String part : parts) {
                if (value instanceof Map<String, Object>) {
                    value = ((Map<String, Object>)value).get(part);
                } else {
                    return null;
                }
            }
        }
        return value;
    }

    private static String resolvePlaceholderValue(DataRecord dataRecord, String placeholderWithoutBraces) {
        Id recordId = dataRecord.recordId;
        String objectName = recordId.getSObjectType().getDescribe().getName();
        String[] parts = placeholderWithoutBraces.split('\\.');

        String sanitizedFieldName = placeholderWithoutBraces
                .substring(parts[0].length() + 1)
                .replaceAll('[^a-zA-Z0-9_\\.]', '');

        String soql = 'SELECT ' + sanitizedFieldName + ' FROM ' + objectName + ' WHERE Id = \'' + recordId + '\'';
        try {
            SObject record = Database.query(soql);
            Object value = record;
            for (Integer i = 1; i < parts.size() - 1; i++) {
                value = ((SObject)value).getSObject(parts[i]);
            }
            Object val = ((SObject)value).get(parts[parts.size() - 1]);
            return String.valueOf(val);
        } catch (Exception e) {
            System.debug('PromptBuilder.cls: Unable to resolve value for ' + placeholderWithoutBraces);
            System.debug('PromptBuilder.cls: query is ' + soql);
            System.debug('PromptBuilder.cls: error is ' + e.getMessage());            
            return null;
        }
    }

    private static List<Id> getPlatinumOfferIDs(Id taskId) {

        Task task = [SELECT WhatId, What.Type, WhoId, Who.Type FROM Task WHERE Id = :taskId LIMIT 1];
        List<Platinum_Offer_Item_Product__c> offers = [
            SELECT
                Platinum_Offer_Item__r.Id
            FROM 
                Platinum_Offer_Item_Product__c 
            WHERE 
                Platinum_Offer_Item__r.Active__c = True 
                AND Product__c in (select Product2Id from OpportunityLineItem where OpportunityId = :task.WhatId)
            ORDER BY
                Platinum_Offer_Item__r.Service__c
        ];

        Set<Id> uniqueOfferIds = new Set<Id>();
        for (Platinum_Offer_Item_Product__c offer : offers) {
            uniqueOfferIds.add(offer.Platinum_Offer_Item__r.Id);
        }

        return new List<Id>(uniqueOfferIds);
    }

    private List<String> replacePlatinumOfferRulePlaceholders(Id taskId, String promptTemplate) {

        List<String> prompts = new List<String>();
        List<Id> uniqueOfferIds = getPlatinumOfferIDs(taskId);
        for (Id offerId : uniqueOfferIds) {
            List<PromptBuilder.DataRecord> dataRecords = prepareDataRecords(taskId, offerId);
            String prompt = PromptBuilder.replacePlaceholders(dataRecords, promptTemplate);
            prompts.add(prompt);
        }

        return prompts;
    }

    private List<QC_Rule_Result__c> getRuleResultsForTask(Id taskId) {

        Task task = [SELECT Work_Unit_Type__c, QC_Summary__c FROM Task WHERE Id = :taskId LIMIT 1];
        List<QC_Scorecard__c> qcScorecards = [
            SELECT Id 
            FROM QC_Scorecard__c 
            WHERE QC_Summary__c = :task.QC_Summary__c 
            ORDER BY CreatedDate DESC LIMIT 1
        ];
        if (qcScorecards.isEmpty()) {
            System.debug('PromptBuilder.cls: No scorecard found for ' + taskId);
            return new List<QC_Rule_Result__c>();
        }
        QC_Scorecard__c qcScorecard = qcScorecards[0];

        List<QC_Rule_Result__c> ruleResults = [
            SELECT
                QC_Scorecard__c,
                QC_Rule__r.Category__r.Name,
                QC_Rule__r.Name,
                QC_Rule__r.Context__c,
                QC_Rule__r.Grading_Criteria__c
            FROM 
                QC_Rule_Result__c 
            WHERE 
                QC_Scorecard__c = :qcScorecard.Id 
                and QC_Rule__r.Grader_Type__c = 'AutoAI'
                and QC_Rule__r.Enforced_On__c INCLUDES(:task.Work_Unit_Type__c)
            ORDER BY
                QC_Rule__r.Grading_Order__c,
                QC_Rule__r.Name
        ];

        return ruleResults;
    }

    private String getTranscriptForTask(Id taskId) {
        // Load the most recent transcript file content
        List<ContentDocumentLink> docLinks = [
            select 
                Id,
                LinkedEntityId,
                ContentDocument.Title,  
                ContentDocument.CreatedDate, 
                ContentDocument.LatestPublishedVersionId 
            from 
                ContentDocumentLink 
            where 
                LinkedEntityId = :taskId
                and ContentDocument.Title like '%-transcript.vtt.txt'
            order by 
                ContentDocument.CreatedDate desc
            limit 1
        ];

        String transcript = null;

        ContentDocumentLink docLink = docLinks.isEmpty() ? null : docLinks[0];
        if (docLink != null) {
            ContentVersion transcriptContent = [
                SELECT VersionData 
                FROM ContentVersion 
                WHERE Id = :docLink.ContentDocument.LatestPublishedVersionId
                LIMIT 1
            ];
            transcript = transcriptContent.VersionData.toString();
        }
        return transcript;
    }
}