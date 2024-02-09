@isTest
private class QCTaskTests {

    private static final String PROMPT_PREFIX = 'Prefix for Task QC prompt';


    // Mock for IUtils (w/ StubProvider)
    private class MockUtils implements System.StubProvider {
        Boolean attachTxtFile2Rec_called = false;
        public Object handleMethodCall(Object stubbedObject, String stubbedMethodName, 
                                     Type returnType, List<Type> parameterTypes, 
                                     List<String> parameterNames, List<Object> args) {

            if (stubbedMethodName == 'attachTxtFile2Rec') {
                attachTxtFile2Rec_called = true;
            }
            return null;
        }
    }

    private class MockAgentPlatinum implements IAgent {

        List<QCTask.QCRuleResult> m_objReply;

        public MockAgentPlatinum(List<QCTask.QCRuleResult> objReply) {
            m_objReply = objReply;
        }
        public String runPrompt(String prompt) {
            return null;
        }
        public Object runPrompt(String prompt, Type targetType) {
            QCTask.QCRuleResult res = m_objReply[0];
            if (m_objReply.size() > 1) {
                res = m_objReply.remove(0);
            }
            System.debug(LoggingLevel.INFO, 'MockAgent.runPrompt: ' + JSON.serialize(res));
            return res;
        }
    }

    private class MockAgent implements IAgent {

        String m_reply;
        Object m_objReply;

        public MockAgent(String reply, Object objReply) {
            m_reply = reply;
            m_objReply = objReply;
        }
        public String runPrompt(String prompt) {
            return m_reply;
        }
        public Object runPrompt(String prompt, Type targetType) {
            System.debug(LoggingLevel.INFO, 'MockAgent.runPrompt: ' + JSON.serialize(m_objReply));
            return m_objReply;
        }
    }    

    private class MockPromptBuilderSimpleQCRules extends IPromptBuilder {
    
        private final QCTaskPrompt mockQCTaskPrompt;
    
        public MockPromptBuilderSimpleQCRules(QCTaskPrompt mockQCTaskPrompt) {
            this.mockQCTaskPrompt = mockQCTaskPrompt;
        }
        public override QCTaskPrompt prepareQcTaskPrompt(Id taskId) {
            System.debug(LoggingLevel.INFO, 'MockQCTaskPrompt: ' + JSON.serialize(mockQCTaskPrompt));
            return mockQCTaskPrompt;
        }
        public override QCTaskPlatinumOfferPrompt preparePromptsToQcPlatinumOffers(Id taskId) {
            return null;
        }
        public override IPromptBuilder.QCJobDS prepareQCJobDS(Id recordId) {
            return null;
        }     
    }

    private class MockPromptBuilderPlatinumQCRule extends IPromptBuilder {
    
        private final List<String> mockPrompts;
        private final QC_Rule_Result__c mockRuleResult;
    
        public MockPromptBuilderPlatinumQCRule(List<String> prompts, QC_Rule_Result__c mockRuleResult) {
            this.mockPrompts = prompts;
            this.mockRuleResult = mockRuleResult;
        }
        public override QCTaskPrompt prepareQcTaskPrompt(Id taskId) {
            return null;
        }
        public override QCTaskPlatinumOfferPrompt preparePromptsToQcPlatinumOffers(Id taskId) {
            QCTaskPlatinumOfferPrompt prompt = new QCTaskPlatinumOfferPrompt();
            prompt.prompts = this.mockPrompts;
            prompt.ruleResult = this.mockRuleResult;
            return prompt;
        }
        public override IPromptBuilder.QCJobDS prepareQCJobDS(Id recordId) {
            return null;
        }     
    }   

    @isTest 
    static void Should_Parse_AI_Response_For_Platinum_QC_Rules_And_Save_Into_Rule_Result() { //NOSONAR

        setupData(true);

        // Set mock callout class 
        QCTask.QCRuleResult qcRuleResult1 = new QCTask.QCRuleResult();
        qcRuleResult1.RuleName = 'Service Offer 1';
        qcRuleResult1.Result = 'Pass';
        qcRuleResult1.Reason = 'All checks for service 1 passed';

        QCTask.QCRuleResult qcRuleResult2 = new QCTask.QCRuleResult();
        qcRuleResult2.RuleName = 'Service Offer 2';
        qcRuleResult2.Result = 'Fail';
        qcRuleResult2.Reason = 'Some checks for service 2 failed';


        IAgent mockAgent = new MockAgentPlatinum(new List<QCTask.QCRuleResult> { qcRuleResult1, qcRuleResult2 });

        // Call method to test
        Test.startTest();
        IPromptBuilder promptBuilder = new MockPromptBuilderPlatinumQCRule(
            new List<String> { PROMPT_PREFIX, PROMPT_PREFIX },
            m_testRuleResult);
        IUtils mockUtils = (IUtils)Test.createStub(IUtils.class, new MockUtils());
        QCTask qcer = new QCTask(promptBuilder, mockUtils, mockAgent);

        qcer.qcTasks(new List<Id> { m_testTask.Id });

        Test.stopTest();

        QC_Rule_Result__c ruleResult = [
            SELECT Id, Result__c, Grader_Comment__c 
            FROM QC_Rule_Result__c 
            WHERE Id = :m_testRuleResult.Id];

        System.debug(LoggingLevel.INFO, 'RULE_RESULT 1: ' + JSON.serialize(ruleResult));

        System.assertEquals('Fail', ruleResult.Result__c, 'The result should match the mock response.');
        System.assert(ruleResult.Grader_Comment__c.contains('All checks for service 1 passed'), 
                    'The reason contains a reason returned by LLM (1).');
        System.assert(ruleResult.Grader_Comment__c.contains('Some checks for service 2 failed'), 
                    'The reason contains a reason returned by LLM (2).');
    }

    @isTest 
    static void Should_Parse_AI_Response_For_Simple_QC_Rules_And_Save_Into_Rule_Result() { //NOSONAR

        setupData(true);

        // Set mock callout class 
        QCTask.QCRuleResult qcRuleResult = new QCTask.QCRuleResult();
        qcRuleResult.RuleName = m_testRule.Name;
        qcRuleResult.Result = 'Pass';
        qcRuleResult.Reason = 'All checks passed';

        QCTask.QCScorecard qcScorecard = new QCTask.QCScorecard();
        qcScorecard.ruleResults = new List<QCTask.QCRuleResult> { qcRuleResult };
        qcScorecard.GraderComment = 'Here goes grader comment for the whole call';

        IPromptBuilder.QCTaskPrompt qcTaskPrompt = new IPromptBuilder.QCTaskPrompt();
        qcTaskPrompt.scorecardId = m_testScorecard.Id;
        qcTaskPrompt.prompt = PROMPT_PREFIX;
        qcTaskPrompt.ruleResults = new List<QC_Rule_Result__c> { m_testRuleResult };

        // Call method to test
        Test.startTest();
        IAgent mockAgent = new MockAgent(null, qcScorecard);
        IPromptBuilder promptBuilder = new MockPromptBuilderSimpleQCRules(qcTaskPrompt);
        IUtils mockUtils = (IUtils)Test.createStub(IUtils.class, new MockUtils());
        QCTask qcer = new QCTask(promptBuilder, mockUtils, mockAgent);

        qcer.qcTasks(new List<Id> { m_testTask.Id });

        Test.stopTest();

        QC_Rule_Result__c ruleResult = [
            SELECT Id, Result__c, Grader_Comment__c 
            FROM QC_Rule_Result__c 
            WHERE Id = :m_testRuleResult.Id];

        QC_Scorecard__c scorecard = [
            SELECT Id, Grader_Comment__c 
            FROM QC_Scorecard__c 
            WHERE Id = :m_testScorecard.Id];

        System.debug(LoggingLevel.INFO, 'RULE_RESULT: ' + JSON.serialize(ruleResult));
        System.debug(LoggingLevel.INFO, 'SCORECARD: ' + JSON.serialize(scorecard));
        System.assertEquals('Pass', ruleResult.Result__c, 'The result should match the mock response.');
        System.assertEquals('All checks passed', 
                    ruleResult.Grader_Comment__c, 
                    'The reason should match the mock response.');
        System.assertEquals(qcScorecard.GraderComment, 
                    scorecard.Grader_Comment__c, 
                    'The grader comment should match the mock response.');
    }

    static QC_Summary__c m_testSummary;
    static QC_Scorecard__c m_testScorecard;
    static QC_Rule__c m_testRule;
    static QC_Rule_Result__c m_testRuleResult;
    static Task m_testTask;

    //@testSetup - it resets static vars!
    static void setupData(Boolean attachTranscript) {
        m_testSummary = new QC_Summary__c(Name = 'ExampleSummary');
        insert m_testSummary;

        // Create a mock QC_Scorecard__c record
        m_testScorecard = new QC_Scorecard__c(QC_Summary__c = m_testSummary.Id);
        insert m_testScorecard;

        // Create a mock QC_Rule_Result__c record
        m_testRule = new QC_Rule__c(
            Name = 'ExampleRule', 
            Description__c = 'ExampleDescription', 
            Grader_Type__c = 'AutoAI', 
            Enforced_On__c = 'Renewal Call',
            Enforced__c = True
        );
        insert m_testRule;
        
        m_testRuleResult = new QC_Rule_Result__c(
            QC_Scorecard__c = m_testScorecard.Id, 
            QC_Rule__c = m_testRule.Id,
            QC_Rule__r = m_testRule
        );
        insert m_testRuleResult;

        // Create a mock Task record => QC resuls must be generated
        // for this task, among them should one for our test rule
        m_testTask = new Task(
            Subject = 'Renewal Call - DNN',
            CallDisposition = 'Completed - Action needed',
            Type = 'Call',
            Work_Unit_Type__c = 'Renewal Call', 
            QC_Scorecard__c = m_testScorecard.Id);
        insert m_testTask;

        if(attachTranscript) {
            Utils utils = new Utils();
            utils.attachTxtFile2Rec(m_testTask.Id, m_testTask.Id + '-transcript.vtt.txt', 'Transcript goes here');
        }
        System.debug('QCTaskTests.setup() - completed');
    }
}