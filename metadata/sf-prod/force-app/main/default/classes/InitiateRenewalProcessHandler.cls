/***
* @description: LAMBDA-65516 process handler to send intro email on platform event creation
* */
public with sharing class InitiateRenewalProcessHandler {

    static List<ApexLogger__c> lstAllApexLogs = new List<ApexLogger__c>();
    static final string templateIdWithLink = [SELECT ID, Name FROM EmailTemplate 
                                              WHERE DeveloperName =: System.Label.IntroTemplateWithLink limit 1][0].Id ;
    static final string templateIdWithoutLink = [SELECT ID, Name FROM EmailTemplate 
                                                  WHERE 
                                                    DeveloperName =: System.Label.IntroTemplateWithoutLink limit 1][0].Id;
    static final List<String> defaultErrorRecepients = new List<String>{'0052x0000049ZXCAA2','0052x000003dkbXAAQ'};
    static final string communityId = [SELECT ID,name from Network WHERE Name = 'Customer Portal'].Id;
    public static void handleEventInsert (List<Initiate_Renewal_Process__e> lstNewList) {
        Savepoint sp = Database.setSavepoint();
        Set<Id> oppyIdsToProcess = new Set<Id>();
        try {
            if(lstNewList!=null && !lstNewList.isEmpty()) {
                for(Initiate_Renewal_Process__e irp : lstNewList) {
                    if(irp.Opportunity_18_Digit_Id__c!=null) {
                        oppyIdsToProcess.add(irp.Opportunity_18_Digit_Id__c);
                    }
                }
            }
            System.debug('==oppyIdsToProcess=='+oppyIdsToProcess);
            if(oppyIdsToProcess!=null && !oppyIdsToProcess.isEmpty()) {
                processOpportunities(oppyIdsToProcess);
            }
        } catch (Exception ex) {
            Database.rollback(sp);
            System.debug('==exception occurred=='+ex.getMessage());
             GeneralUtility.postToRecord(defaultErrorRecepients[0],
                                        defaultErrorRecepients,
                                        'Errored oppies: '+ex.getMessage()+oppyIdsToProcess);
        } 
    }
    @testVisible
    private static void processOpportunities(Set<Id> opportunityIds) {
        List<SurveyInvitation> lstSurInvToIns = new List<SurveyInvitation>();
        List<Opportunity> lstOppToUpdate = new List<Opportunity>();
        List<Opportunity> lstValidOpportunities = new List<Opportunity>();
        List<RenewalCadenceTracker__c> lstTrackerRecords = new List<RenewalCadenceTracker__c>();
        //query opportunities to process
        List<Opportunity> lstOpportunityToProcess = [SELECT Id, Account.Name, Name, Product__c,StageName,
                                            Product_Configuration__r.Intro_Survey__c,
                                            Product_Configuration__c,Product_Configuration__r.Mailbox_Override__c,
                                            Last_Survey_URL__c,
                                            (SELECT Id, contact.Email, contactId From 
                                            OpportunitycontactRoles WHERe isPrimary=true
                                            and contact.Email!=null),
                                            Owner.email,Owner.Name
                                            from Opportunity WHERE Id IN :opportunityIds 
                                            and Product__c!=null and isClosed=false and StageName!='Pending' 
                                            and Id NOT IN (SELECT OpportunityId from 
                                            OpportunityPartner WHERE AccountToId!=null)
                                            and type = 'Renewal' and Last_Survey_URL__c=null
                                            and Owner.UserRole.Name = 'ISR Renewals'
                                           ];
        System.debug('==lstOpportunityToProcess=='+lstOpportunityToProcess);
        
        lstValidOpportunities = validateOpportunities(lstOpportunityToProcess);
        System.debug('==lstValidOpportunities=='+lstValidOpportunities);
        if(lstValidOpportunities==null || lstValidOpportunities.isEmpty()) {
            return;
        }
        for(Opportunity opp: lstValidOpportunities) {
            if(opp.Product_Configuration__c!=null && 
               opp.Product_Configuration__r.Intro_Survey__c!=null) {
               //generate survey invitation
               lstSurInvToIns.add(generateSurveyInvitation(opp));
               lstTrackerRecords.add(generateCadenceRec(opp,templateIdWithLink,Date.Today()));  
               } else{
                   Opportunity tempOpp = new Opportunity(
                                   Id=opp.Id,
                                   Last_Survey_URL__c = 'https://localhost'
                   );
                   lstOppToUpdate.add(tempOpp);
                   lstTrackerRecords.add(generateCadenceRec(opp,templateIdWithoutLink,Date.Today())); 
               }
        }
        if(lstSurInvToIns!=null && !lstSurInvToIns.isEmpty()) {
            insert lstSurInvToIns;
            lstOppToUpdate.addAll(updateSurveyURLS(lstSurInvToIns));
        }
        if(lstOppToUpdate!=null && !lstOppToUpdate.isEmpty()) {
            update lstOppToUpdate;
            sendEmails(lstValidOpportunities);
        }
        if(lstTrackerRecords!=null && !lstTrackerRecords.isEmpty()) {
            insert lstTrackerRecords;
        }
        
    }
    @testVisible
    private static SurveyInvitation generateSurveyInvitation(Opportunity opp) {
        SurveyInvitation surInv = new SurveyInvitation();
        surInv.SurveyId = opp.Product_Configuration__r.Intro_Survey__c;
        surInv.ParticipantId = opp.OpportunitycontactRoles[0].contactId;
        surInv.OptionsAllowParticipantAccessTheirResponse = false;
        surInv.OptionsCollectAnonymousResponse = false;
        surInv.OptionsAllowGuestUserResponse = true;
        surInv.Opportunity__c = opp.Id;
        surInv.CommunityId = communityId;
        surInv.Name = opp.OpportunitycontactRoles[0].contact.email;
        return surInv;
    }
    private static void sendEmails(List<Opportunity> lstOpportunity) {
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        for(Opportunity opp : lstOpportunity) {
            String templateId =templateIdWithoutLink;
            if(opp.Product_Configuration__r.Intro_Survey__c!=null) {
                templateId = templateIdWithLink;
            }
            Messaging.SingleEmailMessage email = generateEmail(opp, templateId);
            if(email != null) {
                emails.add(email);
            }
        } 
    if(emails!=null && !emails.isEmpty()) {
            Messaging.sendEmail(emails);
        }        
    }
    private static Messaging.SingleEmailMessage generateEmail (Opportunity opp, Id templateId) {
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            // Retrieve the OrgWideEmailAddress using product configuration
            Id fromEmailId = GeneralUtility.getOrgWideEmailIdbyName(opp.Product_Configuration__r.Mailbox_Override__c);
            mail.setOrgWideEmailAddressId(fromEmailId);
            Id primaryContactId;
            List<String> toAddresses = new List<String>();
            List<String> ccAddresses = new List<String>();
            toAddresses.add(opp.OpportunityContactRoles[0].Contact.Email);
            primaryContactId = opp.OpportunityContactRoles[0].contactId;
            mail.setToAddresses(toAddresses);
            ccAddresses.add(opp.Owner.Email);
            mail.setCcAddresses(ccAddresses);
            mail.setTemplateId(templateId);
            mail.setWhatId(opp.Id);
            mail.setTargetObjectId(primaryContactId);
            mail.setSaveAsActivity(true);
            mail.setTreatTargetObjectAsRecipient(false);
            // Send Email
        return mail;
    }
    @testVisible
    private static List<Opportunity> updateSurveyURLS(List<SurveyInvitation> lstSurveyInvs) {
        Map<Id,SurveyInvitation> mapSurveyInvs = new Map<Id,SurveyInvitation>(lstSurveyInvs);
        List<Opportunity> lstOpportunityToUpdate = new List<Opportunity>();
        List<SurveyInvitation> lstSurveyInvsToQuery = [SELECT Id, Opportunity__c, InvitationLink  
                                                       from SurveyInvitation WHERE ID In: mapSurveyInvs.keySet()];
        for(SurveyInvitation survInv : lstSurveyInvsToQuery) {
            Opportunity tempOpp = new Opportunity(Id=survInv.Opportunity__c,
                                                  Last_Survey_URL__c = survInv.InvitationLink);
            lstOpportunityToUpdate.add(tempOpp);
        }
        return lstOpportunityToUpdate;
    }
    @testVisible
    private static List<Opportunity> validateOpportunities(List<Opportunity> lstOpportunityToValidate) {
        List<Opportunity> lstValidOpportunity = new List<Opportunity>();
        List<OpportunityChatterWrapper> lstChatterMsgs = new List<OpportunityChatterWrapper>();
        List<String> lstUserIds = new List<String>();
        lstUserIds.addAll(defaultErrorRecepients);
        for(Opportunity opp: lstOpportunityToValidate) {
            Boolean isValid = true;
            String message = '';
            if(opp.OpportunitycontactRoles==null || opp.OpportunitycontactRoles.isEmpty()) {
            //add chatter message primary contact missing
              isValid = false;
                message +='The first email from the renewal sequence - "Critical: '+opp.Account.Name;
                message += '- Your Contact for '+ opp.Product__c+' Renewal" ';
                message += 'was not sent out because a Primary Contact with a valid email was not found. '; 
                message += 'The email sending will be reattempted once the primary contact has been updated. @';
                message += opp.owner.Name+' please update the contact details asap.';
          }
            Id fromEmailId = GeneralUtility.getOrgWideEmailIdbyName(opp.Product_Configuration__r.Mailbox_Override__c);
            System.debug('==fromEmailId=='+fromEmailId);
            if(fromEmailId==null) {
                //add chatter
                isValid = false;
                message += 'Valid renewals mailbox not found';
            }
            if(isValid) {
                lstValidOpportunity.add(opp);
            }
            if(!isValid) {
                lstUserIds.add(opp.OwnerId);
                OpportunityChatterWrapper ocw = new OpportunityChatterWrapper();
                ocw.opportunityId = opp.Id;
                ocw.userIds = lstUserIds;
                ocw.customMessage = message;
                lstChatterMsgs.add(ocw);
            }
        }
        if(lstChatterMsgs!=null && !lstChatterMsgs.isEmpty()) {
            GeneralUtility.postChatterInBulk(lstChatterMsgs);
        }
        return lstValidOpportunity;
    }
    @testVisible
    private static RenewalCadenceTracker__c generateCadenceRec(Opportunity opp, Id templateId, Date scheduledDate) {
		RenewalCadenceTracker__c tracker = new RenewalCadenceTracker__c();
        try {
            tracker.Opportunity__c = opp.Id;
        	tracker.TemplateId__c = templateId;
            tracker.status__c = 'Sent';
            tracker.Email_Scheduled_Date__c = scheduledDate;
            tracker.Actual_Email_Date__c = scheduledDate;
            String name = opp.Name + '_' + templateId;
            tracker.Name = name.left(80).trim();
            
            
        } catch (Exception ex) {
            String message = 'Error occurred while creating tracker record ='+ex.getMessage() + ' oppId='+opp.Id;
            GeneralUtility.postToRecord(defaultErrorRecepients[0],
                                        defaultErrorRecepients,
                                        message);
        }
        System.debug('==tracker records=='+tracker);
		return tracker;        
    }
}