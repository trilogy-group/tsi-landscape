// Assign open opportunities (owned by “Sales Integration” user AND not in “Pending” stage) among active users with 
// the “ISR” word in their role name.
public virtual class AssignOpportunityRep implements Database.Batchable<sObject>, Database.AllowsCallouts, 
    Database.Stateful {
    
    static final Double CALLING_HOURS_MIDPOINT = 12.5; // Midle of the suitable calling time
    static final Double REP_PAIRING_RANGE = 4.0;        // Range of the suitable calling time (calling time is [MIDPOINT-RANGE,MIDPOINT+RANGE])
    static final Integer MAX_OPPORTUNITIES_DIFFERENCE = 3; // Maximum acceptable difference between opportunities number. If exceeded, we will assign opportunities despite TimeZone
    public static final Id SALES_INTEGRATION_USER_ID = '0052x000002Q1BbAAK';
    String NOTIFICATION_EMAIL_NOTE = 'Automation is unable to assign owners to the following opportunities '+
                                     '(no certified ISRs available). Please assign ISRs to the product, so the '+
                                     'automation assigns owners to the opportunities.\n<br>\n<br>';
    String NOTIFICATION_EMAIL_TITLE = '[ACTION REQUIRED] {0} - No certified ISRs to process renewal opportunities';
    String NOTIFICATION_EMAIL_OPP_LINE = '{0}. <a href="' + URL.getSalesforceBaseUrl().toExternalForm() +
                                         '/lightning/r/Opportunity/{1}/view">{2}</a>\n<br>';

    // ISR user information
    public class RepInfo {
        public Set<String> productCertifications; // Product certifications
        public String role;   // Role is used to check Renewals/New business assignment possibility
        public Timezone timeZone;   // Rep timezone
        public Integer startDay;    // Start of the rep day
        public Integer endDay;      // End of the rep day
        public Double startDayUTC;    // Start of the rep day in UTC
        public Double endDayUTC;      // End of the rep day in UTC
        public String email;          // User email
        public Boolean highValueCertified; // Specifies if rep is High Value certified
    }
    
    protected List<RepCount> repCounts = new List<RepCount>();  // Opps count for all reps
    protected Map<Id, RepInfo> isrInfo = new Map<Id, RepInfo>(); // ISR Information
    Map<String,Set<Id>> accountOwners = new Map<String,Set<Id>>(); // Owners for the accounts being processed (previously assigned opportunity owners)
    DateTime datetime_now = DateTime.now(); // Current time to calculate TZ offsets
    protected CachedTimezoneService cachedTimezoneService = new CachedTimezoneService();
    List<Opportunity> opportunitiesNotAssigned = new List<Opportunity>();
    protected Set<String> productHasHighValueRep = new Set<String>();
    // Batchable members
    public Database.QueryLocator start(Database.BatchableContext bc){
        getISRInformation();
        String query = 'SELECT Id, Name,' +
        'Account.Id, Account.BillingCountry, Account.BillingCity, Account.BillingPostalCode, ' +
        'OwnerId, Type, Product__c, SBQQ__PrimaryQuote__c, product_configuration__r.name, ' +
        'product_configuration__r.Renewal_Manager__r.email, ' + 
        'product_configuration__r.Renewal_Manager__r.name, ' +
        'High_Value_Opp__c ' +
        'FROM Opportunity ' +
        'WHERE IsClosed = false ' +
        'AND StageName != \'Pending\' ' +
        'AND OwnerId = \'' + SALES_INTEGRATION_USER_ID + '\' ' +
        'AND Active__c = true ' + 
        'ORDER BY product_configuration__r.name, Account.LastActivityDate DESC';
        return Database.getQueryLocator(query);
    }
    
    public void execute(Database.BatchableContext bc, List<sObject> opportunitiesToProcess){
        processOpportunities((List<Opportunity>)opportunitiesToProcess,false);
    }

    public void finish(Database.BatchableContext bc){ 
        if (opportunitiesNotAssigned.size() > 0){
            Map<String,String> errorsFoundPerProductFamily = new Map<String,String>();
            Map<String,String> emailPerProductFamily = new Map<String,String>();
            Map<String,String> namesPerProductFamily = new Map<String,String>();
            Integer i = 1;
            for (Opportunity opp : opportunitiesNotAssigned){
                String productFamily = opp.product_configuration__r.name;
                String productMessage = errorsFoundPerProductFamily.get(productFamily);
                if (productMessage == null) {
                    i = 1;
                }
                String message =  String.format(NOTIFICATION_EMAIL_OPP_LINE, new Object[]{i++, opp.Id, opp.Name});
                if (productMessage != null) {
                    errorsFoundPerProductFamily.put(productFamily, productMessage + message);
                } else {
                    errorsFoundPerProductFamily.put(productFamily, NOTIFICATION_EMAIL_NOTE + message);
                    emailPerProductFamily.put(productFamily, opp.product_configuration__r.Renewal_Manager__r.email);
                    namesPerProductFamily.put(productFamily, opp.product_configuration__r.Renewal_Manager__r.name);
                }
            }

            for (String productFamily : errorsFoundPerProductFamily.keySet()){
                String emailTitle = String.format(NOTIFICATION_EMAIL_TITLE, new String[]{productFamily});
                String emailBody = String.format('Dear {0}, \n<br>\n<br>{1}', new String[]{
                        namesPerProductFamily.get(productFamily), errorsFoundPerProductFamily.get(productFamily)});
                ErrorReporting.notifyViaEmail(emailTitle, emailBody, true, emailPerProductFamily.get(productFamily));
                System.debug('Sending email to ' + emailPerProductFamily.get(productFamily));
            }

        }
    }    

    public void processOpportunities(List<Opportunity> opportunitiesToProcess, Boolean getISRInfo){
        if (getISRInfo) {
            getISRInformation();
        }
        getAccountOwners(opportunitiesToProcess);
        assignOpportunitiesOwners(opportunitiesToProcess); // Assign owners
        repCounts.sort();
        debugIsrInfo();
        update opportunitiesToProcess; // Write to DB
        reAssignQuotes(opportunitiesToProcess); // Sync the SalesRep field
    }

    private void reAssignQuotes(List<Opportunity> opportunitiesToProcess){
        List<SBQQ__Quote__c> quotes = new List<SBQQ__Quote__c>();
        for (Opportunity o : opportunitiesToProcess){
            if(o.SBQQ__PrimaryQuote__c != null && o.OwnerId != null) {
                quotes.add(new SBQQ__Quote__c(Id = o.SBQQ__PrimaryQuote__c, SBQQ__SalesRep__c = o.OwnerId));
            }
        }
        update quotes;
    }

    private void getISRInformation(){
        // Get all the ISRs
        List<User> cx_on_rep_users = [SELECT Id, Product_Certifications__c, RepStartDay__c, RepEndDay__c, TimeZoneSidKey, Email, UserRole.Name,High_Value_Opportunity_Certified__c
        FROM User 
        WHERE UserRole.Name LIKE '%ISR%' AND IsActive=TRUE AND Product_Certifications__c != null
        ORDER BY High_Value_Opportunity_Certified__c DESC
        ];
        // Prepare a dictionary with certifications
        // Used clear instead creating new because this is being used in a wrapper to assert test
        isrInfo.clear();
        for(User user:cx_on_rep_users){
            RepInfo info = new RepInfo();
            info.productCertifications = new Set<String>(user.Product_Certifications__c.split(';'));
            info.role = user.UserRole.Name;
            String startDayString = String.valueOf(user.get('RepStartDay__c')); // The RepStart and RepEnd can be not filled yet
            info.startDay = Integer.valueof(String.isBlank(startDayString)?'9':startDayString);
            String endDayString = String.valueOf(user.get('RepEndDay__c'));
            info.endDay = Integer.valueof(String.isBlank(endDayString)?'18':endDayString);
            info.timeZone = String.isBlank(user.TimeZoneSidKey)?null:Timezone.getTimeZone(user.TimeZoneSidKey);
            Double repOffset = info.timeZone.getOffset(datetime_now) / 3600000.0;
            Integer rep_start_day_int = info.startDay;
            Integer rep_end_day_int = info.endDay;
            Double rep_start_day_UTC = rep_start_day_int - repOffset;
            Double rep_end_day_UTC = rep_end_day_int - repOffset;
            info.startDayUTC = rep_start_day_UTC;
            info.endDayUTC = rep_end_day_UTC;
            info.email = user.Email;
            info.highValueCertified = user.High_Value_Opportunity_Certified__c;
            isrInfo.put(user.Id, info);
            if(user.High_Value_Opportunity_Certified__c) {
                productHasHighValueRep.addAll(info.productCertifications);
            }
        }

        // Count the opportunities assigned to the ISRs recently
        List<sObject> assignedCount = [SELECT OwnerId, count(Id) cnt 
                            FROM  Opportunity 
                            WHERE OwnerId in :cx_on_rep_users 
                                AND (CloseDate < tomorrow OR CloseDate = NEXT_N_DAYS:120)
                                AND IsClosed = false
                            GROUP BY OwnerId 
                            ORDER BY count(Id) asc];
        List<Id> allReps = new List<Id>(); // Create a list of all the Reps to find reps without leads
        for(User user:cx_on_rep_users){
            allReps.add(user.Id);
        }
        // Used clear instead creating new because this is being used in a wrapper to assert test
        repCounts.clear();
        for(SObject row:assignedCount){
            RepCount cur = new RepCount();
            cur.repId = (Id)row.get('OwnerId');
            cur.count = (Integer)row.get('cnt');
            repCounts.add(cur);
            if(allReps.contains(cur.repId)){
                 allReps.remove(allReps.indexOf(cur.repId));
            }
        }
        
        for(Id userId:allReps){ // Users without opportunities
            RepCount cur = new RepCount();
            cur.repId = userId;
            cur.count = 0;
            repCounts.add(cur);
        }
        repCounts.sort();
        this.debugIsrInfo();
    }

    // We should keep track on who processed opportunities for each account in past
    public void getAccountOwners(List<Opportunity> opportunitiesToProcess) { 
        Set<Id> accountIds = new Set<Id>();
        for(Opportunity opp : opportunitiesToProcess){
            if(!accountIds.contains(opp.AccountId)){
                accountIds.add(opp.AccountId);
            }
        }
        // Select opporunities recently closed in the account, owned by a suitable ISR
        List<Opportunity> opps = [SELECT Id, NAME, Owner.Id, AccountId, Type
        FROM Opportunity
        WHERE CloseDate >= LAST_N_DAYS:90
        AND AccountId IN :accountIds
        AND OwnerId IN :isrInfo.keySet()];
        accountOwners = new Map<String,Set<Id>>();
        for(Opportunity opp : opps){
            saveAccountOwner(opp);
        }
    }

    // We use AccountId and Renewal/NonRenewal as an owner key
    public String getAccountOwnerKey(Opportunity opp){
        if(opp.AccountId == null) return null;
        String key = opp.AccountId; // For possible extension in future
        return key;
    }

    // Save an account owner in the set
    public void saveAccountOwner(Opportunity opp){
        String accountKey = getAccountOwnerKey(opp);
        Id ownerId = opp.OwnerId;
        if(accountKey == null){
            return; // No save for not saved accounts (test methods)
        }
        if(!accountOwners.containsKey(accountKey)){
            Set<Id> owners = new Set<Id>();
            owners.add(ownerId);
            accountOwners.put(accountKey, owners);
        } else {
            accountOwners.get(accountKey).add(ownerId);
        }
    }


    // Get the owner for the opportunity which has been assigned to similar opportunities for the account
    public RepCount getAccountOwner(Opportunity opp){
        String accountKey = getAccountOwnerKey(opp);
        if(accountOwners.containsKey(accountKey)){
            for(Id repId : accountOwners.get(accountKey)){
                if(isIsrSuitableForOpportunity(repId, opp)){ // The rep is certified for the product
                    for(RepCount rep : repCounts){
                        if(rep.repId == repId){
                            System.debug(String.format('Account owner assigned AccountId: {0}, OwnerId: {1}, Opportunity: {2} {3}', new String[]{ accountKey, repId, opp.id, opp.Name }));
                            return rep;
                        }
                    }
                }
            }
        }
        return null;
    }

    public Boolean isIsrSuitableForOpportunity(Id repId, Opportunity opp){
        RepInfo info = isrInfo.get(repId);
        return isIsrSuitableForOpportunity(info, opp);
    }

    public Boolean isIsrSuitableForOpportunity(RepInfo info, Opportunity opp){ // Check that ISR has correct role and product certification
        String product = (String)opp.get('Product__c');        
        return info.productCertifications.contains(product) // The rep is certified for the product
            && isIsrRoleSuitableForOpportunity(info.role, opp)
            && (!opp.High_Value_Opp__c || 
            (info.highValueCertified && opp.High_Value_Opp__c) || !productHasHighValueRep.contains(product));
    }

    // Check that role is ok to be assigned
    public Boolean isIsrRoleSuitableForOpportunity(String role, Opportunity opp) {
        switch on role {
            when 'ISR' {
                return true;
            }
            when 'ISR Renewals' {
                return opp.Type == 'Renewal';
            }
            when 'ISR New Business' {
                return opp.Type == 'New Business' || opp.Type == 'Upsell';
            }
            when else {
                return false;
            }
        }                                                  
    }

    // Get timezone for the opportunity
    public TimeZone getContactTimezone(Opportunity opportunity){
        TimezoneService.TimeZone timezoneByAddress = cachedTimezoneService.defaultTimeZone;
        if(opportunity.Account.BillingCountry!=null)
        {
            timezoneByAddress = cachedTimezoneService.getTimeZone(opportunity.Account.BillingCity, opportunity.Account.BillingCountry, opportunity.Account.BillingPostalCode);
        }
        
        TimeZone contactTimezone = null;
        if(timezoneByAddress != null) {
            contactTimezone = TimeZone.getTimeZone(timezoneByAddress.timeZoneId);
        }
        else {
            contactTimezone = Timezone.getTimeZone('America/New York');
        }
        return contactTimezone;
    }

    public RepCount findSuitableRep(Opportunity opportunity){
        RepCount assignedRep = null;
        // Get timezone for the opportunity        
        TimeZone contact_timezone = getContactTimezone(opportunity);
        Double contact_offset = contact_timezone.getOffset(datetime_now) / 3600000.0;
        Double contact_timezone_min = CALLING_HOURS_MIDPOINT - contact_offset - REP_PAIRING_RANGE;
        Double contact_timezone_max = CALLING_HOURS_MIDPOINT - contact_offset + REP_PAIRING_RANGE;
        // Find a suitable owner for the opportunity            
        Double tentativeOverlap = 0;      // TZ overlap for the candidate
        Integer minCount = 9999;          // Minimal number of opportunities for a rep with proper certification
        Integer countDif = 9999;          // Difference between the minimal count and count of the selected user
        
        for(RepCount user:repCounts){
            RepInfo info = isrInfo.get(user.repId);
            // The rep is certified for the product
            if(!isIsrSuitableForOpportunity(info, opportunity)) {
                continue;
            }
            // Checking timezone
            Double overlappingTZ = rangesIntersection(info.startDayUTC, info.endDayUTC, contact_timezone_min, contact_timezone_max);
            
            if(assignedRep == null) { // We do not have any variant yet. Let's remember at least this one
                assignedRep = user;
                tentativeOverlap = overlappingTZ;
                minCount = user.count; // Since it is the first rep in our list, he has the minimum amount of opportunities
                countDif = 0;
                if(overlappingTZ  > 1/*4*/) {  // We do not need to search further. Let's assign this opportunity to the rep with minimal opportunities number
                    tentativeOverlap = overlappingTZ;
                    break;
                }
            } else {
                if((user.count - minCount) > MAX_OPPORTUNITIES_DIFFERENCE) {
                    break; // We can't afford assigning opportunites with such a big difference
                }
                else if(overlappingTZ > tentativeOverlap ) {
                    assignedRep = user;
                    tentativeOverlap = overlappingTZ;
                    countDif = user.count - minCount;
                }
            }
        }
        return assignedRep;
    }

    // Assign owners for the opportunities given
    public void assignOpportunitiesOwners(List<Opportunity> opportunitiesToProcess) {
        for(Opportunity opportunity:opportunitiesToProcess) {
            repCounts.sort(); // Keep the rep list sorted by count in ascending order
            RepCount assignedRep = getAccountOwner(opportunity); // Assignment candidate
            if(assignedRep == null) {
                assignedRep = findSuitableRep(opportunity);
            }
            if(assignedRep != null) { // There might be a product without ISR so we won't be able to find an ISR            
                assignedRep.count++;
                opportunity.OwnerId = assignedRep.repId;
                saveAccountOwner(opportunity); // Store assigned rep as an Account owner, there might be opportunities from this account later
            } else{
                opportunitiesNotAssigned.add(opportunity);
            }
            if(Limits.getCallouts() + 3 > Limits.getLimitCallouts())
            {
                break; // Limit callouts number
            }
        }
    }

    /// Write to Debug info about ISRs included their opportunities count
    private void debugIsrInfo(){        
        System.debug('---------- ISRs --------------');
        for(RepCount user:repCounts){
            RepInfo info = isrInfo.get(user.repId);
            System.debug(String.Format('UserId={0} Email={1} Cert={6} Day=[{7},{8}] UtcDay=[{4},{5}] Tz={2}  Count={3}', 
            new String[] { user.repId, info.email, String.valueOf(info.timeZone), String.valueOf(user.count), String.valueOf(info.startDayUTC), String.valueOf(info.endDayUTC), String.valueOf(info.productCertifications), String.valueOf(info.startDay), String.valueOf(info.endDay)}));
        }
        System.debug('---------- ISRs --------------');
    }

    // Find intersection length of 2 ranges [min1,max1] and [min2,max2]
    // When there is no intersection, the method returns distance with negative sign (length of the gap between ranges)
    public Double rangesIntersection(Double min1, Double max1, Double min2, Double max2){
        // Normalize the ranges. They should be in the positive area
        if(min1 < 0)
        {
            min1 += 24;
            max1 += 24;
        }
        if(min2 < 0)
        {
            min2 += 24;
            max2 += 24;
        }
        // Order the ranges
        if(min1 > min2)
        {
            Double m = min1;
            min1 = min2;
            min2 = m;
            m = max1;
            max1 = max2;
            max2 = m;
        }

        if(max1 <= min2){ // No intersection, return negative number
            Double dist1 = Math.abs(min2 - max1);
            Double dist2 = Math.abs((min1 + 24) - max2);
            return -Math.min(dist1, dist2);
        }
        return Math.abs(max1 - min2);        
    }
}