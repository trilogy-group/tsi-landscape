public without sharing class SFCentralOppDescriptionUpdate implements Database.Batchable<sObject>, Database.Stateful{
    private List<String> errors;
    private Integer totalProcessed;
    private String[] reportEmails;

    String prodFamily;

    /*
        Constructor that has input an array of 
        email addresses as string to send the final report to
        and the product family to filter on
    */
    public SFCentralOppDescriptionUpdate(String productFamily, String[] reportEmails) {
        this.prodFamily = productFamily;
        this.reportEmails = reportEmails;
        this.errors = new List<String>();
        this.totalProcessed = 0;

    }

    /*
        Default start method of Batchable interface  
    */
    public Database.QueryLocator start(Database.BatchableContext bc){

        String query = 'SELECT Id, Description, CreatedDate ' + 
                       'FROM Opportunity WHERE Product__c = \'' + prodFamily + '\'';
        return Database.getQueryLocator(query);
    }

    private void processOpportunities(List<Opportunity> opportunities) {
        for (Opportunity opp : opportunities) {
            if (opp.description == null || opp.description == '') {
                opp.description = '';
            } else {
                opp.description += '\r\n';
            }

            opp.description += String.format('{0}/{1}/{2} System: Opportunity migrated from Central SF:', 
                                    new String[]{ String.valueOf(opp.CreatedDate.month()), 
                                                  String.valueOf(opp.CreatedDate.day()), 
                                                  String.valueOf(opp.CreatedDate.year()).substring(2) });
            opp.description += '\r\n';
            opp.description += '----------------------------------------';
            opp.description += '\r\n';
            List<OpportunityLineItem> lineItems = [SELECT Central_ProductName__c, Central_ProductCode__c, 
                                                          Id, Subscription_Term__c, Quantity, TotalPrice
                                                   FROM OpportunityLineItem
                                                   WHERE  OpportunityId = :opp.Id];
            Integer rowNumber = 1;
            for (OpportunityLineItem item: lineItems) {
                opp.description += String.format('{0}- {1}  {2} T:{3} Q:{4} TP:{5}', 
                                    new String[] {String.valueOf(rowNumber),
                                        item.Central_ProductName__c, 
                                        item.Central_ProductCode__c, 
                                        String.valueOf(item.Subscription_Term__c), 
                                        String.valueOf(item.Quantity), 
                                        String.valueOf(item.TotalPrice)});
                opp.description += '\r\n';
                rowNumber += 1;
            }
            
            opp.description += '----------------------------------------';


            
        }
        try {
            update opportunities;
            this.totalProcessed += opportunities.size();
        } catch (Exception ex) {
            errors.add(ex.getMessage());
        }
    }

    /*
        Batchable database execute method 
    */
    public void execute(Database.BatchableContext bc, List<sObject> opportunities) {
        processOpportunities(opportunities);
    }

    public void finish(Database.BatchableContext bc) {
        sendEmail();
    }

    private void sendEmail() {
        String messageMiddle = 'SFCentralOppDescriptionUpdate';
        String message;
        if (errors.size() == 0) {
            if (totalProcessed == 0) {
                message = 'No opportunities were found to be processed.';
            } else {
                message = String.format('All {0}. Total: {1}.', new String[] 
                    {messageMiddle, String.valueOf(totalProcessed)});
            }
        } else {
            message = String.format('{0} {1}.\r\n\r\n{2}{3}', new String[] {
                String.valueOf(totalProcessed), 
                messageMiddle, 
                'The Following errors happened when processing the batches:\r\n - ', 
                String.join(errors,'\r\n - ')});
        }

        IEmailService emailService = Injector.getInstance().getEmailService();
        emailService.sendEmail(reportEmails, 'SFCentralOppDescriptionUpdate Report', message);
    }
}