public class BatchCallPostGridAPI implements Database.Batchable<String>, Database.AllowsCallouts  {

    private Set<String> recordIds;

    // Constructor to accept record IDs
    public BatchCallPostGridAPI(Set<String> recordIds) {
        this.recordIds = recordIds;
    }

    public Iterable<String> start(Database.BatchableContext context) {
        return recordIds;
    }

    public void execute(Database.BatchableContext context, List<String> scope) {
        for (String recordId : scope) {
            try {
                // Make third-party API call using record ID
                callPostGridApiAsync(recordId);
            } catch (Exception e) {
                // Handle errors or log them as needed
            }
        }
    }
    

    public void finish(Database.BatchableContext context) {
        // Perform any cleanup or finalization tasks
    }

    private void callPostGridApiAsync(String opportunityIds) {
        system.debug('In Method');
        String apiUrl = 'https://api.postgrid.com/print-mail/v1/letters';
        List<PostGridAPIConfig__mdt> metadataRecords = [SELECT Id, MasterLabel, Value__c FROM PostGridAPIConfig__mdt];
        List<Opportunity> currentOppdata = [Select id,Description,Business_unit__c,Product__c,Account.Name,
                                            Owner.FirstName,Owner.LastName,Product_Configuration__c, 
                                            Product_Configuration__r.Mailbox_Override__c,
                                            AR_Quote_Success_Level__c,AR_List_Total__c,
                                            AR_Quote__r.SBQQ__BillingCity__c,AR_Quote__r.SBQQ__BillingCountry__c,  
                                            AR_Quote__r.SBQQ__BillingName__c,AR_Quote__r.SBQQ__BillingPostalCode__c,
                                            AR_Quote__r.SBQQ__BillingState__c,AR_Quote__r.SBQQ__BillingStreet__c,
            								AR_Quote__r.Service_Provider_City__c,AR_Quote__r.Service_Provider_Country__c,
                                            AR_Quote__r.Service_Provider_Name__c,AR_Quote__r.Service_Provider_Postal_Code__c,
                                            AR_Quote__r.Service_Provider_State__c,AR_Quote__r.Service_Provider_Street__c,
                                            AR_Pkg__c,Renewal_Date__c, Success_Level__c , AR_Quote_Term__c , ARR__c , 
                                            Customer_Termination_Deadline__c,
                                            Current_Success_Level__c ,Current_Term__c , List_Total__c,
                                            AR_Quote__r.Service_Provider__r.LogoUrl__c, Transactional_Opp__c ,
                                            (SELECT Id,AccountToId,AccountTo.BillingAddress,AccountTo.BillingCountry
                                             ,AccountTo.BillingState,AccountTo.BillingCity,
                                             AccountTo.BillingStreet,AccountTo.Name,AccountTo.BillingPostalCode,Role 
                                            FROM OpportunityPartnersFrom)
                                            from Opportunity where id =:opportunityIds];
        if(!currentOppdata.isEmpty()) {
            Opportunity currentOpp = currentOppdata[0];
            HttpRequest request = new HttpRequest();
            request.setEndpoint(apiUrl);
            request.setMethod('POST');
            request.setHeader('Content-Type', 'application/x-www-form-urlencoded');
            String apiKeyData;
            if(!metadataRecords.isEmpty()){
                apiKeyData = metadataRecords[0].Value__c;
            } else {
                apiKeyData = 'test_sk_jBxYWJyyQn4LsWmjHU2HYT_1';
            }
            // Add API key as a header
            request.setHeader('x-api-key', apiKeyData);
            String toStreet,toName,toCity,toState,toPostal,toFirstName;
            String fromStreet,fromName,fromCity,fromState,fromPostal,fromFirstName;
            if(!currentOpp.OpportunityPartnersFrom.isEmpty()) {
                if(currentOpp.OpportunityPartnersFrom[0].AccountTo.BillingStreet!=null) {
                    toStreet=currentOpp.OpportunityPartnersFrom[0].AccountTo.BillingStreet;
                } else {
                    toStreet='';
                }
                if(currentOpp.OpportunityPartnersFrom[0].AccountTo.Name!=null) {
                    toName=currentOpp.OpportunityPartnersFrom[0].AccountTo.Name;
                } else {
                    toName='';
                }
                if(currentOpp.OpportunityPartnersFrom[0].AccountTo.BillingCity!=null) {
                    toCity=currentOpp.OpportunityPartnersFrom[0].AccountTo.BillingCity;
                } else {
                    toCity='';
                }
                
                if(currentOpp.OpportunityPartnersFrom[0].AccountTo.BillingState!=null) {
                    toState=currentOpp.OpportunityPartnersFrom[0].AccountTo.BillingState;
                } else {
                    toState='';
                }
                if(currentOpp.OpportunityPartnersFrom[0].AccountTo.BillingPostalCode!=null) {
                    toPostal=currentOpp.OpportunityPartnersFrom[0].AccountTo.BillingPostalCode;
                } else {
                    toPostal='';
                }
                if(currentOpp.OpportunityPartnersFrom[0].AccountTo.Name!=null) {
                    toFirstName=currentOpp.OpportunityPartnersFrom[0].AccountTo.Name;
                } else {
                    toFirstName='PostGrid';
                }
                
            } else {
                if(currentOpp.AR_Quote__r.SBQQ__BillingStreet__c!=null) {
                    toStreet=currentOpp.AR_Quote__r.SBQQ__BillingStreet__c;
                } else {
                    toStreet='';
                }
                if(currentOpp.AR_Quote__r.SBQQ__BillingName__c!=null) {
                    toName=currentOpp.AR_Quote__r.SBQQ__BillingName__c;
                } else {
                    toName='';
                }
                if(currentOpp.AR_Quote__r.SBQQ__BillingCity__c!=null) {
                    toCity=currentOpp.AR_Quote__r.SBQQ__BillingCity__c;
                } else {
                    toCity='';
                }
                
                if(currentOpp.AR_Quote__r.SBQQ__BillingState__c!=null) {
                    toState=currentOpp.AR_Quote__r.SBQQ__BillingState__c;
                } else {
                    toState='';
                }
                if(currentOpp.AR_Quote__r.SBQQ__BillingPostalCode__c!=null) {
                    toPostal=currentOpp.AR_Quote__r.SBQQ__BillingPostalCode__c;
                } else {
                    toPostal='';
                }
                if(currentOpp.AR_Quote__r.SBQQ__BillingName__c!=null) {
                    toFirstName=currentOpp.AR_Quote__r.SBQQ__BillingName__c;
                } else {
                    toFirstName='PostGrid';
                }
            }
            if(currentOpp.AR_Quote__r.Service_Provider_Street__c!=null) {
                fromStreet=currentOpp.AR_Quote__r.Service_Provider_Street__c;
            } else {
                fromStreet='PostGrid Street';
            }
            if(currentOpp.AR_Quote__r.Service_Provider_Name__c!=null) {
                fromName=currentOpp.AR_Quote__r.Service_Provider_Name__c;
            } else {
                fromName='PostGrid';
            }
            if(currentOpp.AR_Quote__r.Service_Provider_City__c!=null) {
                fromCity=currentOpp.AR_Quote__r.Service_Provider_City__c;
            } else {
                fromCity='';
            }
            
            if(currentOpp.AR_Quote__r.Service_Provider_State__c!=null) {
                fromState=currentOpp.AR_Quote__r.Service_Provider_State__c;
            } else {
                fromState='';
            }
            if(currentOpp.AR_Quote__r.Service_Provider_Postal_Code__c!=null) {
                fromPostal=currentOpp.AR_Quote__r.Service_Provider_Postal_Code__c;
            } else {
                fromPostal='';
            }
            if(currentOpp.AR_Quote__r.Service_Provider_Name__c!=null) {
                fromFirstName=currentOpp.AR_Quote__r.Service_Provider_Name__c;
            } else {
                fromFirstName='';
            }
            string dateRenewal = '';
            string dateDeadline='';
            if(currentOpp.Renewal_Date__c != null) {
                dateRenewal = currentOpp.Renewal_Date__c.format();
            }
            
            if(currentOpp.Customer_Termination_Deadline__c != null) {
                dateDeadline = currentOpp.Customer_Termination_Deadline__c.format();
            }
            string hasCertified;
            
            string htmlContent = '<!DOCTYPE html> <html lang="en"> <head> <style type="text/css">@page { size: A4;margin: 0;} #final-notice p { font-size: 9pt !important; }</style>     <meta charset="UTF-8">     <meta name="viewport" content="width=device-width, initial-scale=1.0">     <title>Renewal Notice</title> </head> <body style="margin-left: 40px;margin-right: 40px;font: 11pt &quot;Tahoma&quot;;">     <div>       <center> <img src="'+currentOpp.AR_Quote__r.Service_Provider__r.LogoUrl__c+'" alt="Subsidiary Logo" style="max-height: 90px;  max-width: 300px;"> </center> </div>     <div>         <p>'+fromName +' <br>'+fromStreet +',<br> '+fromCity +', '+fromState +', '+fromPostal +'</p>  </div> <div> <p><strong>Date: </strong><span>'+system.today().format()+' </span></p>  </div> <div>  <p>'+ toName +' <br> Attn: General Counsel <br>'+toStreet +', <br>'+toCity +', '+toState +', '+toPostal +'</p> </div> <div> <p><strong>Subject - </strong><span> '+currentOpp.Product__c+' Service Renewal for '+currentOpp.Account.Name+' </p>     </div>  <div> <p>Dear '+currentOpp.Account.Name+' Team,</span></p> </div> <div><p><span>'+currentOpp.Account.Name+'’s '+currentOpp.Product__c+' service is scheduled to renew on <span>'+dateRenewal+'.</span></span></p>     </div>     <div>         <p>Given the existing agreement includes an automatic renewal clause, you have three options - each with applicable deadlines:</p><ol>  <li> If you have not already done so, engage with your Renewals rep for your convenience - now to review options available to you.  As it stands, we recommend you renew with '+currentOpp.Success_Level__c+' success for '+currentOpp.AR_Quote_Term__c+' months at '+currentOpp.ARR__c+' per year to realize the greatest value from your subscription.  Please note if a new agreement is not reached with your Renewals rep, your current agreement will renew unless you timely cancel in accordance with option #3 below.<br>OR </li> <li>Do nothing, and your agreement will auto renew, per the clause stated in your existing agreement, on the same terms '+currentOpp.AR_Quote_Success_Level__c+' for '+currentOpp.AR_Quote_Term__c+' at '+currentOpp.AR_List_Total__c+', which is the current list price.  Your automatic renewal invoice will be sent 30 days ahead of '+dateRenewal+'.<br>OR<br> </li> <li>Request cancellation of the renewal on or before '+dateDeadline+', by emailing notification to <a href="mailto:cancellations@trilogy.com">cancellations@trilogy.com</a> - detailing your company name, the product, and your renewal date. </li> </ol> </div> <div>         <p>You can contact us at any time to request a copy of your current contract, renewal quotation, or with any questions or concerns at renewals@'+currentOpp.Product_Configuration__r.Mailbox_Override__c+'.</p>     </div>     <div>         <p>We look forward to continuing our business relationship.</p>     </div>     <div>         <p>Best regards,<br>'+currentOpp.AR_Quote__r.Service_Provider_Name__c+'</p> </div> <div id="final-notice"> <p>This letter is simply a notice of renewal pursuant to the agreement between our companies. It is possible that there may be unintentional errors in references or other fields. Nothing herein is intended to amend or revise any agreement between our companies.</p> </div> </body> </html>';                           
                
            //string htmlContent = '<!DOCTYPE html> <html lang="en"> <head> <style type="text/css">@page { size: A4;margin: 0;}</style>     <meta charset="UTF-8">     <meta name="viewport" content="width=device-width, initial-scale=1.0">     <title>Renewal Notice</title> </head> <body style="margin-left: 40px;margin-right: 40px;font: 11pt &quot;Tahoma&quot;;}">     <div>       <center> <img src="'+currentOpp.AR_Quote__r.Service_Provider__r.LogoUrl__c+'" alt="Subsidiary Logo" style="max-height: 90px;  max-width: 300px;"> </center> </div>     <div>'+fromName+', <br'+fromStreet+',</br><br'+fromCity+','+fromState +','+fromPostal +'</br> </div>     <div>         <p><strong>Date: </strong><span>'+system.today().format()+' </span></p>     </div>     <div>         <p>'+ toName +',<p>'+toStreet+', </p><p>'+toCity+', '+toState+', '+toPostal+'</p>     </div>     <div>         <p><strong>Subject - </strong><span> '+currentOpp.Product__c+' Service Renewal for '+currentOpp.Account.Name+' </p>     </div>     <div>         <p>Dear '+currentOpp.Account.Name+' Team,</span></p>     </div>     <div>         <p><span>'+currentOpp.Account.Name+'’s '+currentOpp.Product__c+' service is scheduled to renew on <span>'+dateRenewal+'.</span></span></p>     </div>     <div>         <p>Given the existing agreement includes an automatic renewal clause, you have three options - each with applicable deadlines:</p>         <ol>             <li>                 <p>If you have not already done so, engage with your Renewals rep for your convenience - now to review options available to you.  As it stands, we recommend you renew with '+currentOpp.Success_Level__c+' for '+currentOpp.AR_Quote_Term__c+' months at '+currentOpp.ARR__c+' per year to realize the greatest value from your subscription.  Please note if a new agreement is not reached with your Renewals rep, your current agreement will renew unless you timely cancel in accordance with option #3 below.</p>       <p>OR</p>     </li>             <li>                 <p>Do nothing, and your agreement will auto renew, per the clause stated in your existing agreement, on the same terms '+currentOpp.Current_Success_Level__c+' for '+currentOpp.Current_Term__c+' at '+currentOpp.List_Total__c+', which is the current list price.  Your automatic renewal invoice will be sent 30 days ahead of '+dateRenewal+'.</p>      <p>OR</p>        </li>             <li>                 <p>Request cancellation of the renewal on or before '+dateDeadline+', by emailing notification to <a href="mailto:cancellations@trilogy.com">cancellations@trilogy.com</a> - detailing your company name, the product, and your renewal date</p>            </li>         </ol>     </div>     <div>         <p>You can contact us at any time to request a copy of your current contract, renewal quotation, or with any questions or concerns at the following:renewals@'+currentOpp.Business_unit__c+'.com</p>     </div>     <div>         <p>We look forward to continuing our business relationship.</p>     </div>     <div>         <p>Best regards,</p>   <p>'+currentOpp.AR_Quote__r.Service_Provider_Name__c+'</p>     </div>     <div>   <p>This letter is simply a notice of renewal pursuant to the agreement between our companies. It is possible that there may be unintentional errors in references or other fields. Nothing herein is intended to amend or revise any agreement between our companies.</p>     </div> </body> </html> ' ;
            //string htmlContent = '<!DOCTYPE html> <html lang="en"> <head>     <meta charset="UTF-8">     <meta name="viewport" content="width=device-width, initial-scale=1.0">     <title>Renewal Notice</title> </head> <body style="margin-left: 40px;    margin-right: 40px;">     <div>       <center> <img src="'+currentOpp.AR_Quote__r.Service_Provider__r.LogoUrl__c+'" alt="Subsidiary Logo">    </center> </div>     <div>         <p>'+fromName +', '+fromStreet +', '+fromCity +', '+fromState +', '+fromPostal +'</p>     </div>     <div>         <p><strong>Date: </strong><span>'+system.today().format()+' </span></p>     </div>     <div>         <p>'+ toName +', '+toStreet +', '+toCity +', '+toState +', '+toPostal +'</p>     </div>     <div>         <p><strong>Subject - </strong><span> '+currentOpp.Product__c+' Service Renewal for '+currentOpp.Account.Name+' </p>     </div>     <div>         <p>Dear '+currentOpp.Account.Name+' Team,</span></p>     </div>     <div>         <p><span>'+currentOpp.Account.Name+'’s '+currentOpp.Product__c+' service is scheduled to renew on <span>'+currentOpp.Renewal_Date__c+'.</span></span></p>     </div>     <div>         <p>Given the existing agreement includes an automatic renewal clause, you have three options - each with applicable deadlines:</p>         <ol>             <li>                 <p>If you have not already done so, engage with your Renewals rep for your convenience - now to review options available to you.  As it stands, we recommend you renew with '+currentOpp.Success_Level__c+' for '+currentOpp.AR_Quote_Term__c+' months at '+currentOpp.ARR__c+' per year to realize the greatest value from your subscription.  Please note if a new agreement is not reached with your Renewals rep, your current agreement will renew unless you timely cancel in accordance with option #3 below.</p>             </li>             <li>                 <p>Do nothing, and your agreement will auto renew, per the clause stated in your existing agreement, on the same terms '+currentOpp.Current_Success_Level__c+' for '+currentOpp.Current_Term__c+' at '+currentOpp.List_Total__c+', which is the current list price.  Your automatic renewal invoice will be sent 30 days ahead of '+currentOpp.Renewal_Date__c+'.</p>             </li>             <li>                 <p>Request cancellation of the renewal on or before '+currentOpp.Customer_Termination_Deadline__c+', by emailing notification to <a href="mailto:cancellations@trilogy.com">cancellations@trilogy.com</a> - detailing your company name, the product, and your renewal date</p>             </li>         </ol>     </div>     <div>         <p>You can contact us at any time to request a copy of your current contract, renewal quotation, or with any questions or concerns at the following:renewals@'+currentOpp.Business_unit__c+'.com</p>     </div>     <div>         <p>We look forward to continuing our business relationship.</p>     </div>     <div>         <p>Best regards,</p>         <p>'+currentOpp.AR_Quote__r.Service_Provider_Name__c+'</p>     </div>     <div>         <p>This letter is simply a notice of renewal pursuant to the agreement between our companies. It is possible that there may be unintentional errors in references or other fields. Nothing herein is intended to amend or revise any agreement between our companies.</p>     </div> </body> </html> ' ;
            system.debug('HTML=='+htmlContent);  
            String requestBody;
            if(currentOpp.Transactional_Opp__c == false){
				hasCertified = 'certified_return_receipt';	
                requestBody = 'to[addressLine1]='+ EncodingUtil.urlEncode(toStreet, 'UTF-8')+'&to[city]='+ EncodingUtil.urlEncode(toCity, 'UTF-8')+'&to[postalOrZip]='+ EncodingUtil.urlEncode(toPostal, 'UTF-8')+'&to[provinceOrState]='+ EncodingUtil.urlEncode(toState, 'UTF-8')+ '&to[firstName]=' + EncodingUtil.urlEncode(toFirstName, 'UTF-8')+'&to[companyName]=' + EncodingUtil.urlEncode( toFirstName, 'UTF-8')+'&from[firstName]='+EncodingUtil.urlEncode(fromName, 'UTF-8')+'&from[companyName]=' + EncodingUtil.urlEncode(fromName, 'UTF-8')+'&from[addressLine1]='+EncodingUtil.urlEncode(fromStreet, 'UTF-8')+'&from[city]='+ EncodingUtil.urlEncode(fromCity, 'UTF-8')+'&from[postalOrZip]='+ EncodingUtil.urlEncode(fromPostal, 'UTF-8')+'&from[provinceOrState]='+ EncodingUtil.urlEncode(fromState, 'UTF-8')+'&html=' + EncodingUtil.urlEncode(htmlContent, 'UTF-8')+'&addressPlacement=' + EncodingUtil.urlEncode('insert_blank_page', 'UTF-8')+'&color=true&extraService=' + EncodingUtil.urlEncode(hasCertified, 'UTF-8');
            } else {
                requestBody = 'to[addressLine1]='+ EncodingUtil.urlEncode(toStreet, 'UTF-8')+'&to[city]='+ EncodingUtil.urlEncode(toCity, 'UTF-8')+'&to[postalOrZip]='+ EncodingUtil.urlEncode(toPostal, 'UTF-8')+'&to[provinceOrState]='+ EncodingUtil.urlEncode(toState, 'UTF-8')+ '&to[firstName]=' + EncodingUtil.urlEncode(toFirstName, 'UTF-8')+'&to[companyName]=' + EncodingUtil.urlEncode( toFirstName, 'UTF-8')+'&from[firstName]='+EncodingUtil.urlEncode(fromName, 'UTF-8')+'&from[companyName]=' + EncodingUtil.urlEncode(fromName, 'UTF-8')+'&from[addressLine1]='+EncodingUtil.urlEncode(fromStreet, 'UTF-8')+'&from[city]='+ EncodingUtil.urlEncode(fromCity, 'UTF-8')+'&from[postalOrZip]='+ EncodingUtil.urlEncode(fromPostal, 'UTF-8')+'&from[provinceOrState]='+ EncodingUtil.urlEncode(fromState, 'UTF-8')+'&html=' + EncodingUtil.urlEncode(htmlContent, 'UTF-8')+'&addressPlacement=' + EncodingUtil.urlEncode('insert_blank_page', 'UTF-8')+'&color=true';
	        }
            
            // Construct the form-urlencoded body
            // String requestBody = 'to[addressLine1]='+ EncodingUtil.urlEncode(toStreet, 'UTF-8')+'&to[city]='+ EncodingUtil.urlEncode(toCity, 'UTF-8')+'&to[postalOrZip]='+ EncodingUtil.urlEncode(toPostal, 'UTF-8')+'&to[provinceOrState]='+ EncodingUtil.urlEncode(toState, 'UTF-8')+ '&to[firstName]=' + EncodingUtil.urlEncode(toFirstName, 'UTF-8')+'&to[companyName]=' + EncodingUtil.urlEncode( toFirstName, 'UTF-8')+'&from[firstName]='+EncodingUtil.urlEncode(fromName, 'UTF-8')+'&from[companyName]=' + EncodingUtil.urlEncode(fromName, 'UTF-8')+'&from[addressLine1]='+EncodingUtil.urlEncode(fromStreet, 'UTF-8')+'&from[city]='+ EncodingUtil.urlEncode(fromCity, 'UTF-8')+'&from[postalOrZip]='+ EncodingUtil.urlEncode(fromPostal, 'UTF-8')+'&from[provinceOrState]='+ EncodingUtil.urlEncode(fromState, 'UTF-8')+'&html=' + EncodingUtil.urlEncode(htmlContent, 'UTF-8')+'&addressPlacement=' + EncodingUtil.urlEncode('insert_blank_page', 'UTF-8')+'&color=true&extraService=' + EncodingUtil.urlEncode(hasCertified, 'UTF-8')';
                			/*  'key=' + EncodingUtil.urlEncode('to[addressLine1]', 'UTF-8') +
                                '&value=' + EncodingUtil.urlEncode(currentOpp.toStreetAddress, 'UTF-8')+'&'
                                'key=' + EncodingUtil.urlEncode('to[addressLine1]', 'UTF-8') +
                                '&value=' + EncodingUtil.urlEncode(currentOpp.toStreetAddress, 'UTF-8')+'&'
                                'key=' + EncodingUtil.urlEncode('to[addressLine1]', 'UTF-8') +
                                '&value=' + EncodingUtil.urlEncode(currentOpp.toStreetAddress, 'UTF-8')+'&'
                                'key=' + EncodingUtil.urlEncode('to[addressLine1]', 'UTF-8') +
                                '&value=' + EncodingUtil.urlEncode(currentOpp.toStreetAddress, 'UTF-8')+'&'
                                'key=' + EncodingUtil.urlEncode('to[addressLine1]', 'UTF-8') +
                                '&value=' + EncodingUtil.urlEncode(currentOpp.toStreetAddress, 'UTF-8')+'&'
                                'key=' + EncodingUtil.urlEncode('to[addressLine1]', 'UTF-8') +
                                '&value=' + EncodingUtil.urlEncode(currentOpp.toStreetAddress, 'UTF-8')+'&'
                                'key=' + EncodingUtil.urlEncode('to[addressLine1]', 'UTF-8') +
                                '&value=' + EncodingUtil.urlEncode(currentOpp.toStreetAddress, 'UTF-8')+'&'*/
    
            // Add more key-value pairs as needed
    
            request.setBody(requestBody);
    
            // Use try-catch block to handle exceptions
            try {
                // Create a new HTTP object to send the request
                Http http = new Http();
                HttpResponse response = http.send(request);
    
                // Process the response
                if (response.getStatusCode() == 200 || response.getStatusCode() == 201) {
                    // Request was successful
                    System.debug('API Response: ' + response.getBody());
                     
                    PostGridLetterResponseJson parsedData = PostGridLetterResponseJson.parse(response.getBody());
                    system.debug('parsedData=='+parsedData.id);
                    ///update current opp with response id
                    if(currentOpp.Customer_Termination_Deadline__c != null) {
                        Integer daysBetween = system.today().daysBetween(currentOpp.Customer_Termination_Deadline__c);
                        if(daysBetween == 29){
                        	currentOpp.PostGrid_Letter_Link_AR_20__c = 'https://dashboard.postgrid.com/dashboard/letters/'+parsedData.id;   
                        } else {
                            currentOpp.PostGrid_Letter_Link__c = 'https://dashboard.postgrid.com/dashboard/letters/'+parsedData.id;
                        } 
                    }
                    
                    
                    String descLetter = system.today().format() + ' System - A physical copy of the AR warning letter dispatched to the customer billing address. \n\r';
                    String descOpp= '';
                    if(currentOpp.Description!=null){
                        descOpp=currentOpp.Description;
                    }
                    currentOpp.Description = descLetter + descOpp;
                    update currentOpp;
                } else {
                    // Request failed
                    System.debug('Error: ' + response.getStatusCode() + ' - ' + response.getStatus());
                    System.debug('Error Message: ' + response.getBody());
                }
            } catch (Exception e) {
                // Handle exceptions
                System.debug('Exception: ' + e.getMessage());
            }
        }
    }    
    
}