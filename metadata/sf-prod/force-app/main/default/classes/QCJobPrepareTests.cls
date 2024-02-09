@isTest
public class QCJobPrepareTests {
    @isTest
    static void Should_Correctly_Map_InternalDS_To_QCBackendDS() {
        // Arrange
        IPromptBuilder mockPromptBuilder = new MockPromptBuilder();
        List<Id> recordIds = new List<Id>{'001D000000IqhSL'}; // replace with a valid Id

        // Action
        List<QCJobPrepare.QCJobRequestWrapper> result = 
            QCJobPrepare.internalPrepareJobDS(recordIds, mockPromptBuilder);

        // Assert
        System.assertEquals(1, result.size(), 'Expected one QCJobRequestWrapper in the result');
        System.assertEquals(2, result[0].jobRequest.qcRules.size(), 'Expected two QC rules in the job request');
        System.assertEquals('Rule1', result[0].jobRequest.qcRules[0].name, 
            'Expected the first rule name to be Rule1');
        System.assertEquals('Rule2', result[0].jobRequest.qcRules[1].name, 
            'Expected the second rule name to be Rule2');
        System.assertEquals(1, result[0].jobRequest.QCCategories.size(), 
            'Expected one QC category in the job request');
        System.assertEquals('Category1', result[0].jobRequest.QCCategories[0].name, 
            'Expected the QC category name to be Category1');
    }

    public class MockPromptBuilder extends IPromptBuilder {
        public override IPromptBuilder.QCJobDS prepareQCJobDS(Id recId) {
            IPromptBuilder.QCJobDS mockJobDS = new IPromptBuilder.QCJobDS();
            mockJobDS.qcRules = new List<IPromptBuilder.QCRuleDS>();
            IPromptBuilder.QCRuleDS rule1 = new IPromptBuilder.QCRuleDS();
            rule1.Name = 'Rule1';
            mockJobDS.qcRules.add(rule1);
            IPromptBuilder.QCRuleDS rule2 = new IPromptBuilder.QCRuleDS();
            rule2.Name = 'Rule2';
            mockJobDS.qcRules.add(rule2);
            
            mockJobDS.qcCategories = new List<IPromptBuilder.QCCategoryDS>();
            IPromptBuilder.QCCategoryDS category1 = new IPromptBuilder.QCCategoryDS();
            category1.Name = 'Category1';
            mockJobDS.qcCategories.add(category1);
            
            return mockJobDS;
        }

        public override QCTaskPrompt prepareQcTaskPrompt(Id taskId) { return null; }
        public override QCTaskPlatinumOfferPrompt preparePromptsToQcPlatinumOffers(Id taskId) { return null; }
    }
}