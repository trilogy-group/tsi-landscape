public with sharing class Utils implements IUtils {
    public Utils() {
    }

    @TestVisible
    public void attachTxtFile2Rec(Id recId, String title, String content) {
        ContentVersion contentVersion = new ContentVersion();
        contentVersion.Title = title;
        contentVersion.PathOnClient = title + '.txt';
        contentVersion.VersionData = Blob.valueOf(content);
        contentVersion.Origin = 'H';
        insert contentVersion;

        ContentDocumentLink cdl = new ContentDocumentLink();
        cdl.ContentDocumentId = [
                SELECT ContentDocumentId 
                FROM ContentVersion 
                WHERE Id = :contentVersion.Id
            ].ContentDocumentId;
            
        cdl.LinkedEntityId = recId;
        cdl.ShareType = 'V';
        cdl.Visibility = 'AllUsers';
        insert cdl;
    }
}