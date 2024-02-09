@IsTest
public class PromptBuilderTests { //NOSONAR

    private static final String PROMPT_PREFIX = 'Prefix for Task QC prompt';
    private static final String RENEWAL_CALL = 'Renewal Call';

    //mock IPromptProvider (w/o StubProvider)
    private class MockPromptRegistry implements IPromptBuilder.IPromptRegistry {
        public String output;
        public MockPromptRegistry(String output) {
            this.output = output;
        }
        public String getQCTaskPromptPrefix() {
            return output;
        }
        public String getQCTaskPlatinumOfferPromptPrefix() {
            return output;
        }
    }

    @isTest
    static void Should_Prepare_Data_Records_For_Opportunity_And_Contact() { //NOSONAR
        BasicTaskData basicTaskData = createBasicTaskData();

        Test.startTest();
        // Call the method to test
        List<PromptBuilder.DataRecord> dataRecords = PromptBuilder.prepareDataRecords(basicTaskData.taskId, 
            basicTaskData.platinumOfferItemId);
        Test.stopTest();

        // Assert the results
        System.assertEquals(4, dataRecords.size(), 'There should be 4 data records prepared.');

        // Additional assertions can be made to check the content of the DataRecords
        // For example, check if the first record is the Task record
        // Create list of DataRecords based on the assertions provided
        List<PromptBuilder.DataRecord> expectedDataRecords = new List<PromptBuilder.DataRecord> {
            new PromptBuilder.DataRecord('Record', basicTaskData.taskId),
            new PromptBuilder.DataRecord('Opportunity', basicTaskData.oppId),
            new PromptBuilder.DataRecord('Contact', basicTaskData.contactId),
            new PromptBuilder.DataRecord('Platinum_Offer_Item__c', basicTaskData.platinumOfferItemId)
        };

        // Assert that each element in the expectedDataRecords matches one in the dataRecords returned by the method
        for (PromptBuilder.DataRecord expectedRecord : expectedDataRecords) {
            Boolean isMatchFound = false;
            for (PromptBuilder.DataRecord actualRecord : dataRecords) {
                if (expectedRecord.prefixName == actualRecord.prefixName && 
                    expectedRecord.recordId == actualRecord.recordId) {

                    isMatchFound = true;
                    break;
                }
            }
            System.assert(isMatchFound, 'The record with prefixName ' + expectedRecord.prefixName +
                 ' and recordId ' + expectedRecord.recordId + ' should be present in the actual dataRecords.');
        }
    }

    @isTest 
    static void Should_Throw_Exception_If_No_Transcript_Is_Attached_To_Task() { //NOSONAR
        createQCRecords();
        createTask(false, null);
        try {
            Utils utils = new Utils();
            call_PrepareQcPrompt();
            System.assert(false, 'Expected NoTranscriptFoundException to be thrown');
        } catch (IPromptBuilder.NoTranscriptFoundException e) {
            System.assert(true, 'NoTranscriptFoundException was thrown as expected');
        }
    }

    @isTest
    static void Should_Prepare_Prompt_Based_On_Prefix_Rule_Transcript() { //NOSONAR
        createQCRecords();
        createTask(true, null);
        call_PrepareQcPrompt();
    }

    @isTest
    static void Should_Iterate_Over_Platinum_Offer_Items() { //NOSONAR
        //setup 
        createQCRecords();
        addPlatinumDiscoveryRuleData();
        createTask(true, m_testOpp.Id);

        //action
        Test.startTest();
        PromptBuilder buidler = new PromptBuilder(new MockPromptRegistry(PROMPT_PREFIX));
        IPromptBuilder.QCTaskPrompt result = buidler.prepareQcTaskPrompt(m_testTask.Id);
        Test.stopTest();
        System.debug('==============');
        System.debug(result.prompt);
        // Assert the expected outcomes
        System.assert(result.prompt.contains('Questions 1: Here goes probing questions 1'), 
            'The prompt should contain the probing questions.');
    }

    @isTest()
    static void Should_Ignore_Platinum_Discovery_Rule_For_Simple_QC_Prompt() { //NOSONAR

        //setup 
        createQCRecords();
        addPlatinumDiscoveryRuleData();
        createTask(true, m_testOpp.Id);

        //action
        Test.startTest();
        PromptBuilder buidler = new PromptBuilder(new MockPromptRegistry(PROMPT_PREFIX));
        IPromptBuilder.QCTaskPrompt result = buidler.prepareQcTaskPrompt(m_testTask.Id);
        Test.stopTest();

        // Assert the expected outcomes
        System.assert(!result.prompt.contains(IPromptBuilder.PLATINUM_OFFER_RULE_NAME), 
            'The prompt should NOT contain "Platinum Offers Discover" rule.');
    }

    @isTest()
    static void Should_Contain_Platinum_Rule_Prompt_Prefix() { //NOSONAR
        //setup 
        createQCRecords();
        addPlatinumDiscoveryRuleData();
        createTask(true, m_testOpp.Id);

        //action
        Test.startTest();
        PromptBuilder buidler = new PromptBuilder(new MockPromptRegistry(PROMPT_PREFIX));
        IPromptBuilder.QCTaskPlatinumOfferPrompt result = buidler.preparePromptsToQcPlatinumOffers(m_testTask.Id);
        Test.stopTest();

        // Assert the expected outcomes
        System.debug(LoggingLevel.INFO, 'QCTaskPlatinumOfferPrompt: ' + JSON.serialize(result));
        String combinedPrompts = '';
        for (String prompt : result.prompts) {
            combinedPrompts += prompt;
        }

        System.assert(combinedPrompts.contains('Offer 1'), 'The final prompt should contain "Offer 1".');
        System.assert(combinedPrompts.contains('Here goes probing questions'), 
            'The final prompt should contain the probing questions.');
        System.assert(combinedPrompts.contains('Here goes description'), 
            'The final prompt should contain the description.');
        System.assert(combinedPrompts.contains('Here goes AI prompt'), 
            'The final prompt should contain the AI prompt.');
        System.assert(combinedPrompts.contains('Service 2'), 'The final prompt should contain the service.');
    }
  
    @isTest
    static void Should_Prepare_QCJobDS_Based_On_QCRules() { //NOSONAR
        createQCRecords();
        createTask(true, null);
        call_PrepareQcJobDS();
    }

    static void call_PrepareQcJobDS() {

        // Call the method
        Test.startTest();
        PromptBuilder buidler = new PromptBuilder(new MockPromptRegistry(PROMPT_PREFIX));
        IPromptBuilder.QCJobDS result = buidler.prepareQCJobDS(m_testTask.Id);
        Test.stopTest();

        // Assert the expected outcomes for QCJobRequest
        System.assertNotEquals(null, result, 'The QCJobRequest result should not be null.');
        System.assertEquals(PROMPT_PREFIX, result.promptPrefix, 
            'The promptPrefix should match the expected PROMPT_PREFIX.');
        System.assertNotEquals(null, result.qcRules, 'The qcRules list should not be null.');
        System.assertEquals(2, result.qcRules.size(), 'There should be two QC rules in the list.');
        System.assertEquals('ExampleRule2', result.qcRules[0].name, 'The first QC rule name should match.');
        System.assertEquals('Example Context 2 Completed - Action needed', result.qcRules[0].context, 
            'The first QC rule context should match.');
        System.assert(result.qcRules[0].gradingCriteria.contains('Example Criteria 2'), 
            'The first QC rule grading criteria should match.');

        System.assertEquals('ExampleRule1', result.qcRules[1].name, 'The second QC rule name should match.');
        System.assertEquals('Example Context 1 Completed - Action needed', result.qcRules[1].context, 
            'The second QC rule context should match.');
        System.assert(result.qcRules[1].gradingCriteria.contains('Example Criteria 1'), 
            'The second QC rule grading criteria should match.');
        System.assertEquals('Transcript goes here', result.workData, 
            'The workData should contain the transcript.');
    }

    static void call_PrepareQcPrompt() {

        // Call the method
        Test.startTest();
        PromptBuilder buidler = new PromptBuilder(new MockPromptRegistry(PROMPT_PREFIX));
        IPromptBuilder.QCTaskPrompt result = buidler.prepareQcTaskPrompt(m_testTask.Id);
        Test.stopTest();

        // Assert the expected outcomes
        System.assertNotEquals(null, result, 'The result should not be null.');
        System.assert(result.prompt.contains('ExampleRule1'), 'The prompt should contain the rule 1 name.');
        System.assert(result.prompt.contains('ExampleRule2'), 'The prompt should contain the rule 2 name.');
        System.assert(result.prompt.contains('Example Context 1'), 
            'The prompt should contain the rule\'s context.');
        System.assert(result.prompt.contains('Example Criteria 1'), 
            'The prompt should contain the rule\'s grading criteria.');
        System.assert(result.prompt.contains('Completed - Action needed'), 
            '${Record.CallDisposition} must be replaced in the prompt template.');
        System.assert(result.prompt.contains(PROMPT_PREFIX), 
            'The prompt should contain the text from the Prompt__mdt record.');
        System.assert(result.prompt.contains('Transcript goes here'), 'The prompt should contain the transcript.');
        System.assertEquals(m_testScorecard.Id, result.scorecardId, 'Scorecard Id should be set correctly.');

        // Verify ExampleRule1 goes after ExampleRule2
        Integer indexRule1 = result.prompt.indexOf('ExampleRule1');
        Integer indexRule2 = result.prompt.indexOf('ExampleRule2');
        System.assert(indexRule1 > indexRule2, 'ExampleRule1 should come after ExampleRule2 in the prompt.');
    }

    @isTest
    static void Should_Replace_Dynamic_Placeholders_When_Calling_To_replacePlaceholders() { //NOSONAR
        // Arrange
        BasicTaskData basicTaskData = createBasicTaskData();

        // Template with placeholders
        String template = 'Owner = ${Record.Owner.Name};'  + //three level placeholder
            ' Product = ${Opp.Product__c};' +
            ' Probing Questions: ${Platinum_Offer_Item__c.Probing_Questions__c}';

        // Create DataRecord instances for each object
        List<PromptBuilder.DataRecord> dataRecords = new List<PromptBuilder.DataRecord>{
            new PromptBuilder.DataRecord('Record', basicTaskData.taskId),
            new PromptBuilder.DataRecord('Opp', basicTaskData.oppId),
            new PromptBuilder.DataRecord('Platinum_Offer_Item__c', basicTaskData.platinumOfferItemId)
        };

        // Mock expected values
        String expectedOwnerName = [SELECT Name FROM User WHERE Id = :basicTaskData.userId].Name;
        String expectedProductFamily = [SELECT Product__c FROM Opportunity 
            WHERE Id = :basicTaskData.oppId].Product__c;
        String expectedProbingQuestions = [SELECT Probing_Questions__c FROM Platinum_Offer_Item__c
             WHERE Id = :basicTaskData.platinumOfferItemId].Probing_Questions__c;

        // Act
        Test.startTest();
        String result = PromptBuilder.replacePlaceholders(dataRecords, template);
        Test.stopTest();

        // Assert
        String expectedString = 'Owner = ' + expectedOwnerName + ';' +
            ' Product = ' + expectedProductFamily + ';' +
            ' Probing Questions: ' + expectedProbingQuestions;

        System.assertEquals(expectedString, result, 'The placeholders were not replaced correctly.');
    }

    static Task m_testTask;
    static QC_Summary__c m_testSummary;
    static QC_Scorecard__c m_testScorecard;
    static Opportunity m_testOpp;

    static QC_Rule__c m_testRule1;
    static QC_Rule__c m_testRule2;
    static QC_Rule_Result__c m_testRule1Result;
    static QC_Rule_Result__c m_testRule2Result;
    static QC_Rule__c m_testPlatinumRule;
    static QC_Rule_Result__c m_testPlatinumRuleResult;

    static Product2 m_platinumProd;

    class BasicTaskData {
        Id taskId;
        Id oppId;
        Id platinumOfferItemId;
        Id accountId;
        Id userId;
        Id contactId;
    }

    static BasicTaskData createBasicTaskData() {
        Account testAccount = new Account(
            Name = 'Test Account'
        );
        insert testAccount;

        Contact testContact = new Contact(
            FirstName = 'Test',
            LastName = 'Contact',
            AccountId = testAccount.Id
        );
        insert testContact;

        Opportunity testOpportunity = new Opportunity(
            Name = 'Test Opportunity - Renewal',
            StageName = 'Proposal',
            CloseDate = System.today().addDays(30),
            Amount = 12345.67,
            AccountId = testAccount.Id,
            Product__c = 'DNN',
            Type = 'Renewal',
            Renewal_Date__c = System.today().addYears(1),
            Parent_Subscription_ID__c = '12345'
        );
        insert testOpportunity;

        User testUser = new User(
            Username = 'testuser20231221@example.com',
            LastName = 'User',
            FirstName = 'Test',
            Alias = 'tuser',
            Email = 'testuser20231221@example.com',
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'Standard User'].Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
        insert testUser;

        Task testTask = new Task(
            Subject = 'Follow-Up Call',
            Priority = 'High',
            WhoId = testContact.Id,
            WhatId = testOpportunity.Id,
            OwnerId = testUser.Id
        );
        insert testTask;

        Platinum_Offer_Item__c testPlatinumOfferItem = new Platinum_Offer_Item__c(
            Name = 'Test Item - Managed Upgrade',
            Probing_Questions__c = 'How many users do you have?'
        );
        insert testPlatinumOfferItem;

        BasicTaskData basicTaskData = new BasicTaskData();
        basicTaskData.taskId = testTask.Id;
        basicTaskData.oppId = testOpportunity.Id;
        basicTaskData.platinumOfferItemId = testPlatinumOfferItem.Id;
        basicTaskData.accountId = testAccount.Id;
        basicTaskData.userId = testUser.Id;
        basicTaskData.contactId = testContact.Id;

        return basicTaskData;
    }

    static void addPlatinumDiscoveryRuleData() {
        m_testPlatinumRule = new QC_Rule__c(
            Name = '1.2 ' + IPromptBuilder.PLATINUM_OFFER_RULE_NAME, 
            Context__c = 'Platinum Discovery Context' + 
                '${Platinum_Offer_Item__c.Name} ' + 
                '${Platinum_Offer_Item__c.Service__c} ', 
            Grading_Criteria__c = 'Platinum Discovery Garding Criteria' + 
                '${Platinum_Offer_Item__c.Probing_Questions__c} ' + 
                '${Platinum_Offer_Item__c.Description__c} ' + 
                '${Platinum_Offer_Item__c.AI_Prompt__c} ' + 
                '${Opportunity.Product__c}', 
            Grader_Type__c = 'AutoAI', 
            Enforced_On__c = RENEWAL_CALL,
            Enforced__c = True
        );
        insert m_testPlatinumRule;
        
        m_testPlatinumRuleResult = new QC_Rule_Result__c(
            QC_Scorecard__c = m_testScorecard.Id, 
            QC_Rule__c = m_testPlatinumRule.Id,
            QC_Rule__r = m_testPlatinumRule
        );
        insert m_testPlatinumRuleResult;

        // Create an Opportunity
        m_testOpp = new Opportunity(
            //AccountId = testAccount.Id,
            Product__c = 'DNN', 
            Name = 'Test Opportunity', 
            StageName = 'Pending', 
            CloseDate =  DateTime.now().addDays(5).date(), 
            Type='New Business',
            All_Tasks_Completed__c = false
        );    

        insert m_testOpp;

        // Create two Products
        m_platinumProd = new Product2(Product__c='DNN', Name='Platinum Product 1', Family = 'DNN', IsActive=true);
        Product2 prod2 = new Product2(Product__c='DNN', Name='Product 2', Family = 'DNN', IsActive=true);
        insert new List<Product2>{m_platinumProd, prod2};

        // Create Pricebook and PricebookEntries
        Id standardPbId = Test.getStandardPricebookId();
        PricebookEntry pbe1 = new PricebookEntry(
                Product2Id=m_platinumProd.Id, 
                Pricebook2Id=standardPbId, 
                UnitPrice=100, 
                IsActive=true
        );
        PricebookEntry pbe2 = new PricebookEntry(
            Product2Id=prod2.Id, 
            Pricebook2Id=standardPbId, 
            UnitPrice=200, 
            IsActive=true
        );
        insert new List<PricebookEntry>{pbe1, pbe2};

        // Create OpportunityLineItems
        OpportunityLineItem oli1 = new OpportunityLineItem(
            OpportunityId=m_testOpp.Id, 
            PricebookEntryId=pbe1.Id, 
            Quantity=1, 
            TotalPrice=100
        );
        OpportunityLineItem oli2 = new OpportunityLineItem(
            OpportunityId=m_testOpp.Id, 
            PricebookEntryId=pbe2.Id, 
            Quantity=1, 
            TotalPrice=200
        );
        insert new List<OpportunityLineItem>{oli1, oli2};

        // Create Platinum Offer Items
        Platinum_Offer_Item__c offerItem1 = new Platinum_Offer_Item__c(
            Active__c=true,
            Name='Offer 1',
            Service__c = 'Service 1', 
            Probing_Questions__c='Here goes probing questions 1',
            Description__c='Here goes description',
            AI_Prompt__c='Here goes AI prompt'
        );
        Platinum_Offer_Item__c offerItem2 = new Platinum_Offer_Item__c(
            Name='Offer 2', 
            Service__c = 'Service 2',
            Probing_Questions__c='Here goes probing questions 2',
            Active__c=true
        );
        insert new List<Platinum_Offer_Item__c>{offerItem1, offerItem2};

        // Create Platinum Offer Item Products
        Platinum_Offer_Item_Product__c offerProd1 = new Platinum_Offer_Item_Product__c(
            Platinum_Offer_Item__c=offerItem1.Id, 
            Product__c=m_platinumProd.Id
        );
        Platinum_Offer_Item_Product__c offerProd2 = new Platinum_Offer_Item_Product__c(
            Platinum_Offer_Item__c=offerItem2.Id, 
            Product__c=prod2.Id
        );
        insert new List<Platinum_Offer_Item_Product__c>{offerProd1, offerProd2};

        // Assuming we have a valid pricebook ID from prior setup
        // Create a SBQQ__Quote__c (CPQ Quote) and mark it as primary for the Opportunity
        SBQQ__Quote__c primaryQuote = new SBQQ__Quote__c(
            SBQQ__Opportunity2__c = m_testOpp.Id,
            SBQQ__Primary__c = true,
            SBQQ__Status__c = 'Draft', // Assuming 'Draft' is a valid status in your org
            SBQQ__Account__c = m_testOpp.AccountId // Assuming we are using the Account from the Opportunity
        );
        insert primaryQuote;

        // Create SBQQ__QuoteLine__c (CPQ Quote Lines) for the primary Quote
        // Assuming we have valid pricebook entry IDs from earlier setup
        SBQQ__QuoteLine__c quoteLine1 = new SBQQ__QuoteLine__c(
            SBQQ__Quote__c = primaryQuote.Id,
            SBQQ__Product__c = m_platinumProd.Id, // Set to CPQ Product lookup field
            SBQQ__Quantity__c = 1,
            SBQQ__ListPrice__c = 100 // Assuming ListPrice is the field to set
        );
        SBQQ__QuoteLine__c quoteLine2 = new SBQQ__QuoteLine__c(
            SBQQ__Quote__c = primaryQuote.Id,
            SBQQ__Product__c = prod2.Id, // Set to CPQ Product lookup field
            SBQQ__Quantity__c = 1,
            SBQQ__ListPrice__c = 200 // Assuming ListPrice is the field to set
        );
        insert new List<SBQQ__QuoteLine__c>{quoteLine1, quoteLine2};
    }

    static void createQCRecords() {
        m_testSummary = new QC_Summary__c(Name = 'ExampleSummary');
        insert m_testSummary;

        // Create a mock QC_Scorecard__c record
        m_testScorecard = new QC_Scorecard__c(QC_Summary__c = m_testSummary.Id);
        insert m_testScorecard;

        // Create a mock QC_Rule_Result__c record
        m_testRule1 = new QC_Rule__c(
            Name = 'ExampleRule1', 
            Context__c = 'Example Context 1 ${Record.CallDisposition}',
            Grading_Criteria__c = 'Example Criteria 1\n\n' +
                        'Here are some text 1:\n' +
                        '<%iterate:$Custom.Platinum_Offer_Item__r%>\n'+
                        'Questions ${$index}: ${$item.Probing_Questions__c}\n' +
                        '<%iterate_end%>\n', 
            Grader_Type__c = 'AutoAI', 
            Enforced_On__c = RENEWAL_CALL,
            Enforced__c = True,
            Grading_Order__c = 2
        );
        insert m_testRule1;

        m_testRule2 = new QC_Rule__c(
            Name = 'ExampleRule2', 
            Context__c = 'Example Context 2 ${Record.CallDisposition}',
            Grading_Criteria__c = 'Example Criteria 2\n\n' +
                        'Here are some text 2:\n' +
                        '<%iterate:$Custom.Platinum_Offer_Item__r%>\n'+
                        'Questions ${$index}: ${$item.Probing_Questions__c}\n' +
                        '<%iterate_end%>\n', 
            Grader_Type__c = 'AutoAI', 
            Enforced_On__c = RENEWAL_CALL,
            Enforced__c = True,
            Grading_Order__c = 1
        );
        insert m_testRule2;
        
        m_testRule1Result = new QC_Rule_Result__c(
            QC_Scorecard__c = m_testScorecard.Id, 
            QC_Rule__c = m_testRule1.Id
        );
        insert m_testRule1Result;

        m_testRule2Result = new QC_Rule_Result__c(
            QC_Scorecard__c = m_testScorecard.Id, 
            QC_Rule__c = m_testRule2.Id
        );
        insert m_testRule2Result;
    }

    static void createTask(Boolean attachTranscript, Id oppId) {
        // Create a mock Task record
        //NOTE: QC results records will not be generated because
        // QC Summary is explicitly specified 
        m_testTask = new Task(
            Subject = 'Renewal Call - DNN',
            CallDisposition = 'Completed - Action needed',
            Type = 'Call',
            Work_Unit_Type__c = RENEWAL_CALL,
            QC_Summary__c = m_testSummary.Id,
            WhatId = oppId
        );
        insert m_testTask;

        if(attachTranscript) {
            Utils utils = new Utils();
            utils.attachTxtFile2Rec(m_testTask.Id, m_testTask.Id + '-transcript.vtt.txt', 'Transcript goes here');
        }
    }
}