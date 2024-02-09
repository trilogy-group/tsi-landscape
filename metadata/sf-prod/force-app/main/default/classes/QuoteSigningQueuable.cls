public with sharing class QuoteSigningQueuable Implements System.Queueable, Database.AllowsCallouts {
    Id quoteDocumentId; // Id in the SBQQ__QuoteDocument__c
    Opportunity oppToUpdate; 
    Id quoteSignerUserId;
    List<echosign_dev1__SIGN_Recipients__c> recipentList = new List<echosign_dev1__SIGN_Recipients__c>();
    public QuoteSigningQueuable(Id quoteIdToSign) {
        System.debug('Document is being sent for signature: ' + quoteIdToSign);
        quoteDocumentId = quoteIdToSign;
    }

    public void execute(System.QueueableContext ctx) {
        requestQuoteDocumentSignature();
    }
    
    // Sending the generated documents for signature
    public void requestQuoteDocumentSignature() {
        if (echoSign()) {
            updateTheOportunityFields();
            update oppToUpdate;
        }
    }

    // Send with EchoSign
    public Boolean echoSign(){
        System.debug('--------- Sending the quote document ---------');
        SBQQ__QuoteDocument__c quoteDoc = [SELECT 
            SBQQ__DocumentId__c,
            Name,
            SBQQ__Opportunity__r.Name,
            SBQQ__Opportunity__r.OwnerId,
            SBQQ__Opportunity__r.Owner.Email,
            SBQQ__Opportunity__r.ContactId,
            SBQQ__Opportunity__r.Product__c,
            SBQQ__Opportunity__r.Product_Configuration__c, 
            SBQQ__Opportunity__r.Product_Configuration__r.Quote_Signer__c,                               
            SBQQ__Opportunity__r.Description,
            SBQQ__Opportunity__r.Id,
            SBQQ__Quote__r.SBQQ__ExpirationDate__c,
            SBQQ__Quote__r.SBQQ__PrimaryContact__c
            FROM SBQQ__QuoteDocument__c
            WHERE Id=:quoteDocumentId LIMIT 1];
        echosign_dev1__SIGN_Agreement__c agreementRec = createAgreementRecord(quoteDoc);
        if (agreementRec != null) {
            sendEchoSignAgreement(agreementRec.Id, oppToUpdate.Id, oppToUpdate.Name, oppToUpdate.Owner.Email);
        }
        return agreementRec != null;
    }

    public echosign_dev1__SIGN_Agreement__c createAgreementRecord(SBQQ__QuoteDocument__c quoteDoc) {
        oppToUpdate = quoteDoc.SBQQ__Opportunity__r;
        
        Document attachmentDoc = null;        
        if (Test.isRunningTest()) {
            System.debug('test document is used');
            attachmentDoc = new Document(Name='Test', Body = EncodingUtil.base64Decode('Test'));
        } else {        
            System.debug('quoteDoc: ' + quoteDoc);
            attachmentDoc = [SELECT Name, Body FROM Document WHERE Id=:quoteDoc.SBQQ__DocumentId__c LIMIT 1];
        }        
        
        System.debug('Attachment doc: ' + attachmentDoc);
        Blob pdfBody = attachmentDoc.Body;

        String documentName = quoteDoc.Name;
        documentName = documentName.replace('.pdf', ''); // Remove unnecessary extension
        documentName = documentName.replace('.pdf', '');
        System.debug('documentName: ' + documentName);

        String ccEmails = quoteDoc.SBQQ__Opportunity__r.Owner.Email; // Owner should be in CC
        // Build Echosign agreement record
        Id primaryContactId = quoteDoc.SBQQ__Quote__r.SBQQ__PrimaryContact__c;
        // If the quote does not have a primary contact, use the primary contact from the opportunity
        if (primaryContactId == null) { 
            primaryContactId = quoteDoc.SBQQ__Opportunity__r.ContactId; 
        }
        Contact primaryContact = [SELECT Email
            FROM Contact
            WHERE Id=:primaryContactId];
        System.debug('primaryContact: ' + primaryContact);

        if(quoteDoc.SBQQ__Opportunity__r.Product_Configuration__r.Quote_Signer__c != null) {
            quoteSignerUserId = quoteDoc.SBQQ__Opportunity__r.Product_Configuration__r.Quote_Signer__c;
        }

        echosign_dev1__SIGN_Agreement__c agreementRec = new echosign_dev1__SIGN_Agreement__c();
        agreementRec.Name = documentName;
        agreementRec.echosign_dev1__Signaturetype__c = 'e-Signature';
        
        //Commenting out the receipent from Agreement as we need 2 signatures and we will be using the recipent object
        /*agreementRec.echosign_dev1__Recipient_Addresses__c    = primaryContact.Email;
        agreementRec.echosign_dev1__Recipient__c = primaryContactId; */

        agreementRec.echosign_dev1__Cc__c = ccEmails;        
        agreementRec.echosign_dev1__Opportunity__c = quoteDoc.SBQQ__Opportunity__r.Id;
        agreementRec.echosign_dev1__Message__c = '';
        agreementRec.echosign_dev1__SignatureOrder__c = '';
        agreementRec.echosign_dev1__Signature_Flow__c = null;
        agreementRec.echosign_dev1__Signing_Deadline__c  = quoteDoc.SBQQ__Quote__r.SBQQ__ExpirationDate__c;
        agreementRec.echosign_dev1__Sender_User__c = quoteDoc.SBQQ__Opportunity__r.OwnerId;
        agreementRec.OwnerId = quoteDoc.SBQQ__Opportunity__r.OwnerId;
        try {
            insert agreementRec;
            
            // Add receipents 
            echosign_dev1__SIGN_Recipients__c rec1 = new echosign_dev1__SIGN_Recipients__c();
            rec1.echosign_dev1__useEmailAddress__c = true;
            rec1.echosign_dev1__Recipient_Type__c = 'Contact';
            rec1.echosign_dev1__Contact__c = primaryContactId;
            rec1.echosign_dev1__Order_Number__c = 1;
            rec1.echosign_dev1__Recipient_Message__c = '';
            rec1.echosign_dev1__Agreement__c = agreementRec.Id;
            recipentList.add(rec1);
            //insert rec1;
            
            // We will only add 2nd receipent if the Product Configutation has Quote Signer set
            if(quoteDoc.SBQQ__Opportunity__r.Product_Configuration__r.Quote_Signer__c != null) {
                echosign_dev1__SIGN_Recipients__c rec2 = new echosign_dev1__SIGN_Recipients__c();
                rec2.echosign_dev1__useEmailAddress__c = true;
                rec2.echosign_dev1__Recipient_Type__c = 'User';
                rec2.echosign_dev1__User__c = quoteSignerUserId;
                rec2.echosign_dev1__Order_Number__c = 2;
                rec2.echosign_dev1__Recipient_Message__c = '';
                rec2.echosign_dev1__Agreement__c = agreementRec.Id;
            	recipentList.add(rec2);
                //insert rec2;  
            }
            if(recipentList.size() > 0) {
                insert recipentList;
            }
           
            
        } catch (Exception ex) {
            Boolean quoteExpired = quoteDoc.SBQQ__Quote__r.SBQQ__ExpirationDate__c < Date.today();
            String subject = 'Error generating agreement';
            subject += quoteExpired ? ' - quote expired' : '';
            String message = String.format('Opportunity: {0} - {1}\n{2}/{0}\n\n{3}{4}{5}\n\n{6}',new string[] {
                oppToUpdate.Id,
                oppToUpdate.Name,
                URL.getSalesforceBaseUrl().toExternalForm(),
                quoteExpired ? 'The quote has expired' : 'An error happened when generating agreement',
                ', agreement was not created and was not sent.',
                quoteExpired ? '' : '\nError: ' + ex.getMessage(),
                'This message was sent automatically by salesforce. Do not reply.'
            });
            IEmailService emailService = Injector.getInstance().getEmailService();
            emailService.sendEmail(new String[]{oppToUpdate.Owner.Email,getApproverEmail()}, subject, message);
         
            return null;
        }
        System.debug('Agreement inserted, Id: ' + agreementRec.Id);

        Attachment pdfFile = new Attachment();
        pdfFile.isPrivate       = false;
        pdfFile.body            = pdfBody;
        pdfFile.parentId        = agreementRec.id;
        pdfFile.Name            = attachmentDoc.Name;
        insert pdfFile;
        System.debug('Attachment inserted, Id: ' + pdfFile.Id);
        return agreementRec;
    }

    @future (callout=true)
    // Since this update causes a callout we need to move it to a @future method
    public static void sendEchoSignAgreement(Id agreementId, Id oppId, String oppName, String ownerEmail) { 
        echosign_dev1.EchoSignApiService.SendDocumentResult result = echosign_dev1.EchoSignApiService.sendDocument(agreementId);    
        // Callouts from triggers are not supported as we use this form trigger
        /*update new echosign_dev1__SIGN_Agreement__c (Id = agreementId, 
        echosign_dev1__Background_Action__c ='Send');*/
        if (result.error != null) {
            String subject = 'Error when sending document to sign';
            String message = String.format('Opportunity: {0} - {1}\n{2}/{0}\n\n{3}\nError: {4}\n\n{5}',new string[] {
                oppId,
                oppName,
                URL.getSalesforceBaseUrl().toExternalForm(),
                'An error happened when sending document to sign.',
                result.error.getMessage(),
                'This message was sent automatically by salesforce. Do not reply.'
            });
            IEmailService emailService = Injector.getInstance().getEmailService();
            emailService.sendEmail(new String[]{ownerEmail,getApproverEmail()}, subject, message);
        }
        System.debug('Agreement is queued for sending. ' + result);
    }
    
    public void updateTheOportunityFields() {
        oppToUpdate.StageName = 'Quote Follow-Up';
        String message = String.format('{0}/{1} Primary quote has been sent to the client.\r\n', new String[]{ String.valueOf(System.today().month()), String.valueOf(System.today().day())});
        if(oppToUpdate.Description == null){ // Avoid the 'null' string in the case of empty description
            oppToUpdate.Description = '';
        }
        oppToUpdate.Description = message + oppToUpdate.Description;
    }

    // Initiate signing for the given documents
    public static void EnqueueSigningTasks(List<SBQQ__QuoteDocument__c> documents){
        documents = filterDocuments(documents); // Ensure that we're sending documents for correct quotes
        for (SBQQ__QuoteDocument__c document : documents){
            System.enqueueJob(new QuoteSigningQueuable(document.Id));  
        }
    }

    // Allow only documents for Primary quotes which are Accepted
    private static List<SBQQ__QuoteDocument__c> filterDocuments(List<SBQQ__QuoteDocument__c> documents){        
        return [SELECT Id 
        FROM SBQQ__QuoteDocument__c 
        WHERE Id IN :documents 
        AND SBQQ__Quote__r.SBQQ__Primary__c = True 
        AND SBQQ__Quote__r.SBQQ__Status__c = 'Accepted' 
        AND SBQQ__Quote__r.SBQQ__Opportunity2__r.Product_Configuration__r.Manual_Quote__c = False
        AND SBQQ__Quote__r.SBQQ__Opportunity2__r.Product_Configuration__r.Processed_via_OTC__c = False
        ];
    }

    private static String getApproverEmail(){
        // the approver is the current user
        Id id = UserInfo.getUserId();
        User approver = [Select Email From User where Id = :id limit 1];
        return approver.Email;
    }
}