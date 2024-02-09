@isTest
private class UtilsTests {

    @isTest 
    static void testAttachTxtFile2Rec() {
        // Step 1: Set up test data
        // Assuming 'MyObject__c' is the object to which you want to attach the file
        Task testRecord = new Task(Subject = 'Test Task');
        insert testRecord;

        // Step 2: Call the method to test
        Test.startTest();
        // Replace 'YourClass' with the actual name of your class that contains the attachTxtFile2Rec method
        Utils utils = new Utils();
        utils.attachTxtFile2Rec(testRecord.Id, 'Test Title', 'Test Content');
        Test.stopTest();

        // Step 3: Verify the results
        // Query for the ContentVersion based on the title
        ContentVersion contentVersion = [
            SELECT Title, PathOnClient, VersionData, ContentDocumentId 
            FROM ContentVersion 
            WHERE Title = 'Test Title'
            LIMIT 1
        ];
        System.assertNotEquals(null, contentVersion, 'ContentVersion record should be created');
        System.assertEquals('Test Title.txt', contentVersion.PathOnClient, 
                    'PathOnClient should match the title with .txt extension');
        System.assertEquals('Test Content', contentVersion.VersionData.toString(), 
                'VersionData should match the test content');

        // Query for the ContentDocumentLink
        ContentDocumentLink cdl = [
            SELECT ContentDocumentId, LinkedEntityId, ShareType, Visibility 
            FROM ContentDocumentLink 
            WHERE LinkedEntityId = :testRecord.Id
            LIMIT 1
        ];
        System.assertNotEquals(null, cdl, 'ContentDocumentLink record should be created');
        System.assertEquals(testRecord.Id, cdl.LinkedEntityId, 'LinkedEntityId should match the test record Id');
        System.assertEquals('V', cdl.ShareType, 'ShareType should be V');
        System.assertEquals('AllUsers', cdl.Visibility, 'Visibility should be AllUsers');
    }
}