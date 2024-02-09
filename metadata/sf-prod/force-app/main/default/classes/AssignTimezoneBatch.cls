global virtual class AssignTimezoneBatch implements Database.Batchable<sObject>, Database.AllowsCallouts {
   
  global Database.QueryLocator start(Database.BatchableContext bc) {
         return Database.getQueryLocator('SELECT Id, City, PostalCode, Country, Timezone__c, Set_Google_Timezone__c FROM Lead WHERE Lead.Set_Google_Timezone__c = False AND Lead.Timezone__c = null');
    }

    protected virtual CachedTimezoneService getTimezoneService(){
        return new CachedTimezoneService(); // Caching timezone service. It will cache HTTP request and count them
    }

    global void execute(Database.BatchableContext bc, List<sObject> no_timezone_opportunities){
        CachedTimezoneService cachedTimezoneService = getTimezoneService();
        List<Lead> to_update_leads = new List<Lead>();
        for (sObject ob : no_timezone_opportunities) {
            Lead l = (Lead)ob;
            String city = l.City;
            String postalCode = l.PostalCode;
            String country = l.Country;
            if (l.Country == null){
                country = 'us';
            }
            try {
                TimezoneService.TimeZone timeZone = cachedTimezoneService.getTimeZone(city, country, postalCode);
                Lead lead_to_update = new Lead(Id=l.Id, Set_Google_Timezone__c=True, Timezone__c=timeZone.timeZoneId);
                to_update_leads.add(lead_to_update);
                if(Limits.getCallouts() + 3 > Limits.getLimitCallouts())
                {
                    break; // Limit callouts number
                }
            }
            catch(Exception e){
                System.debug('Exception caught: ' + e.getMessage());
                Lead lead_to_update = new Lead(Id=l.Id, Set_Google_Timezone__c=True); // Mark it as a processed anyway
                to_update_leads.add(lead_to_update);
            }
        }
        update to_update_leads;
    }
    
    global void finish(Database.BatchableContext bc) {
    }      
}