public without sharing class UpdateOpportunitiesBatch implements Database.Batchable<sObject>, Database.Stateful {

    private List<String> errorsList;
    private Integer totalProcessed;
    private String[] reportEmails;

    /*  
        Constructor that has input an array of 
        email addresses as string to send the final report to
    */
    public UpdateOpportunitiesBatch(String[] reportEmails) {
        this.reportEmails = reportEmails;
    }

    /*
        get total number of records processed 
    */
    public Integer getTotalProcessed() {
        return totalProcessed;
    }

    /*
        Default start method of Batchable interface  
    */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        errorsList = new List<String>();
        totalProcessed = 0;
        // update all opportunities 
        return Database.getQueryLocator('SELECT Id FROM Opportunity');
    }

    /*
        Batchable database execute method 
    */
    public void execute(Database.BatchableContext bc, List<sObject> scope) {
        List<Opportunity> oppsToUpdate = new List<Opportunity>();
        for(sObject s : scope){
            Opportunity opp =  (Opportunity) s;
            oppsToUpdate.add(opp);
        }
        try {
            totalProcessed += oppsToUpdate.size();
            database.SaveResult[] myResult=database.update(oppsToUpdate,false);
            for(Integer i=0; i < myResult.size(); i++) {
                if(!myResult.get(i).isSuccess()) {
                Database.Error errors =  myResult.get(i).getErrors().get(0);
                errorsList.add('Opportunity ID=' + oppsToUpdate.get(i).Id + ' error:' + errors.getMessage());
                }
            }
        } catch (Exception ex) {
            errorsList.add(ex.getMessage());
        }
    }

    public void finish(Database.BatchableContext bc) {
        sendEmail();
    }

    private void sendEmail() {
        String messageMiddle = 'opportunities updated';
        String message;
        if (errorsList.size() == 0) {
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
                String.join(errorsList,'\r\n - ')});
        }
            
        IEmailService emailService = Injector.getInstance().getEmailService();
        emailService.sendEmail(reportEmails, 'UpdateOpportunitiesBatch Report', message);
    }

}