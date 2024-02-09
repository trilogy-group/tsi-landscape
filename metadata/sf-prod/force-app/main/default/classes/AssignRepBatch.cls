global virtual class AssignRepBatch implements Database.Batchable<sObject>, Database.AllowsCallouts {

    static final Double CALLING_HOURS_MIDPOINT = 12.5;
    static final Double REP_PAIRING_RANGE = 4.0;
    static final String ROLE_TO_DISTRIBUTE_TO = 'ISR New Business';
     
  global Database.QueryLocator start(Database.BatchableContext bc){
         return Database.getQueryLocator('SELECT Id, OwnerId, Owner.UserRole.Name, Country, Name, PostalCode, ' +
                                         'City, Company, Set_Google_Timezone__c, Product__c, Timezone__c, ' + 
                                         'Rep_Assigned__c FROM Lead ' +
                                         'WHERE Rep_Assigned__c = false AND status != \'Qualified\''+
                                         ' AND Product_Configuration__c != null '+
                                         'AND Product_Configuration__r.New_Business_Enabled__c = TRUE');
    }

    protected Map<Id, Set<String>> productCertifications; // Map UserId->Product Certifications
    protected Map<Id, Double> workingHoursMidpointUtc; // Map UserId->Middle of the working day in UTC
    private DateTime currentDateTime = DateTime.now(); // Current date/time for timezone offset calculation
    protected List<User> allReps; // All active ISRs 
    protected List<RepCount> repIdsOrderedByCount; // All ISRs ordered by leads count
    protected List<Lead> leadsToBeUpdated = new List<Lead>(); // List of changes to be written to DB
    // Owners for the accounts being processed (previously assigned lead owners)
    Map<String,Set<Id>> accountOwners = new Map<String,Set<Id>>(); 
    // Should be in lowercase
    Set<String> notExistingCompanies = new Set<String>(new String[]{'[not provided]','test','testing',
                                                                     'personal','test_organization','', null}); 

    // We should keep track on who processed opportunities for each company in past
    public void getLeadsOwners(List<Lead> leadsToProcess){ 
        Set<String> companies = new Set<String>();
        for(Lead leadDb : leadsToProcess){
            String key = getLeadOwnerKey(leadDb);
            if(!companies.contains(key)){
                companies.add(key);
            }
        }
        System.debug('Companies in the batch: ' + String.valueOf(companies));

        // Select leads recently processed by these companies
        List<Lead> leads = [SELECT Company, Owner.Id
        FROM Lead
        WHERE CreatedDate >= LAST_N_DAYS:365
        AND Company IN :companies
        AND OwnerId IN :productCertifications.keySet()
        ];
        System.debug('Existing leads for the companies: ' + String.valueOf(leads));
        for(Lead leadDb : leads){
            saveAccountOwner(leadDb);
        }
        System.debug('Account owners: ' + String.valueOf(accountOwners));
    }

    // We use Company name an owner key
    public String getLeadOwnerKey(Lead leadDb){
        if(leadDb.Company == null) return null;
        String key = leadDb.Company.toLowerCase().trim(); 
        if(notExistingCompanies.contains(key)) return null; // This is not really a company
        return key;
    }

    // Save an account owner in the set
    public void saveAccountOwner(Lead leadDb){
        String key = getLeadOwnerKey(leadDb);
        Id ownerId = leadDb.OwnerId;
        if(key == null){
            return; // No save for not saved accounts (test methods)
        }
        if(!accountOwners.containsKey(key)){
            Set<Id> owners = new Set<Id>();
            owners.add(ownerId);
            accountOwners.put(key, owners);
        } else {
            accountOwners.get(key).add(ownerId);
        }
    }

    // Get the owner for the opportunity which has been assigned to similar opportunities for the account
    public Id getAccountOwner(Lead leadDb){
        String accountKey = getLeadOwnerKey(leadDb);
        if(accountOwners.containsKey(accountKey)){
            for(Id repId : accountOwners.get(accountKey)){
                if(isIsrSuitableForLead(repId, leadDb)){ // The rep is certified for the product
                    for(RepCount rep : repIdsOrderedByCount){
                        if(rep.repId == repId){
                            System.debug(String.format('Account owner assigned Company: {0},' + 
                                                       ' OwnerId: {1}, Lead: {2} {3}', 
                                                       new String[]{ accountKey, repId, leadDb.Id, leadDb.Name }));
                            return rep.repId;
                        }
                    }
                }
            }
        }
        return null;
    }

    // Checks if the rep can be assigned to the lead
    public Boolean isIsrSuitableForLead(Id repId, Lead leadDb){ 
        // Check that ISR has correct role and product certification
        return isCertifiedForTheProduct(repId, leadDb.Product__c);
    }

    // Checks if the rep is certified for the product
    protected Boolean isCertifiedForTheProduct(Id repId, String product){
        if(productCertifications == null) return false;
        if(productCertifications.containsKey(repId)){
            return productCertifications.get(repId).contains(product);
        } else {
            System.debug('No certifications found for the user: ' + repId);
            return false;
        }
    }

    // Put certifications in a map
    protected void fillProductCertifications(){
        productCertifications = new Map<Id, Set<String>>();
        for(User user : allReps){
            productCertifications.put(user.Id, new Set<String>(user.Product_Certifications__c.split(';')));
        }
        System.debug('------- Users Product Certification ---------');
        System.debug(productCertifications);
    }

    // Put rep work day in UTC in a map
    protected virtual void fillWorkingHoursMap(){
        workingHoursMidpointUtc = new Map<Id, Double>();
        List<User> usersWorkingTime = [SELECT RepStartDay__c, RepEndDay__c, TimeZoneSidKey 
                                       FROM User where Id in :allReps];
        for(User user : usersWorkingTime){
            String repStartDay = (String)user.get('RepStartDay__c');
            String repEndDay = (String)user.get('RepEndDay__c');
            String repTimezoneId = (String)user.get('TimeZoneSidKey');
            try {
                if(!String.isBlank(repTimezoneId)){
                    Timezone repTimezone = Timezone.getTimeZone(repTimezoneId);
                    Double repOffset = repTimezone.getOffset(currentDateTime) / 3600000.0;
                    Integer repStartDayInt = Integer.valueof(String.isBlank(repStartDay)?'9':repStartDay);
                    Integer repEndDayInt = Integer.valueof(String.isBlank(repEndDay)?'18':repEndDay);
                    Double repStartDayUtc = repStartDayInt - repOffset;
                    Double repEndDayUtc = repEndDayInt - repOffset;
                    Double repWorkingHoursMidpointUTC = (repStartDayUtc + repEndDayUtc) / 2.0;
                    workingHoursMidpointUtc.put(user.Id, repWorkingHoursMidpointUTC);
                }
            }
            catch(Exception ex){
                System.debug(String.format('Incorrect timezone information for user:{0}. Exception: {1}',
                                            new String[]{String.valueOf(user.Id), ex.getMessage()}));
            }
        }
        System.debug('------- Users Working Time Midpoint UTC ---------');
        System.debug(workingHoursMidpointUtc);
    }

    // Gets UTC time for the rep day midpoint
    protected Double getDayMidpointUtc(Id repId){
        if(workingHoursMidpointUtc.containsKey(repId)){
            return workingHoursMidpointUtc.get(repId);
        }
        else {
            return 20; // Some general US time
        }
    }

    protected virtual void orderRepsByCount(){    // Prepare the list of reps ordered by leads count
        List<sObject> repsOrderedByCount = [SELECT Lead.OwnerId, count(Id) cnt 
        FROM Lead WHERE Lead.OwnerId IN :allReps AND Lead.CreatedDate = LAST_N_DAYS:14
        GROUP BY Lead.OwnerId 
        ORDER BY COUNT(Lead.Id) ASC];
        Set<Id> allLeadsOwnersSet = new Set<Id>();
        for (sObject op : repsOrderedByCount){
            allLeadsOwnersSet.add((Id)op.get('OwnerId'));
        }
        List<User> repsWithoutLeads = new List<User>();
        for (User u : allReps){
            if(!allLeadsOwnersSet.contains(u.Id)){
            repsWithoutLeads.add(u);
            }
        }
        repIdsOrderedByCount = new List<RepCount>();
        for(User user : repsWithoutLeads){ // ISRs without leads go first, because they have 0 leads
            RepCount cur = new RepCount();
            cur.repId = user.Id;
            cur.count = 0;
            repIdsOrderedByCount.add(cur);
        }
        for(sObject lead : repsOrderedByCount){ // Store reps with their leads count
            RepCount cur = new RepCount();
            cur.repId = (Id)lead.get('OwnerId');
            cur.count = (Integer)lead.get('cnt');
            repIdsOrderedByCount.add(cur);
        }
        logRepsCount('Reps ordered by count(before processing):');
    }

    private void logRepsCount(String message){ // Log User Ids and number of leads assigned to them
        System.debug(message);
        for(RepCount item : repIdsOrderedByCount){
            System.debug(String.valueOf(item));
        }

    }

    protected void processOneLead(Lead unassignedLead){ // Assign an owner to the lead given
        System.debug('Processing the lead: ' + unassignedLead);
        Id repAssignment = getAccountOwner(unassignedLead); // Search through old lead owners
        if(repAssignment == null){
            String productName = unassignedLead.Product__c;
            System.debug('Searching for a certification only: ' + productName);
            for (RepCount repCount  : repIdsOrderedByCount){
                if(isCertifiedForTheProduct(repCount.repId, productName)){
                    repAssignment = repCount.repId;
                    break;
                }
            }
        }
        if(repAssignment == null) {
            System.debug('We were not able to find rep for lead.');
        } else {
            addLeadToUpdate(unassignedLead, repAssignment);
        }
    }
    
    private void addLeadToUpdate(Lead unassignedLead, Id repAssignment) { // Adds updatinig of the owner to the list
        unassignedLead.OwnerId = repAssignment;
        unassignedLead.Rep_Assigned__c = true;        
        leadsToBeUpdated.add(unassignedLead);
        saveAccountOwner(unassignedLead); // Remember the lead assigned to the company
        for(RepCount item : repIdsOrderedByCount){
            if(item.repId == repAssignment){
                item.count++; // Since we assigned an item to this rep, increase the count
            }
        }
    }

    protected virtual void fillAllReps(){ // Read all ISR users with product certification
        allReps = [SELECT Id, Product_Certifications__c 
        FROM User 
        WHERE UserRole.Name = :ROLE_TO_DISTRIBUTE_TO
        AND IsActive = true 
        AND Product_Certifications__c != null];
    }

    global void execute(Database.BatchableContext bc, List<sObject> unassignedLeads){
        // Prepare initial data
        fillAllReps();
        fillProductCertifications();
        fillWorkingHoursMap();
        orderRepsByCount();     
        getLeadsOwners((List<Lead>)unassignedLeads);
        for(Lead unassignedLead : (List<Lead>)unassignedLeads){            
            try{
                processOneLead(unassignedLead);        
                repIdsOrderedByCount.sort(); // Keep the list sorted by leads count
            }
            catch(Exception ex){
                String errorString = String.format('Lead Id: {0}. Exception: {1}. \n Line: {2} \n Stack: {3}',
                    new String[]{String.valueOf(Lead.Id), ex.getMessage(), String.valueOf(ex.getLineNumber()), 
                                 ex.getStackTraceString()});
                ErrorReporting.notifyViaEmail('Error in assigning a Lead Owner', errorString);
            }
        }
        updateLeads();
    }

    protected virtual void updateLeads(){ // Save the updated leads to DB. Virtual for overriding in UT
        logRepsCount('Reps ordered by count(after processing):');
        update leadsToBeUpdated; // Move changes to DB
    }

    global void finish(Database.BatchableContext bc){    
    }
}