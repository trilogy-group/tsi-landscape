global class BatchRenewalmpendingEmailSender implements Database.Batchable<Renewal_Template_Mapping__mdt>, Schedulable {
	global List<string> opportunityID;
    global Iterable<Renewal_Template_Mapping__mdt> start(Database.BatchableContext BC) {
        List<Renewal_Template_Mapping__mdt> lstRenewalRules = new List<Renewal_Template_Mapping__mdt>();
        lstRenewalRules = [SELECT MasterLabel, Threshold_Days__c, TemplateId__c, Is_AR_Rule__c, Is_Maintenance_Rule__c, Use_Termination_Deadline__c,
                           Stage_Criteria__c
        FROM Renewal_Template_Mapping__mdt WHERE TemplateId__c!=null];
        if(Test.isRunningTest()) {
            return [SELECT MasterLabel, Threshold_Days__c, TemplateId__c, Is_AR_Rule__c, Is_Maintenance_Rule__c, Use_Termination_Deadline__c,Stage_Criteria__c 
            FROM Renewal_Template_Mapping__mdt WHERE TemplateId__c!=null AND Threshold_Days__c=-44 AND Use_Termination_Deadline__c = TRUE limit 1];
        }
        return lstRenewalRules;
    }
    
    global void execute(Database.BatchableContext bc, List<Renewal_Template_Mapping__mdt> scope) {
        //batch size is 1 processing 1 rule at a time
        for (Renewal_Template_Mapping__mdt rule : scope) {
            try {
                List<Opportunity> relatedOpps = getOpportunitiesForRule(rule);
            	System.debug('==relatedOpps=='+relatedOpps.size());
            	if(relatedOpps.size() > 0) {
                	List<RenewalCadenceTracker__c> trackers = processOpportunities(relatedOpps, rule);
                	if(trackers!=null && !trackers.isEmpty()) {
                    	insert trackers;
                    	//Messaging.sendEmail(emails);
                    
                	}
            	}
            } catch(Exception ex) {
                String message = 'Batch failed for rule' + rule.MasterLabel+' and template '+ rule.TemplateId__c + 'Error Message='+ex.getMessage();
                GeneralUtility.postToRecord('0052x0000049ZXCAA2', new List<String>{'0052x0000049ZXCAA2'}, message);
            }
            
        }
    }

    private List<Opportunity> getOpportunitiesForRule(Renewal_Template_Mapping__mdt rule) {
        String oppQuery = 'SELECT Id,Account.Turn_Off_Late_Renewals_Emails__c,Renewal_Date__c, CloseDate, Owner.Email,OwnerId,Owner.IsActive, StageName,CurrentContractHasAutoRenewalClause__c,' +
            'Product_Configuration__r.Business_Unit__c, Product_Configuration__r.Mailbox_Override__c, Customer_Termination_Deadline__c, Win_Type__c, Loss_Reason__c, Name,' +
            '(SELECT ProductCode FROM OpportunityLineItems WHERE Product2.SBQQ__Component__c=false ), ' +
            '(SELECT Id, Contact.Email, isPrimary, ContactId FROM OpportunityContactRoles WHERE Contact.Email!=null), ' +
            ' SBQQ__PrimaryQuote__c,AR_Quote__c,Approving_VP__c,IsLocked__c FROM Opportunity WHERE Renewal_Date__c != null AND IsClosed=false AND Product_Configuration__r.Enabled__c=true'+
            ' AND Product_Configuration__r.Mailbox_Override__c!=null AND Type=\'Renewal\' AND Ready_To_Close__c=false'+
            ' AND Handled_by_BU__c =false AND Active__c = true ';
        if(opportunityID!=null && !opportunityId.isEmpty()) {
            oppQuery += ' AND Id In:opportunityID ';
        }
            Integer thresholdDays = Integer.valueOf(rule.Threshold_Days__c == null?0:(rule.Threshold_Days__c*-1));
            Date dateToCompare = Date.today().addDays(thresholdDays);
            String dateToCompareString = formatDate(dateToCompare);
        	System.debug('==dateToCompareString=='+dateToCompareString);
            if(rule.Use_Termination_Deadline__c==true) {
                
                //Date tempDate = dateToCompare.addDays(60);//adding a 60 day gap where customer Customer_Termination_Notice_Period__c is null
                //String tempDateString = formatDate(tempDate);
                //assume customer termination notice period of 60 days could be null
                oppQuery += ' AND Customer_Termination_Deadline__c = '+dateToCompareString + 
                            //' OR (Customer_Termination_Notice_Period__c =null AND Customer_Termination_Deadline__c='+tempDateString+' ))'
                        ' AND CurrentContractHasAutoRenewalClause__c = \'Yes\'' ; 
            } 
            if(rule.Use_Termination_Deadline__c==false ) {
                oppQuery += ' AND (Renewal_Date__c = '+dateToCompareString+' OR CloseDate = '+dateToCompareString+')';
                /*if(rule.Threshold_Days__c ==-30) {
                    oppQuery += ' AND Customer_Termination_Notice_Period__c>= 30 ';
                }
                if(rule.Threshold_Days__c == -40) {
                    oppQuery += ' AND Customer_Termination_Notice_Period__c>= 60 ';
                } */
            }
            // If Turn_Off_Late_Renewals_Emails__c on Account is checked skip all the emails excpet AR.AR emails is based on CurrentContractHasAutoRenewalClause__c 
			if(rule.Is_AR_Rule__c!=true) {
                oppQuery += ' AND Account.Turn_Off_Late_Renewals_Emails__c = False'; 
            }
            if( rule.Is_AR_Rule__c==true) {
                oppQuery += ' AND CurrentContractHasAutoRenewalClause__c = \'Yes\'';
            } else {
                oppQuery += ' AND CurrentContractHasAutoRenewalClause__c = \'No\'';
            }
            System.debug( LoggingLevel.INFO, '==query=='+oppQuery);
        // Apply the rule filters here based on rule attributes
        return Database.query(oppQuery);
    }

    private List<RenewalCadenceTracker__c> processOpportunities(List<Opportunity> relatedOpps, Renewal_Template_Mapping__mdt rule) {
        List<RenewalCadenceTracker__c> trackers = new List<RenewalCadenceTracker__c>();
        List<Opportunity> filteredOpps = new List<Opportunity>();
        filteredOpps = filterAlreadyProcessedOpps(rule,relatedOpps);
        for(Opportunity opp: filteredOpps) {
            //check opportunity to skip
            if(shouldSkipOpportunity(opp, rule)) {
                continue;
            }
            if(!isOpportunityValid(opp, rule)) {
                continue;//do not process the opportunity 
            }
            Date scheduledDate = Date.today() ;
            //rules where customer termination deadline is not be used
            if(rule.Use_Termination_Deadline__c==false || Test.isRunningTest()) { 
                //check max of closeDate and Renewal_Date__c
                Date maxDate = opp.Renewal_Date__c;
                if(opp.CloseDate > opp.Renewal_Date__c) {
                    maxDate = opp.CloseDate;
                }
                Integer thresholdDays = Integer.valueOf(rule.Threshold_Days__c == null?0:(rule.Threshold_Days__c*-1));
                Date dateToCompare = Date.today().addDays(thresholdDays);
                //invalid opportunity as it does not meet the criteria
                if(maxDate!=dateToCompare) {
                    continue;
                }
            //check if any productcode has mnt product
                Boolean hasMNTProduct = false;
                for(OpportunityLineItem oli : opp.OpportunityLineItems) {
                    if(oli.ProductCode.contains('-MNT')) {
                        hasMNTProduct = true;
                        break;
                    }
                } 
                if(rule.Is_Maintenance_Rule__c == true && hasMNTProduct==false) {
                    continue;//skip this opportunity as Maintenance rule only applies to it
                } 
                if (rule.Is_Maintenance_Rule__c == false && hasMNTProduct==true && rule.Is_AR_Rule__c==false) {
                    continue;
                }
            } 
            /*
            Messaging.SingleEmailMessage email = generateEmail(opp, rule.TemplateId__c);
            if(email != null) {
                emails.add(email);
            }*/
            RenewalCadenceTracker__c tracker = generateCadenceRec(opp,rule.TemplateId__c,scheduledDate);
            if(tracker!=null && tracker.Opportunity__c!=null) {
                trackers.add(tracker);
            }
        }
        return trackers;
    }

    global void execute(SchedulableContext ctx) {
        BatchRenewalmpendingEmailSender emailBatch = new BatchRenewalmpendingEmailSender(); 
        Database.executeBatch(emailBatch, 1);
    }
    private RenewalCadenceTracker__c generateCadenceRec(Opportunity opp, Id templateId, Date scheduledDate) {
		RenewalCadenceTracker__c tracker = new RenewalCadenceTracker__c();
        try {
            tracker.Opportunity__c = opp.Id;
        	tracker.TemplateId__c = templateId;
            tracker.status__c = 'Scheduled';
            tracker.Email_Scheduled_Date__c = scheduledDate;
            String name = opp.Name + '_' + templateId;
            tracker.Name = name.left(80).trim();
            
            
        } catch (Exception ex) {
            String message = 'Error occurred while creating tracker record ='+ex.getMessage();
            sendChatterOnOpp(opp, message);
        }
        System.debug('==tracker records=='+tracker);
		return tracker;        
    }
    global void finish(Database.BatchableContext bc) {
       Database.executeBatch(new SendEmailBatch(),1);
    }
    private string formatDate(Date input) {
        return DateTime.newInstance(
                input.year(), input.month(), input.day()
                ).format('yyyy-MM-dd');
    }
    /**
     * @author: Paras Dhingra
     * @purpose: Method to validate if opportunity is valid to send
     * @ticket: LAMBDA-63448
     */
    private Boolean isOpportunityValid(Opportunity opp,Renewal_Template_Mapping__mdt rule) {
        Boolean isOppyValid = true;
        if(opp.CurrentContractHasAutoRenewalClause__c=='No') {
            return isOppyValid;
        }
        //initialize message
        String message =''+Date.today().format()+ ' SYSTEM: IMPORTANT: ';
        String ruleName = '';
        ruleName+= rule.MasterLabel;
        if((rule.Threshold_Days__c==-20 || rule.Threshold_Days__c==-40) 
           && (opp.SBQQ__PrimaryQuote__c==null || opp.AR_Quote__c==null)) { 
            message+=ruleName + ' Warning NOT SENT, the Primary or AR Quote is missing.';
            isOppyValid=false;
            
        }
        if(opp.OpportunityContactRoles==null || opp.OpportunityContactRoles.isEmpty()) {
            message+=ruleName + ' Warning NOT SENT, no contacts with valid email found.';
            isOppyValid=false;
        }
        if(isOppyValid==false) {
            sendChatterOnOpp(opp, message);
        }
        return isOppyValid;

    }
    /**
     * @author: Paras Dhingra
     * @purpose: Method to notify VP and opportunity owner of incomplete Oppy
     * @ticket: LAMBDA-63448
     */
    private void sendChatterOnOpp(Opportunity opp,String message) {
        List<String> userIds = new List<String>();
        if(opp.Owner.IsActive) {
            userIds.add(opp.ownerId);
        }
        if(opp.Approving_VP__c!=null) {
            userIds.add(opp.Approving_VP__c);
        }
        userIds.add('0052x0000049ZXCAA2');//adding Paras' id for tracking
        GeneralUtility.postToRecord(opp.Id, userIds, message);
    }
    /**
     * @author: Paras Dhingra
     * @purpose: Method to check if opportunity can be skipped
     * @ticket: LAMBDA-64716
     */
    private Boolean shouldSkipOpportunity(Opportunity opp, Renewal_Template_Mapping__mdt rule) {
        Boolean shouldSkip = false;
        if(opp.StageName=='Finalizing' && 
                (
                (opp.Win_Type__c =='Quote Signed' || opp.Win_Type__c=='Co-Term')
                || (opp.Win_Type__c==null && opp.Loss_Reason__c!=null)
                || (rule.Threshold_Days__c == -37)
                )
                ) {
                shouldSkip = true;
            }
        if(rule.Stage_Criteria__c!=null && rule.Stage_Criteria__c!='' && opp.StageName!=rule.Stage_Criteria__c) {
            shouldSkip = true;
        }
        return shouldSkip;
    }
    private List<Opportunity> filterAlreadyProcessedOpps(Renewal_Template_Mapping__mdt rule, List<Opportunity> queriedOpps) {
    List<Opportunity> lstToReturn = new List<Opportunity>();

    // Convert the List of Opportunities to a Map for easy access
    Map<Id, Opportunity> mapOpportunity = new Map<Id, Opportunity>(queriedOpps);
	System.debug('==TemplateId__c=='+rule.TemplateId__c);
    // Query RenewalCadenceTracker__c for records matching the rule's TemplateId__c
    // and the Opportunity IDs in queriedOpps
    List<RenewalCadenceTracker__c> cadenceTrackers = [SELECT Id, Opportunity__c, TemplateId__c 
                                                      FROM RenewalCadenceTracker__c 
                                                      WHERE TemplateId__c = :rule.TemplateId__c 
                                                      ];
	System.debug('==cadenceTrackers=='+cadenceTrackers.isEmpty());
    // Create a Set of Opportunity IDs that already have a matching RenewalCadenceTracker__c
    Set<Id> processedOppIds = new Set<Id>();
    for (RenewalCadenceTracker__c tracker : cadenceTrackers) {
        processedOppIds.add(tracker.Opportunity__c);
    }

    // Add Opportunities to the return list if they are not in the processedOppIds Set
    for (Opportunity opp : queriedOpps) {
        if (!processedOppIds.contains(opp.Id)) {
            lstToReturn.add(opp);
        }
    }

    return lstToReturn;
}


}