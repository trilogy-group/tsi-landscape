public with sharing class OpportunityARPackageGenerator {
    @future(callout=true)
    public static void generateAndAttachPDF(Id oppId) {
        try {
            Opportunity opp = [SELECT Name, Previous_Quote_with_AR_clause__c,
                               (SELECT Id from SBQQ__Quotes2__r)
                               FROM Opportunity WHERE Id = :oppId];
            
            // Generate PDF
            PageReference pdfPage = Page.RenderARPackagePDF;
            pdfPage.getParameters().put('id', oppId);
            Blob pdfBlob = Test.isRunningTest()?Blob.valueOf('Test Blob'):pdfPage.getContentAsPDF();
            String pdfFileName = 'opportunity_docs_' + opp.Name + '.pdf';

            // Create a new instance of Zippex
            Zippex sampleZip = new Zippex();

            // Add the PDF to the ZIP archive
            sampleZip.addFile(pdfFileName, pdfBlob, null);

            // Add existing ContentDocument if the field is not null
            if (opp.Previous_Quote_with_AR_clause__c != null) {
                // Extract ContentDocumentId from the URL
                String contentDocId = opp.Previous_Quote_with_AR_clause__c.substringBefore('/view').substringAfterLast('/');
                System.debug('==contentDocId=='+contentDocId);
                // Retrieve the ContentVersion
                ContentVersion prevQuote = [SELECT VersionData, Title, FileExtension 
                                            FROM ContentVersion 
                                            WHERE ContentDocumentId = :contentDocId AND IsLatest = true LIMIT 1];
                Blob prevQuoteBlob = prevQuote.VersionData;
                String prevQuoteFileName = prevQuote.Title + '.' + prevQuote.FileExtension;

                // Add the existing file to the ZIP archive
                sampleZip.addFile(prevQuoteFileName, prevQuoteBlob, null);
            }
            // Add unsigned files
       		sampleZip = addUnsignedFile(opp,sampleZip);
            // Get the ZIP file as a Blob
            Blob zipBlob = sampleZip.getZipArchive();

            // Create and attach the Zip file to the Opportunity
            ContentVersion newFile = new ContentVersion();
            newFile.Title = 'Opportunity_Docs_Zip_' + DateTime.now();
            newFile.PathOnClient = 'Opportunity_Docs_' + DateTime.now() + '.zip';
            newFile.VersionData = zipBlob;
            newFile.FirstPublishLocationId = oppId;
            insert newFile;
        } catch (Exception e) {
            System.debug('Error in PDF Generation and Zipping: ' + e.getMessage());
        }
    }
    public static void generateARPackage(List<Opportunity> newOpportunities, Map<Id, Opportunity> oldOpportunities) {
        for (Opportunity newOpp : newOpportunities) {
            Opportunity oldOpp = oldOpportunities.get(newOpp.Id);
            if (newOpp.StageName == 'Closed Won' && newOpp.Win_Type__c == 'Auto-Renew' &&
                (oldOpp == null || oldOpp.StageName != 'Closed Won' || oldOpp.Win_Type__c != 'Auto-Renew')) {
                OpportunityARPackageGenerator.generateAndAttachPDF(newOpp.Id);
            }
        }
    }
    @InvocableMethod(label='Generate AR Package' description='Calls the generateARPackage method of the OpportunityARPackageGenerator class.' category='Opportunity')
    public static void generateARPackage(List<Id> lstOppyId) {
        generateAndAttachPDF(lstOppyId[0]);
    }
    private static Zippex addUnsignedFile(Opportunity opp,Zippex sampleZip) {
       	Set<Id> setQuoteId = new Set<Id>();
       	List<ContentDocumentLink> lstCDLs = new List<ContentDocumentLink>();
       	List<ContentVersion> lstCVs = new List<ContentVersion>();
        if(opp.SBQQ__Quotes2__r!=null && !opp.SBQQ__Quotes2__r.isEmpty()) {
            for(SBQQ__Quote__c quote: opp.SBQQ__Quotes2__r) {
                setQuoteId.add(quote.Id);
            }
        }
        lstCDLs = [SELECT ID, ContentDocumentId FROM ContentDocumentLink 
                  WHERE LinkedEntityID IN:setQuoteId and ContentDocument.Title like '%_unsigned%'];
        if(lstCDLs!=null && !lstCDLs.isEmpty()) {
            Set<Id> lstCDIds = new Set<Id>();
            for(ContentDocumentLink cdl : lstCDLs) {
                lstCDIds.add(cdl.ContentDocumentId);
            }
            lstCVs = [SELECT Id, versionData, FileExtension, Title from ContentVersion 
                     WHERE contentDocumentId IN:lstCDIds ];
        }
        if(lstCVs!=null && !lstCVs.isEmpty()) {
            for(ContentVersion cvs: lstCVs) {
                Blob unsignedBlob = cvs.versionData;
                String fileName = cvs.Title ;
                sampleZip.addFile(fileName, unsignedBlob, null);
            } 
        }
        return sampleZip;
    }


}