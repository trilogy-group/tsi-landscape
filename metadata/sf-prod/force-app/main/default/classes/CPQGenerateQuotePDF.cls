public with sharing class CPQGenerateQuotePDF {
    public String save(Id quoteId, Id templateId, String name) {
        QuotePDFGeneratorContext ctx = new QuotePDFGeneratorContext(quoteId, templateId, name);
        if (Test.isRunningTest()) { return 'test'; } // Tests does not support callouts
        else { return SBQQ.ServiceRouter.save('SBQQ.QuoteDocumentAPI.Save', JSON.serialize(ctx)); }
    }

    private class QuotePDFGeneratorContext {
        private Id quoteId;
        private Id templateId;
        private String name;

        private QuotePDFGeneratorContext(Id quoteId, Id templateId, String name) {
            this.quoteId = quoteId;
            this.templateId = templateId;
            this.name = name;
        }
    }

    public void GeneratePDFs(List<SBQQ__Quote__c> toGenerate){
        // Select additional fields for the quotes
        List<SBQQ__Quote__c> quoteData = [SELECT Id, Name, SBQQ__QuoteTemplateId__c, SBQQ__Account__c, 
            SBQQ__Account__r.Name, SBQQ__Opportunity2__c, SBQQ__Opportunity2__r.Product__c, 
            SBQQ__Opportunity2__r.Owner.Email, SBQQ__Opportunity2__r.Name, SBQQ__Opportunity2__r.Description
        FROM SBQQ__Quote__c
        WHERE Id IN :toGenerate];
        List<Opportunity> oppToUpdate = new List<Opportunity>();
        for (SBQQ__Quote__c q : quoteData) {
            try {
                String productFamily =q.SBQQ__Opportunity2__r.Product__c;
                if (q.SBQQ__QuoteTemplateId__c == null) {
                    ErrorReporting.notifyViaEmail('Quote PDF Generation: Quote template not found', 
                    String.format('Cannot locate quote template on primary quote for the Quote {0}[{1}]', 
                        new List<String>{q.Name, q.Id}), true);
                    System.debug(String.format('Cannot locate quote template on primary quote for the Quote {0}[{1}]', 
                        new List<String>{q.Name, q.Id}));
                    continue;
                }

                String quoteNumber = q.Name.split('-')[1];
                String documentName = String.format('{0} Quote {1} {2}', 
                    new List<String> {productFamily, quoteNumber, q.SBQQ__Account__r.Name});
                //max lenght is 80
                documentName = documentName.left(76) + '.pdf';

                if (Test.isRunningTest()) {
                    System.debug('Call mocked PDF Generator in test');
                    QuoteDocumentMockGenerator.generateDocument(q.Id, q.SBQQ__Opportunity2__c);
                } else {
                    this.save(q.Id, q.SBQQ__QuoteTemplateId__c , documentName);
                }
            } catch (Exception ex) {
                IEmailService emailService = Injector.getInstance().getEmailService();
                String subject = 'Error generating quote PDF';
                String message = String.format('{0} {1}[{2}]\nOpportunity {3}[{4}]\n{5}\n{6}', new String[] {
                    'An unexpected error happen generating quote PDF document for the Quote', q.Name, q.Id,
                    q.SBQQ__Opportunity2__r.Name, q.SBQQ__Opportunity2__c,
                    'Do not reply to this message. It was sent automatically by salesforce.',
                    'If it is necessary, contact the system administrator.'
                });
                emailService.sendEmail(new String[]{q.SBQQ__Opportunity2__r.Owner.Email}, subject, message);

                message += String.format('\n\nError Message: {0}\nMessage Type: {1}\nStack Trace: {2}', 
                    new String[]{ex.getMessage(), ex.getTypeName(), ex.getStackTraceString()});
                emailService.sendEmailToApexExceptionEmails(subject, message);

                String description = String.format('{0}{1} System: Error generating quote PDF.', 
                    new String[]{
                        String.isBlank(q.SBQQ__Opportunity2__r.Description) ? '' : 
                            q.SBQQ__Opportunity2__r.Description + '\n',
                        DateTime.now().formatGmt('MM/dd/yy')
                    });
                    oppToUpdate.add(new Opportunity(Id = q.SBQQ__Opportunity2__c, Description = description));
            }
        }
        if (oppToUpdate.size() > 0){
            update oppToUpdate;
        }
    }   
}