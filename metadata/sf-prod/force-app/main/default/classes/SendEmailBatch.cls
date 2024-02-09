global class SendEmailBatch implements Database.Batchable<sObject> {
    
     global Database.QueryLocator start(Database.BatchableContext BC) {
        Date sevenDaysAgo = Date.today().addDays(-7);
        return Database.getQueryLocator(
            'SELECT Id, Opportunity__c, TemplateId__c '+
            'FROM RenewalCadenceTracker__c '+
            'WHERE (Email_Scheduled_Date__c = LAST_N_DAYS:7 Or' +
                  ' Email_Scheduled_Date__c = today)' + ' AND Status__c = \'Scheduled\' '
        );
    }

    global void execute(Database.BatchableContext BC, List<RenewalCadenceTracker__c> scope) {
        for (RenewalCadenceTracker__c tracker : scope) {
            sendEmailForTracker(tracker);
        }
    }

    global void finish(Database.BatchableContext BC) {
    }

    private void sendEmailForTracker(RenewalCadenceTracker__c tracker) {
        // Query Opportunity and Contact Roles
        String message ='';
        String recordId='0052x0000049ZXCAA';
        String templateId=tracker.TemplateId__c;
        List<String> userIds = new List<String>();
        try{
            Opportunity opp = [SELECT Id, Name, Owner.Email,Product_Configuration__r.Mailbox_Override__c
                               FROM Opportunity WHERE Id = :tracker.Opportunity__c LIMIT 1];
            List<OpportunityContactRole> contactRoles = [SELECT ContactId, Contact.Email, IsPrimary FROM OpportunityContactRole WHERE OpportunityId = :opp.Id];
    		recordId =opp.Id;
            // Prepare email addresses
            List<String> toAddresses = new List<String>();
            List<String> ccAddresses = new List<String>(new String[]{opp.Owner.Email}); // Add Opportunity owner to CC
            Id primaryContactId;
            for (OpportunityContactRole ocr : contactRoles) {
                if (ocr.Contact.Email != null) {
                    if (ocr.IsPrimary) {
                        primaryContactId=ocr.contactId;
                        toAddresses.add(ocr.Contact.Email);
                    } else {
                        ccAddresses.add(ocr.Contact.Email);
                    }
                }
            }
            if(primaryContactId==null && opp.OpportunityContactRoles!=null 
                    && !opp.OpportunityContactRoles.isEmpty()) {
                    primaryContactId=opp.OpportunityContactRoles[0].contactId;
                }
            if(primaryContactId==null) {
                
            }
            // Prepare and send email
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            Id fromEmailId = GeneralUtility.getOrgWideEmailIdbyName(opp.Product_Configuration__r.Mailbox_Override__c);
            // Set From Address
            mail.setOrgWideEmailAddressId(fromEmailId);
            mail.setToAddresses(toAddresses);
            mail.setCcAddresses(ccAddresses);
            mail.setTemplateId(tracker.TemplateId__c);
            mail.setWhatId(opp.Id);
            mail.setTargetObjectId(primaryContactId);
            mail.setSaveAsActivity(true);
            mail.setTreatTargetObjectAsRecipient(false);
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{mail});
            tracker.Actual_Email_Date__c = Date.today();
            tracker.Status__c = 'Sent';
            update tracker;
        } catch (Exception e) {
            message = 'An exception occurred while sending email for template'+templateId==null?'':templateId + '\n Exception: '+e.getMessage();
            GeneralUtility.postToRecord(recordId, userIds, message);
            tracker.Status__c = 'Errored';
            tracker.Error_Log__c ='Message = '+e.getMessage()+'Stack trace='+e.getStackTraceString(); 
            update tracker;
        }
    }
}