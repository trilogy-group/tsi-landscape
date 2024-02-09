@isTest
public with sharing class AssignTimezoneBatchTest {
    class AssignTimezoneBatchWrapper extends AssignTimezoneBatch { // replace the timezone service with a wrapper
        protected override  CachedTimezoneService getTimezoneService(){
            return new CachedTimezoneServiceWrapper(); // Caching timezone service. It will cache HTTP request and count them
        }
    }     

    class CachedTimezoneServiceWrapper extends CachedTimezoneService { // Instead of HTTP requests we will use the mocked timezones
         public override TimezoneService.TimeZone getTimezone(String city, String country, String postalCode){
            TimezoneService.TimeZone tz = new TimezoneService.TimeZone();
            if(country == 'Exception') {
                throw new IllegalArgumentException('Test exception is raised.');
            }
            if(country == 'USA' || country == 'us'){            
                tz.timeZoneId ='America/Chicago';
            } else {
                tz.timeZoneId ='GMT';
            }
            return tz;
        }
    }

    static List<Lead> prepareSingleLeadData(String counrty){ // Insert one lead with the country given
        //Product Configuration
        Subsidiary__c subsidiary = new Subsidiary__c();
        insert subsidiary;
        Product_Configuration__c prodConfig = TestData.createProductConfiguration(subsidiary.Id, null, 'Kayako');
        List<Lead> unassignedLeads = new List<Lead>();
        Lead lead = new Lead(
            Country = counrty,
            PostalCode = null,
            City = null,
            LastName = TestData.LAST_NAME,
            Company = TestData.TEST_COMPANY,
            Set_Google_Timezone__c = false, 
            Product__c = 'Kayako',
            Timezone__c = null
        );
        insert lead;
        unassignedLeads.add(lead);
        return unassignedLeads;
    }

    @isTest
    static void testTimezoneAssignTest(){
        // Arrange
        AssignTimezoneBatch batch = new AssignTimezoneBatchWrapper();
        List<Lead> unassignedLeads = prepareSingleLeadData('USA');

        // Act
        batch.execute((Database.BatchableContext)null, unassignedLeads);

        // Assert
        Lead leadFromDb = [SELECT Id, Timezone__c, Set_Google_Timezone__c FROM Lead];
        System.assertEquals('America/Chicago', leadFromDb.Timezone__c, 'Incorrect timezone.');
        System.assertEquals(true, leadFromDb.Set_Google_Timezone__c, 'The Set_Google_Timezone__c should be true after timezone assigning.');
    }

    @isTest
    static void emptyCountryAssignTest(){ // Test that if the country = null the process executes assigning USA by default
        // Arrange
        AssignTimezoneBatch batch = new AssignTimezoneBatchWrapper();
        List<Lead> unassignedLeads = prepareSingleLeadData(null);

        // Act
        batch.execute((Database.BatchableContext)null, unassignedLeads);

        // Assert
        Lead leadFromDb = [SELECT Id, Timezone__c, Set_Google_Timezone__c FROM Lead];
        System.assertEquals('America/Chicago', leadFromDb.Timezone__c, 'Incorrect timezone.');
        System.assertEquals(true, leadFromDb.Set_Google_Timezone__c, 'The Set_Google_Timezone__c should be true after timezone assigning.');
    }

    @isTest
    static void exceptionHandlingTest(){ // Test that exception processing is correct
        // Arrange
        AssignTimezoneBatch batch = new AssignTimezoneBatchWrapper();
        List<Lead> unassignedLeads = prepareSingleLeadData('Exception');

        // Act
        batch.execute((Database.BatchableContext)null, unassignedLeads);

        // Assert
        Lead leadFromDb = [SELECT Id, Timezone__c, Set_Google_Timezone__c FROM Lead];
        System.assertEquals(null, leadFromDb.Timezone__c, 'When exception occurs the timezone should not be set.');
        System.assertEquals(true, leadFromDb.Set_Google_Timezone__c, 'The Set_Google_Timezone__c should be true after timezone assigning.');
    }
}