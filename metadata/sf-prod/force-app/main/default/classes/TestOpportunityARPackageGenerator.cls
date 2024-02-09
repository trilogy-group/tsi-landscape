@isTest
private class TestOpportunityARPackageGenerator {

    @TestSetup
    static void setup() {
        // Create test data
        Opportunity testOpportunity = TestData.createOpportunityForCPQDocument('Renewal','ACRM');

        // Create a test ContentVersion for the "Previous_Quote_with_AR_clause__c"
        ContentVersion testContentVersion = new ContentVersion(
            Title = 'Test Document',
            PathOnClient = 'TestDocument.pdf',
            VersionData = Blob.valueOf('Test PDF Content'),
            IsMajorVersion = true
        );
        insert testContentVersion;
        
        // Link the ContentVersion to the Opportunity
        String contentDocumentURL = 'https://trilogy-sales.lightning.force.com/lightning/r/ContentDocument/';
        contentDocumentURL +=[SELECT ContentDocumentId FROM ContentVersion WHERE Id = :testContentVersion.Id].ContentDocumentId +'/view';
        testOpportunity.Previous_Quote_with_AR_clause__c = contentDocumentURL;
        
        update testOpportunity;
    }

    @isTest
    static void testGenerateAndAttachPDFWithoutPreviousQuote() {
        Opportunity opp = [SELECT Id, Name FROM Opportunity LIMIT 1];
        
        System.Test.startTest();
        OpportunityARPackageGenerator.generateAndAttachPDF(opp.Id);
        System.Test.stopTest();

        // Verify that a ContentVersion record is created
        List<ContentVersion> contentVersions = [SELECT Id, Title FROM ContentVersion WHERE FirstPublishLocationId = :opp.Id];
        System.assertEquals(1, contentVersions.size(), 'A new ContentVersion should be created.');
    }

    @isTest
    static void testGenerateAndAttachPDFWithPreviousQuote() {
        Opportunity opp = [SELECT Id, Name, Previous_Quote_with_AR_clause__c FROM Opportunity LIMIT 1];
        
        System.Test.startTest();
        OpportunityARPackageGenerator.generateAndAttachPDF(opp.Id);
        System.Test.stopTest();

        // Verify that a ContentVersion record is created and linked
        List<ContentVersion> contentVersions = [SELECT Id, Title FROM ContentVersion WHERE FirstPublishLocationId = :opp.Id];
        System.assertEquals(1, contentVersions.size(), 'One ContentVersion records should be created.');
    }
    @isTest
    static void testControllerInitializationAndDataLoading() {
        // Query an Opportunity record to simulate the standard controller
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        ApexPages.StandardController stdController = new ApexPages.StandardController(opp);

        System.Test.startTest();
        ARPackageController controller = new ARPackageController(stdController);
        System.Test.stopTest();

        // Verify that the controller is initialized correctly
        System.assertEquals(opp.Id, controller.oppId, 'The controller should have the correct Opportunity ID.');

        // Verify that related activities and emails are loaded
        System.assertNotEquals(null, controller.relatedActivities, 'Related activities should be loaded.');
        System.assertNotEquals(null, controller.relatedEmails, 'Related emails should be loaded.');
    }
    @isTest
    static void testInvocableMethod() {
        Opportunity opp = [SELECT Id, Name FROM Opportunity LIMIT 1];
        
        System.Test.startTest();
        OpportunityARPackageGenerator.generateARPackage(new List<Id>{opp.Id});
        System.Test.stopTest();

        // Verify that a ContentVersion record is created
        List<ContentVersion> contentVersions = [SELECT Id, Title FROM ContentVersion WHERE FirstPublishLocationId = :opp.Id];
        System.assertEquals(1, contentVersions.size(), 'A new ContentVersion should be created.');
    }
    @isTest
    static void testUnsignedQuotes() {
        Opportunity opp = [SELECT Id, SBQQ__PrimaryQuote__c FROM Opportunity LIMIT 1];
        ContentVersion testContentVersion = new ContentVersion(
            Title = 'Q12323_unsigned',
            PathOnClient = 'Q12323_unsigned.pdf',
            VersionData = Blob.valueOf('Test PDF Content'),
            IsMajorVersion = true,
            FirstPublishLocationId  = opp.SBQQ__PrimaryQuote__c
        );
        insert testContentVersion;
        System.Test.startTest();
        OpportunityARPackageGenerator.generateARPackage(new List<Id>{opp.Id});
        System.Test.stopTest();
        // Verify that a ContentVersion record is created
        List<ContentVersion> contentVersions = [SELECT Id, Title FROM ContentVersion WHERE FirstPublishLocationId = :opp.Id
                                               	AND PathOnClient like '%.zip'];
        System.assertEquals(1, contentVersions.size(), 'A new ContentVersion should be created.');
    }

}