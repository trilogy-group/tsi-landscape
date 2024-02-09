@isTest
public without sharing class FeatureAutoRenewTests {
    static Account Account;
    static Product_Configuration__c ProductConfiguration;
    static Set<String> OpportunityIds;
    static Id OwnerId = null;
    final static String OPP_TEST_PREFIX = 'FeatureAutoRenewTests';
    final static String TASK_DISPATCHER_NAME = 'ISR Renewal Task Dispatcher';
    final static String PRODUCT_FAMILY = 'Kayako';
    final static String USER_PROFILE = 'System Administrator';
    final static String MANAGER_PROFILE = 'Team Manager';
    final static String MANAGER_ROLE = 'Manager New Sales';

    @isTest(SeeAllData = true)
    static void noNewTasksForAlreadyCheckedOpportunities() {
      Test.startTest();
        // Given there is a contract with auto renewal clause
        // And there is an opportunity related to this contract
        // And oppurtunity auto renewal check status is updated already
        seedDatabase();
        seedOpportunities(new List<Opportunity>{
                CreateRenewalOpportunity('Yes'), CreateRenewalOpportunity('No')
        });
        // When we generate tasks for opportunities
        TaskDispatchBatchV2 td = new TaskDispatchBatchV2();
        td.processTaskDispatcherByName(TASK_DISPATCHER_NAME);
        
        // Then no new tasks are created
        List<Task> tasks = [
                SELECT Id, Subject
                FROM Task
                WHERE Subject LIKE 'Check%' AND WhatId IN :opportunityIds
        ];
        Test.stopTest();

        System.assert(tasks.size() == 0, 'No tasks should be created for already checked opportunites.');
    }

    @isTest(SeeAllData = true)
    static void tasksShouldBeCreatedForOpportunitiesWithUnknowAutoRenew() {
        // Given there is a contract with auto renewal clause
        // And there is an opportunity related to this contract
        // And oppurtunity auto renewal check status is unknown
        System.debug('Seeding Database');
        seedDatabase();

        OwnerId = getOpportunityOwnerId(true);
        System.debug('Get Owner = ' + OwnerId);

        Test.startTest();
        // Create new opportunity for owner
        Opportunity opp = CreateRenewalOpportunity('Yes');
        opp.CloseDate = System.today()+2;
        opp.Renewal_Date__c = opp.CloseDate + 30;
        opp.StageName = 'OutReach';
        update opp;

        seedOpportunities(new List<Opportunity>{
            opp
        });
        System.debug('created opportunity: ' + opp);
        // When we generate tasks for opportunities
        TaskDispatchBatchV2 td = new TaskDispatchBatchV2();
        td.processTaskDispatcherByName(TASK_DISPATCHER_NAME);
        
        // Then the task is created
        List<Task> tasks = [
                SELECT Id, Subject
                FROM Task
                WHERE Subject like '%Auto-Renew%' AND 
                WhatId IN :opportunityIds
        ];
        
        Test.stopTest();

        // if is not working day will not generate task
        if (TaskDispatchBatchV2.getWorkingDay(System.today()) == System.today()) {
            System.assertEquals(1, tasks.size(), 'A tasks should be created for unchecked opportunity.');
        }
    }

    @isTest(SeeAllData = true)
    static void tasksShouldNotBeCreatedForNonEligibleOpportunitiesWithUnknowAutoRenew() {
        Test.startTest();
        // Given there is a contract with auto renewal clause
        // And there are opportunities related to this contract
        // And oppurtunities auto renewal check status is unknown
        // And the type of one of the oppurtunity is not Renewal
        // And the owner of one of the oppurtunity doesn't belong to the required role
        // And the renewal date of one of the oppurtunity is greater than next 120 days
        seedDatabase();
        Opportunity op1 = CreateRenewalOpportunity(null);
        op1.Type = 'Upsell';
        update op1;

        Opportunity op2 = CreateRenewalOpportunity(null);
        op2.OwnerId = GetOpportunityOwnerId(false);
        update op2;

        Opportunity op3 = CreateRenewalOpportunity(null);
        op3.Renewal_Date__c = System.today().addMonths(5);
        update op3;

        seedOpportunities(new List<Opportunity>{
                op1, op2, op3
        });

        // When we generate tasks for opportunities
        TaskDispatchBatchV2 td = new TaskDispatchBatchV2();
        td.processTaskDispatcherByName(TASK_DISPATCHER_NAME);

        // Then no new tasks are created
        List<Task> tasks = [
                SELECT Id, Subject
                FROM Task
                WHERE Subject LIKE 'Check%' AND WhatId IN :opportunityIds
        ];

        Test.stopTest();
        System.assert(tasks.size() == 0, 'No tasks should be created for non eligible opportunites.');
    }

    @isTest(SeeAllData = true)
    static void reportShouldReturnDataForEligibleRecords() {
        OwnerId = null;
        // When we generate report (which output is used for tasks generation)


        // Given there is a contract with auto renewal clause
        // And there is an opportunity related to this contract
        // And oppurtunity auto renewal check status is unknown
        seedDatabase();

        seedOpportunities(new List<Opportunity>{
                CreateRenewalOpportunity(null)
        });
        String prefixName = ''+OPP_TEST_PREFIX +'%';
		Opportunity testOpportunity = [SELECT Id, Name,Type from Opportunity where Name like :prefixName and Type='Renewal'];
        System.Assert(testOpportunity!=null && testOpportunity.Type == 'Renewal');
        ReportDefinition reportDefinition = GetReportWithLimitedScope('Contract_Has_AutoRenew_Check_1',
                'Task Dispatch Reports');
        Reports.ReportResults reportResult = Reports.ReportManager.runReport(reportDefinition.ReportId,
                reportDefinition.ReportMetadata, true);

        System.assertEquals(1, reportResult.getgroupingsDown().getgroupings().size());
        Reports.ReportFact grandTotal = (Reports.ReportFact) reportResult.getFactMap().get('T!T');
        System.assertEquals(1, (Decimal) grandTotal.getAggregates().get(0).getValue());
    }

    static void seedOpportunities(List<Opportunity> opportunities) {
        OpportunityIds = new Set<String>();
        for (Opportunity opportunity : opportunities) {
            OpportunityIds.add(opportunity.Id);
        }
    }

    static void seedDatabase() {
        Subsidiary__c subsidiary = new Subsidiary__c();
        insert subsidiary;
        ProductConfiguration = TestData.createProductConfiguration(subsidiary.Id, null, 'Kayako');
        Account = new Account(Name = OPP_TEST_PREFIX, BillingCountry = 'USA', BillingCity = 'New York');
        insert Account;
        Up_LAMBDA_10318_Create_Auto_Renewals_Check_Tasks();
    }

    static Id getOpportunityOwnerId(Boolean isInTheRole) {
        Task_Dispatcher__c taskDispatcher = (Task_Dispatcher__c) LinqUtils.first([
                SELECT Id, Name, Task_Timeout__c, User_Role_ID__c,
                        Backlog_Report_IDs__c
                FROM Task_Dispatcher__c
                WHERE Name = :TASK_DISPATCHER_NAME
        ]);

        List<String> userRoleIds = ((String) taskDispatcher.get('User_Role_ID__c')).split(',');

        User userManager = TestData.getUser(MANAGER_PROFILE);
        TestData.updateUserRole(userManager, MANAGER_ROLE);
        User user = null;
        user = TestData.getUser(USER_PROFILE, userManager);
        UserRole role = null;
        if (isInTheRole) {
            role = [SELECT ID, NAME FROM UserRole WHERE id IN :userRoleIds LIMIT 1];
        } else {
            role = [SELECT ID, NAME FROM UserRole WHERE NOT (id IN :userRoleIds) LIMIT 1];
        }

        TestData.updateUserRole(user, role.name);
        return user.id;
    }

    // Create an opportunities with the Next Follow Up Date = Today and an ISR as the Owner
    static Opportunity createRenewalOpportunity(String hasAutoRenewalClause) {
        return createOpportunity('Renewal', hasAutoRenewalClause, System.today().addMonths(1));
    }

    static Opportunity createOpportunity(String type, String hasAutoRenewalClause, Date renewalDate) {
        if (OwnerId == null) {
            OwnerId = getOpportunityOwnerId(true);
        }

        Opportunity opp = new Opportunity(Type = type, 
                CurrentContractHasAutoRenewalClause__c = hasAutoRenewalClause,
                Renewal_Date__c = renewalDate, Name = 'This value will be overwritten by trigger/flow', 
                OwnerId = OwnerId,
                StageName = 'Pending', 
                AccountId = Account.Id, 
                Product_Configuration__c = ProductConfiguration.Id,
                Product__c = PRODUCT_FAMILY, 
                CloseDate = System.today().addMonths(1), 
                Description = 'ApexTest',
                NetSuite_ID__c = String.valueOf(Integer.valueof((Math.random() * 1000000000))),
                //Quoting_Entity__c = 'Aclate',
                Parent_Subscription_ID__c = 'A-S12345678');
        insert opp;
        return opp;
    }

    static ReportDefinition getReportWithLimitedScope(String developerName, String folderName) {
        List<Report> reps = [
                SELECT Id, Name, FolderName, DeveloperName
                FROM Report
                WHERE DeveloperName = :developerName AND FolderName = :folderName
        ];

        System.assertNotEquals(null, LinqUtils.singleOrDefault(reps),
                'Failed to find the single report by dev name \'' +
                        'Contract_Has_AutoRenew_Check_1\' inside the \'' +
                        'Task Dispatch Reports\' reports folder.');

        String reportId = reps[0].Id;

        Reports.ReportMetadata reportMetadata = Reports.ReportManager.describeReport(reportId).getReportMetadata();
        // Add a filter.
        List<Reports.ReportFilter> filters = new List<Reports.ReportFilter>();
        Reports.ReportFilter newFilter = new Reports.ReportFilter();
        newFilter.setFilterType(Reports.ReportFilterType.FIELDVALUE);
        newFilter.setColumn('OPPORTUNITY_NAME');
        newFilter.setOperator('startsWith');
        newFilter.setValue(OPP_TEST_PREFIX);
        filters.add(newFilter);
        reportMetadata.setReportFilters(filters);

        return new ReportDefinition(reportId, reportMetadata);
    }

    private class ReportDefinition {
        Id ReportId;
        Reports.ReportMetadata ReportMetadata;
        public ReportDefinition(Id reportId, Reports.ReportMetadata reportMetadata) {
            this.ReportId = reportId;
            this.ReportMetadata = reportMetadata;
        }
    }

    private static Task_Dispatcher__c createTaskDispatcher() {
        Task_Dispatcher__c taskDispatcher = new Task_Dispatcher__c(Name = TASK_DISPATCHER_NAME, 
            Task_Timeout__c = 1, 
            User_Role_ID__c = '00E2x000000cXlE');
        insert taskDispatcher;
        List<Cadence_Task_Configuration__c> reports = new List<Cadence_Task_Configuration__c>();
        reports.add(new Cadence_Task_Configuration__c(Name = 'a1', Task_Dispatcher__c = taskDispatcher.Id, 
            Report_ID__c = '00O2x000002G16TEAS', SLA__c = 1));
        reports.add(new Cadence_Task_Configuration__c(Name = 'a2', Task_Dispatcher__c = taskDispatcher.Id, 
            Report_ID__c = '00O2x000002G8yNEAS', SLA__c = 1));
        reports.add(new Cadence_Task_Configuration__c(Name = 'a3', Task_Dispatcher__c = taskDispatcher.Id, 
            Report_ID__c = '00O2x000003opGVEAY', SLA__c = 1));
        insert reports;
        return taskDispatcher;
    }

    private static void up_LAMBDA_10318_Create_Auto_Renewals_Check_Tasks() {
        // Get report id
        List<Report> reports = [
                SELECT Id, Name, FolderName, DeveloperName
                FROM Report
                WHERE DeveloperName = 'Contract_Has_AutoRenew_Check_1' AND
                FolderName = 'Task Dispatch Reports'
        ];

        System.assertNotEquals(null, LinqUtils.singleOrDefault(reports),
                'Failed to find the single report by dev name \'' +
                        'Contract_Has_AutoRenew_Check_1\'' +
                        ' inside the \'Task Dispatch Reports\' reports folder.');

        String reportId = reports[0].Id;

        // Get 'ISR Renewal Task Dispatcher' task dispatcher
        List<Task_Dispatcher__c> taskDispatchers = [
                SELECT Id, Name, Task_Timeout__c, User_Role_ID__c, Backlog_Report_IDs__c
                FROM Task_Dispatcher__c
                WHERE Name = :TASK_DISPATCHER_NAME
        ];

        System.assertNotEquals(null, LinqUtils.singleOrDefault(taskDispatchers),
                'Failed to find the single instance of task dispatcher object \'' +
                        'ISR Renewal Task Dispatcher\'.');

        Task_Dispatcher__c taskDispatcher = null;

        // If there is no 'ISR Renewal Task Dispatcher' task dispatcher, create a new one
        if (taskDispatchers.size() == 0) {
            createTaskDispatcher();
        } else {
            taskDispatcher = taskDispatchers[0];
        }

        String reportIds = taskDispatcher.Backlog_Report_IDs__c;

        // If there is no reportId, add it to 'ISR Renewal Task Dispatcher' task dispatcher
        if (reportIds == null || !reportIds.contains(reportId)) {
            reportIds = reportIds + (reportIds == null ? reportId : ',\r\n' + reportId);
            taskDispatcher.Backlog_Report_IDs__c = reportIds;
            update taskDispatcher;
        }

        System.debug('Migration is applied successfully.');
    }
}