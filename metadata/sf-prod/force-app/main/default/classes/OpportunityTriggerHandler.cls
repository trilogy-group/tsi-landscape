/**
 * @author: Paras Dhingra
 * @description: Handler class for Opportunity trigger. All logic should be in this and triggers should be logicless
 */
public with sharing class OpportunityTriggerHandler {
    /**
    * description: LAMBDA-40414 Method to prevent users from moving opportunity to Final stage unless,
    *               Reseller Agreement is populated on related account if a partner exist.
    */
    public static void oppyValidations(Map<Id,Opportunity> mapNewOpportunity, Map<Id,Opportunity> mapOldOpportunity) {
        if(OpportunityTriggerHandler.currentUserHasByPass()) {
            return;
        }
        checkOpportunityPartners(mapNewOpportunity,mapOldOpportunity);
    }
    public static boolean currentUserHasByPass() {
        Quality_Bars_Configuration__c qualityBars = Quality_Bars_Configuration__c.getInstance();
        if(qualityBars!=null && qualityBars.Disabled_Opportunity_QBs__c) {
            return true;
        }
        return false;
    }
    private static void checkOpportunityPartners(Map<Id,Opportunity> mapNewOpportunity, Map<Id,Opportunity> mapOldOpportunity) {
        Set<Id> setOpportunitiesToQuery = new Set<Id>();
        for(Opportunity oppy: mapNewOpportunity.values()) {
            Opportunity oldOpportunity = mapOldOpportunity.get(oppy.Id);
            if(oppy.StageName!=oldOpportunity.StageName && oppy.StageName ==System.Label.FinalQuote) {
                setOpportunitiesToQuery.add(oppy.Id);
            }
        }
        if(setOpportunitiesToQuery!=null && !setOpportunitiesToQuery.isEmpty()) {
            Set<Id> accountsToGetAgreements = new Set<Id>();
            List<Opportunity> lstEligiblePartners = [SELECT Id, AccountId, Account.BillingAddress,
                                    Account.ShippingAddress, SBQQ__PrimaryQuote__r.Service_Provider__c,
                                    SBQQ__PrimaryQuote__r.SBQQ__Partner__c, SBQQ__PrimaryQuote__r.SBQQ__Distributor__c,
                                    (SELECT Id,AccountToId,AccountTo.BillingAddress,Role FROM OpportunityPartnersFrom
                                    WHERE Role IN ('VAR/Reseller','Distributor')) 
                                    FROM Opportunity WHERE Id IN:setOpportunitiesToQuery];
            if(lstEligiblePartners!=null && !lstEligiblePartners.isEmpty()) {
                for(Opportunity erroredOppy: lstEligiblePartners) {

                    // Validate opportunity partners are correct.
                    List<String> errors = validateOpportunityPartners(erroredOppy);
                    if (!errors.isEmpty()) {
                        // If not, add error(s). Stop processing this opportunity as it doesn't make sense to continue.
                        mapNewOpportunity.get(erroredOppy.Id).addError(String.join(errors, '\n'));
                        continue;
                    }

                    if (!erroredOppy.OpportunityPartnersFrom.isEmpty()) {
                        if (erroredOppy.SBQQ__PrimaryQuote__r.Service_Provider__c == null) {
                            mapNewOpportunity.get(erroredOppy.Id).addError(System.Label.ServiceProviderEmpty);
                        } else {
                            for(OpportunityPartner oppyPartner: erroredOppy.OpportunityPartnersFrom ) {
                                Boolean isPartnerAddressMissing = 
                                    isAddressMissingFields(oppyPartner.AccountTo.BillingAddress);
                                if(isPartnerAddressMissing) {
                                    mapNewOpportunity.get(erroredOppy.Id)
                                        .addError(System.Label.FinalQuoteBillingAddressError);
                                }
                                accountsToGetAgreements.add(oppyPartner.AccountToId);
                            }
                        }
                    }

                    if(erroredOppy.OpportunityPartnersFrom==null || erroredOppy.OpportunityPartnersFrom.isEmpty()) {
                        Boolean isAccountAddressMissing = isAddressMissingFields( erroredOppy.Account.BillingAddress );
                        
                        if(isAccountAddressMissing) {
                            mapNewOpportunity.get(erroredOppy.Id)
                                .addError(formatMessage('Billing',System.Label.FinalQuoteAccountAddressError));
                        }
                    }
                    Boolean isAccountShippingAddressMissing = isAddressMissingFields(erroredOppy.Account.ShippingAddress);
                    if(isAccountShippingAddressMissing) {
                        mapNewOpportunity.get(erroredOppy.Id)
                            .addError(formatMessage('Shipping',System.Label.FinalQuoteAccountAddressError));
                    }
                }
                
                if (!accountsToGetAgreements.isEmpty()) {
                    List<Reseller_Agreement__c> resellerAgreements = [SELECT Account__c,Subsidiary__c
                        FROM Reseller_Agreement__c WHERE Account__c IN:accountsToGetAgreements];
                    Map<Id,Set<Id>> accountToSubsidiaries = new Map<Id,Set<Id>>();
                    for (Reseller_Agreement__c agreement: resellerAgreements) {
                        if (!accountToSubsidiaries.containsKey(agreement.Account__c)) {
                            accountToSubsidiaries.put(agreement.Account__c, new Set<Id>());
                        }
                        accountToSubsidiaries.get(agreement.Account__c).add(agreement.Subsidiary__c);
                    }
                    for(Opportunity erroredOppy: lstEligiblePartners) {
                        for(OpportunityPartner oppyPartner: erroredOppy.OpportunityPartnersFrom ) {
                            if (!accountToSubsidiaries.containsKey(oppyPartner.AccountToId) ||
                                !accountToSubsidiaries.get(oppyPartner.AccountToId)
                                    .contains(erroredOppy.SBQQ__PrimaryQuote__r.Service_Provider__c)) {
                                mapNewOpportunity.get(erroredOppy.Id).addError(System.Label.FinalQuoteError);
                            }
                        }
                    }
                }
                
            } 

        }
    }

    /**
     * Returns true if the opportunity partners match the quote partners; otherwise, returns false.
     */
    private static List<String> validateOpportunityPartners(Opportunity oppy) {

        // Check if partner/distributor exists on primary quote.
        Boolean partnerExistsOnQuote = oppy.SBQQ__PrimaryQuote__r.SBQQ__Partner__c != null;
        Boolean distributorExistsOnQuote = oppy.SBQQ__PrimaryQuote__r.SBQQ__Distributor__c != null;

        // Check if an associated partners exists on opportunity and, if any, check the role is unique.
        Boolean resellerExistsOnOpportunity = false;
        Integer resellerCount = 0;
        Boolean distributorExistsOnOpportunity = false;
        Integer distributorCount = 0;
        for(OpportunityPartner oppyPartner: oppy.OpportunityPartnersFrom) {
            if (oppyPartner.Role == 'VAR/Reseller') {
                resellerExistsOnOpportunity = resellerExistsOnOpportunity
                    || oppyPartner.AccountToId == oppy.SBQQ__PrimaryQuote__r.SBQQ__Partner__c;
                resellerCount++;
            }
            if (oppyPartner.Role == 'Distributor') {
                distributorExistsOnOpportunity = distributorExistsOnOpportunity
                    || oppyPartner.AccountToId == oppy.SBQQ__PrimaryQuote__r.SBQQ__Distributor__c;
                distributorCount++;
            }
        }

        // Ensure the setup on primary quote and on opportunity is aligned.
        List<String> errors = new List<String>();
        if(partnerExistsOnQuote != resellerExistsOnOpportunity || resellerCount > 1) {
            errors.add(String.format(
                System.Label.FinalQuoteIncorrectOpportunityPartner,
                new String[]{'partner', 'VAR/Reseller'}
            ));
        }
        if(distributorExistsOnQuote != distributorExistsOnOpportunity || distributorCount > 1) {
            errors.add(String.format(
                System.Label.FinalQuoteIncorrectOpportunityPartner,
                new String[]{'distributor', 'Distributor'})
            );
        }        
        return errors;
    }

    private static Boolean isAddressMissingFields(Address addr) {
        if(addr==null) {
            return true;
        }
        if(String.isBlank(addr.getCity()) || String.isBlank(addr.getCountry()) ||String.isBlank(addr.getStreet())) {
            return true;
        }
        return false;
    }
    @testvisible 
    private static String formatMessage(String parameter, String message) {
        List<String> parameters = new List<String>();
        parameters.add(parameter);
        return String.format(message, parameters);
    }

    public static void recallQuoteApprovalProcess(
      List<Opportunity> newRecords,
      Map<Id, Opportunity> oldMap
    ) {
      List<ID> quoteIds =  new List<ID>();
      List<String> stagesBeforeFinalQuote = new List<String>{'Pending', 'Outreach', 'Engaged', 'Proposal'};
      for (Opportunity opp : newRecords) {
          Opportunity oldOpp = oldMap.get(opp.Id);
          if(oldOpp.StageName == 'Final Quote' && stagesBeforeFinalQuote.contains(opp.StageName)) {
              quoteIds.add(opp.SBQQ__PrimaryQuote__c);
          }
      }

      if (quoteIds.size() > 0) {
          Map<Id,SBQQ__Quote__c> quotes = new Map<Id,SBQQ__Quote__c>([SELECT SBQQ__Status__c FROM SBQQ__Quote__c
                                                                      WHERE Id in :quoteIds]);
          List<ProcessInstanceWorkitem> processes = [SELECT Id, ProcessInstanceId, ProcessInstance.TargetObjectId
                                                      FROM ProcessInstanceWorkitem 
                                                      WHERE ProcessInstance.TargetObjectId in :quoteIds];
          for (ProcessInstanceWorkitem process : processes) {
              SBQQ__Quote__c quote = quotes.get(process.ProcessInstance.TargetObjectId);
              if (quote.SBQQ__Status__c == 'In Review') {
                  Approval.ProcessWorkitemRequest req = new Approval.ProcessWorkitemRequest();
                  req.setAction('Removed');       
                  req.setWorkitemId(process.Id);
                  Approval.process(req,false);
              }
          }
      }
    }
    public static void onOutreachSequenceTrigger(Map<Id,Opportunity> oldMap, Map<Id,Opportunity> newMap) {
        List<Initiate_Renewal_Process__e> events = new List<Initiate_Renewal_Process__e>();
        for(Opportunity opp: (List<Opportunity>) newMap.values()) {
            Opportunity oldOpp = (Opportunity) oldmap.get(opp.Id);
            if((opp.StageName!=oldOpp.StageName || 
                opp.Primary_Contact_Changed__c!=oldOpp.Primary_Contact_Changed__c
               || opp.OwnerId != oldOpp.OwnerId)
               && opp.StageName =='Outreach'
               && opp.Type == 'Renewal'
               && opp.Last_Survey_URL__c==null
               && opp.Active__c == true
              ) {
                  Initiate_Renewal_Process__e irp = new Initiate_Renewal_Process__e ();
					irp.Opportunity_18_Digit_Id__c =opp.Id;
                  	events.add(irp);
              }
        }
        if(events!=null && !events.isEmpty()) {
            EventBus.publish(events);
        }
    }
}