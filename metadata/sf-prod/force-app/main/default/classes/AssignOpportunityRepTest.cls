@isTest
public class AssignOpportunityRepTest {

    static final String USER_PROFILE = 'System Administrator';
    static final String USER_ROLE = 'ISR';

    static final String MANAGER_PROFILE = 'Team Manager';
    static final String MANAGER_ROLE = 'Manager New Sales';

    class AssignOpportunityRepWrapper extends AssignOpportunityRep {
        // Fill the dictionaries without DB reading
        public AssignOpportunityRepWrapper(List<RepCount> repCountsReplacement, Map<Id, RepInfo> isrInfoReplacement, CachedTimezoneService cachedTimezoneServiceReplacement) {
            this.repCounts = repCountsReplacement;
            this.isrInfo = isrInfoReplacement;
            this.cachedTimezoneService = cachedTimezoneServiceReplacement;
        }
    }

    class CachedTimezoneServiceWrapper extends CachedTimezoneService {
        // Instead of HTTP requests we will use the mocked timezones
        public override TimezoneService.TimeZone getTimezone(String city, String country, String postalCode) {
            TimezoneService.TimeZone tz = new TimezoneService.TimeZone();
            if (country == COUNTRY_USA) {
                tz.timeZoneId = 'America/Chicago';
            } else {
                tz.timeZoneId = 'GMT';
            }
            return tz;
        }
    }

    static List<RepCount> RepCounts = new List<RepCount>();
    static Map<Id, AssignOpportunityRep.RepInfo> IsrInfo = new Map<Id, AssignOpportunityRep.RepInfo>();

    static final String PRODUCT_3 = 'Kayako';
    static final String COUNTRY_USA = 'USA';
    static final String COUNTRY_GERMANY = 'Germany';
    static final String CITY_NEW_YORK = 'New York';
    static final String CITY_BERLIN = 'Berlin';
    static final String ACCOUNT_NAME = 'Test account';
    static final String OPP_NAME = 'Test Opportunity';
    static final String STAGE_NAME = 'Outreach';

    static final String OWNER_ERROR_MSG = 'Owner should have been assigned.';
    static final String OWNER_SHOULD_NOT_BE_ASSIGNED_ERROR_MSG = 'Owner should not be assigned.';

    @isTest
    static void testSimpleAssignment() {
        seedDbRepRec('001xa000003DIloAAG', TestData.EMAIL_1, TestData.PRODUCT_NAME, 0, 1, 0);
        Opportunity testOpportunity = seedOpportunity(COUNTRY_USA, CITY_NEW_YORK, TestData.PRODUCT_NAME, 'Renewal');

        assignOpportunitiesOwners(new Opportunity[]{
                testOpportunity
        });

        System.assert(testOpportunity.OwnerId != AssignOpportunityRep.SALES_INTEGRATION_USER_ID, OWNER_ERROR_MSG);
    }

    @isTest
    static void productAssignment() {
        seedDbRepRec('001xa000003DIloAAG', TestData.EMAIL_1, TestData.PRODUCT_NAME, 0, 1, 10);
        seedDbRepRec('0051y000001Br59AAC', TestData.EMAIL_2, TestData.PRODUCT_NAME_2, 0, 1, 0);
        Opportunity testOpportunity = seedOpportunity(COUNTRY_USA, CITY_NEW_YORK, TestData.PRODUCT_NAME, 'Renewal');

        assignOpportunitiesOwners(new Opportunity[]{
                testOpportunity
        });

        System.assert(testOpportunity.OwnerId == '001xa000003DIloAAG', 'Owner should have the necessary product certification.');
    }

    @isTest
    static void lowestCountAssignment() {
        seedDbRepRec('001xa000003DIloAAG', TestData.EMAIL_1, TestData.PRODUCT_NAME, 0, 1, 10);
        seedDbRepRec('0051y000001Br59AAC', TestData.EMAIL_2, TestData.PRODUCT_NAME, 0, 1, 0);
        Opportunity testOpportunity = seedOpportunity(COUNTRY_USA, CITY_NEW_YORK, TestData.PRODUCT_NAME, 'Renewal');

        assignOpportunitiesOwners(new Opportunity[]{
                testOpportunity
        });

        System.assert(testOpportunity.OwnerId == '0051y000001Br59AAC', 'Opportunity should go the ISR with lower opportunities count.');
    }

    @isTest
    static void timezoneBasedAssignment() {
        seedDbRepRec('001xa000003DIloAAG', TestData.EMAIL_1, TestData.PRODUCT_NAME, 9, 9, 0);
        seedDbRepRec('0051y000001Br59AAC', TestData.EMAIL_2, TestData.PRODUCT_NAME, 0, 0, 0);
        Opportunity germanyOpportunity = seedOpportunity(COUNTRY_GERMANY,
                                                         CITY_BERLIN,
                                                         TestData.PRODUCT_NAME,
                                                         'Renewal');
        Opportunity usaOpportunity = seedOpportunity(COUNTRY_USA,
                                                     CITY_NEW_YORK,
                                                     TestData.PRODUCT_NAME,
                                                     'Renewal');

        assignOpportunitiesOwners(new Opportunity[]{
                germanyOpportunity, usaOpportunity
        });

        System.assert(germanyOpportunity.OwnerId == '001xa000003DIloAAG', 'Opportunity should go the ISR with closest working hours (GMT).');
        System.assert(usaOpportunity.OwnerId == '0051y000001Br59AAC', 'Opportunity should go the ISR with closest working hours (USA).');
    }

    @isTest
    static void bigCountDifferenceAssignment() {
        seedDbRepRec('001xa000003DIloAAG', TestData.EMAIL_1, TestData.PRODUCT_NAME, 9, 9, 6);
        seedDbRepRec('0051y000001Br59AAC', TestData.EMAIL_2, TestData.PRODUCT_NAME, 0, 0, 0);
        Opportunity germanyOpportunity = seedOpportunity(COUNTRY_GERMANY,
                                                         CITY_BERLIN,
                                                         TestData.PRODUCT_NAME,
                                                         'Renewal');

        assignOpportunitiesOwners(new Opportunity[]{
                germanyOpportunity
        });

        System.assert(germanyOpportunity.OwnerId == '0051y000001Br59AAC', 'When ISR opportunities count differs significantly this should override timezone consideration.');
    }

    @isTest
    static void minOverlapEnoughAssignment() {
        seedDbRepRec('001xa000003DIloAAG', TestData.EMAIL_1, TestData.PRODUCT_NAME, 9, 12, 4);
        seedDbRepRec('0051y000001Br59AAC', TestData.EMAIL_2, TestData.PRODUCT_NAME, 14, 16, 0);
        Opportunity germanyOpportunity = seedOpportunity(COUNTRY_GERMANY,
                                                         CITY_BERLIN,
                                                         TestData.PRODUCT_NAME,
                                                         'Renewal');

        assignOpportunitiesOwners(new Opportunity[]{
                germanyOpportunity
        });

        System.assert(germanyOpportunity.OwnerId == '0051y000001Br59AAC', '>1h TZ overlap is good enough to stop looking for a better overlap.');
    }

    private static void seedDbRepRec(String id, String email, String productName, 
									 Double startDayUTC, Double endDayUTC, Integer repCount) {
        IsrInfo.put(id, createRepInfoRecord(email, startDayUTC, endDayUTC, productName));

        RepCounts.add(createIsrCountRecord(id, repCount));
    }

    private static Opportunity seedOpportunity(String billingCountry, String billingCity, 
											   String productName, String opportunityType) {
        Account testAccount = new Account(BillingCountry = billingCountry, BillingCity = billingCity);
        return new Opportunity(Account = testAccount, Product__c = productName, Type = opportunityType,
                OwnerId = AssignOpportunityRep.SALES_INTEGRATION_USER_ID);
    }

    private static void assignOpportunitiesOwners(Opportunity[] opportunities) {
        AssignOpportunityRepWrapper wrapper = new AssignOpportunityRepWrapper(RepCounts, IsrInfo, 
																	new CachedTimezoneServiceWrapper());
        wrapper.assignOpportunitiesOwners(opportunities);
    }

    private static AssignOpportunityRep.RepInfo createRepInfoRecord(String email, Double startDayUTC, Double endDayUTC, String productCertifications) {
        AssignOpportunityRep.RepInfo isr = new AssignOpportunityRep.RepInfo();
        isr.email = email;
        isr.startDayUTC = startDayUTC;
        isr.endDayUTC = endDayUTC;
        isr.productCertifications = new Set<String>(productCertifications.split(';'));
        isr.role = 'ISR Renewals';
        return isr;
    }

    private static RepCount createIsrCountRecord(String repId, Integer count) {
        RepCount isrCount = new RepCount();
        isrCount.repId = repId;
        isrCount.count = count;
        return isrCount;
    }

    @isTest
    static void e2eReadDBAssignment() {
        List<RepCount> repCountList = new List<RepCount>();
        Map<Id, AssignOpportunityRep.RepInfo> repInfoMap = new Map<Id, AssignOpportunityRep.RepInfo>();
        AssignOpportunityRepWrapper batch = new AssignOpportunityRepWrapper(repCountList, repInfoMap, new CachedTimezoneServiceWrapper());
        User userManager = TestData.getUser(MANAGER_PROFILE);
        TestData.updateUserRole(userManager, MANAGER_ROLE);
        TestData.createTestUser(USER_PROFILE, USER_ROLE, PRODUCT_3, userManager);
        Opportunity testOpportunity = prepareTestOpportunity(PRODUCT_3);

        batch.ProcessOpportunities(new Opportunity[]{
                testOpportunity
        }, true);
        Opportunity opp = [
                SELECT Id, OwnerId
                FROM Opportunity
                WHERE Id = :testOpportunity.Id
        ];
        System.assert(opp.OwnerId != AssignOpportunityRep.SALES_INTEGRATION_USER_ID, OWNER_ERROR_MSG);
        System.assert(repInfoMap.containsKey(opp.OwnerId), 'Owner should be one of the ISRs.');
    }

    @isTest
    static void sameAccountAssignment() {
        List<RepCount> repCountList = new List<RepCount>();
        Map<Id, AssignOpportunityRep.RepInfo> repInfoMap = new Map<Id, AssignOpportunityRep.RepInfo>();
        AssignOpportunityRepWrapper batch = new AssignOpportunityRepWrapper(repCountList, repInfoMap, new CachedTimezoneServiceWrapper());
        // Prepare one test opportunity
        Account testAccount = new Account(Name = ACCOUNT_NAME,
                                          BillingCountry = COUNTRY_USA,
                                          BillingCity = CITY_NEW_YORK);
        insert testAccount;
        Subsidiary__c subsidiary = new Subsidiary__c();
        insert subsidiary;
        Product_Configuration__c prodConfig = TestData.createProductConfiguration(subsidiary.Id, null, PRODUCT_3);
        String netSuiteId = PRODUCT_3 == 'Kayako' ? '' : String.valueOf(Integer.valueof((Math.random() * 1000000000)));
        String parentSubscriptionId = PRODUCT_3 == 'Kayako' ? 'A-S00000000' : '';
        Opportunity testOpportunity1 = new Opportunity(AccountId = testAccount.Id,
                                                        Account = testAccount,
                                                        Product__c = PRODUCT_3,
                                                        Name = OPP_NAME,
                                                        StageName = STAGE_NAME,
                                                        CloseDate = DateTime.now().addDays(5).date(),
                                                        Type = 'Renewal',
                                                        Renewal_Date__c = DateTime.now().addDays(30).date(),
                                                        NetSuite_ID__c = netSuiteId,
                                                        //Quoting_Entity__c = 'Aclate',
                                                        Parent_Subscription_ID__c = parentSubscriptionId,
                                                        OwnerId = AssignOpportunityRep.SALES_INTEGRATION_USER_ID);
        insert testOpportunity1;
        Opportunity testOpportunity2 = new Opportunity(AccountId = testAccount.Id,
                                                        Account = testAccount,
                                                        Product__c = PRODUCT_3,
                                                        Name = OPP_NAME,
                                                        StageName = STAGE_NAME,
                                                        CloseDate = DateTime.now().addDays(5).date(),
                                                        Type = 'Renewal',
                                                        Renewal_Date__c = DateTime.now().addDays(30).date(),
                                                        NetSuite_ID__c = netSuiteId,
                                                        //Quoting_Entity__c = 'Aclate',
                                                        Parent_Subscription_ID__c = parentSubscriptionId,
                                                        OwnerId = AssignOpportunityRep.SALES_INTEGRATION_USER_ID);
        insert testOpportunity2;
        batch.ProcessOpportunities(new Opportunity[]{
                testOpportunity1, testOpportunity2
        }, true);
        List<Opportunity> opps = [
                SELECT Id, OwnerId, Product__c, StageName, Type, AccountId
                FROM Opportunity
                WHERE Id = :testOpportunity1.Id OR Id = :testOpportunity2.Id
        ];
        System.debug('opps: ' + opps);
        System.assert(opps[0].OwnerId != AssignOpportunityRep.SALES_INTEGRATION_USER_ID, OWNER_ERROR_MSG);
        System.assert(opps[1].OwnerId != AssignOpportunityRep.SALES_INTEGRATION_USER_ID, OWNER_ERROR_MSG);
        System.assert(opps[1].OwnerId == opps[0].OwnerId,
                        'Opportunities from the same account should go to the same rep.');
    }

    @isTest
    static void opportunityOwnerAssignmentSchedulerTest() {
        User userManager = TestData.getUser(MANAGER_PROFILE);
        TestData.updateUserRole(userManager, MANAGER_ROLE);
        TestData.createTestUser(USER_PROFILE, USER_ROLE, PRODUCT_3, userManager);
        Opportunity testOpportunity = prepareTestOpportunity(PRODUCT_3);

        AssignOpportunityRepScheduler scheduler = new AssignOpportunityRepScheduler();
        test.startTest();
        scheduler.execute(null);
        test.stopTest();
        Opportunity opp = [
                SELECT Id, OwnerId
                FROM Opportunity
                WHERE Id = :testOpportunity.Id
        ];
        System.assert(opp.OwnerId != AssignOpportunityRep.SALES_INTEGRATION_USER_ID, OWNER_ERROR_MSG);
    }


    @isTest
    static void draftOpportunityShouldNotBeAssignedTest() {
        User userManager = TestData.getUser(MANAGER_PROFILE);
        TestData.updateUserRole(userManager, MANAGER_ROLE);
        TestData.createTestUser(USER_PROFILE, USER_ROLE, PRODUCT_3, userManager);
        Opportunity testOpportunity = prepareTestOpportunity(PRODUCT_3);
        Opportunity testOpp = [
                SELECT Id
                FROM Opportunity
                WHERE Id = :testOpportunity.Id
        ];
        testOpp.draft__c = true;
        update testOpp;

        AssignOpportunityRepScheduler scheduler = new AssignOpportunityRepScheduler();
        test.startTest();
        scheduler.execute(null);
        test.stopTest();
        Opportunity opp = [
                SELECT Id, OwnerId
                FROM Opportunity
                WHERE Id = :testOpportunity.Id
        ];
        System.assert(opp.OwnerId == AssignOpportunityRep.SALES_INTEGRATION_USER_ID,
                        OWNER_SHOULD_NOT_BE_ASSIGNED_ERROR_MSG);
    }

    @isTest
    static void newBusinessFlagSetFalseOpportunityShouldNotBeAssignedTest() {
        Opportunity testOpportunity = prepareTestOpportunity(PRODUCT_3);
        Product_Configuration__c prodConfig = [
                select Id, New_Business_Enabled__c
                from Product_Configuration__c
                where product__c = :testOpportunity.Product__c
        ];
        prodConfig.New_Business_Enabled__c = false;
        prodConfig.Renewal_Enabled__c = false;
        update prodConfig;

        AssignOpportunityRepScheduler scheduler = new AssignOpportunityRepScheduler();
        test.startTest();
        scheduler.execute(null);
        test.stopTest();
        Opportunity opp = [
                SELECT Id, OwnerId
                FROM Opportunity
                WHERE Id = :testOpportunity.Id
        ];
        System.assert(opp.OwnerId == AssignOpportunityRep.SALES_INTEGRATION_USER_ID,
                        OWNER_SHOULD_NOT_BE_ASSIGNED_ERROR_MSG);
    }

    static Opportunity prepareTestOpportunity(String productName) {

        Account testAccount = new Account(Id = null, Name = ACCOUNT_NAME, 
										  BillingCountry = COUNTRY_USA, 
										  BillingCity = CITY_NEW_YORK);
        insert testAccount;
        Subsidiary__c subsidiary = new Subsidiary__c();
        insert subsidiary;
        Product_Configuration__c prodConfig = TestData.createProductConfiguration(subsidiary.Id, null,productName);
        Opportunity testOpportunity = new Opportunity(AccountId = testAccount.Id, Account = testAccount,
                Product__c = productName, Name = OPP_NAME, StageName = STAGE_NAME,
                CloseDate = DateTime.now().addDays(5).date(), Type = 'New Business',
                OwnerId = AssignOpportunityRep.SALES_INTEGRATION_USER_ID);
        insert testOpportunity;
        return testOpportunity;
    }

    // Timezone overlapping tests
    static AssignOpportunityRep processor = new AssignOpportunityRep();
    @isTest
    static void timezoneOverlappingFullTest() {
        Double dist1 = processor.rangesIntersection(0, 10, 0, 10);
        System.assert(Math.abs(dist1 - 10) < .1, 'Fully overlapping ranges should result in their length (10).');
    }

    @isTest
    static void timezoneOverlappingTouchingTest() {
        Double dist2 = processor.rangesIntersection(0, 10, 10, 20);
        System.assert(Math.abs(dist2) < .1, 'Touching ranges have zero overlapping (0).');
    }

    @isTest
    static void timezoneOverlappingNoOverlapTest() {
        Double dist3 = processor.rangesIntersection(0, 10, 11, 20);
        System.assert(Math.abs(dist3 + 1) < .1, 'Non overlapping ranges should give distance between them (-1).');
    }

    @isTest
    static void timezoneOverlappingSwapRangesTest() {
        Double dist3a = processor.rangesIntersection(11, 20, 0, 10);
        System.assert(Math.abs(dist3a + 1) < .1, 'Swapping ranges should not affect the result (-1).');
    }

    @isTest
    static void timezoneOverlapping24hPeriodTest() {
        Double dist4 = processor.rangesIntersection(0, 10, 12, 23);
        System.assert(Math.abs(dist4 + 1) < .1, 'Distance between ranges should take into consideration 24h period (next day overlapping, -1).');
    }

    @isTest
    static void timezoneOverlappingNegativeTest() {
        Double dist5 = processor.rangesIntersection(-1, 10, 12, 23);
        System.assert(Math.abs(dist5) < .1, 'Negative values should be processed correctly (0).');
    }

    @isTest
    static void timezoneBothNegativeTest() {
        Double dist6 = processor.rangesIntersection(-4, -2, -5, -3);
        System.assert(Math.abs(dist6 - 1) < .1, 'Negative values should be processed correctly (1).');
    }
}