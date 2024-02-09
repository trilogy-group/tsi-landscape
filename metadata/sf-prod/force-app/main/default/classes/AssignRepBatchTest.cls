@isTest
public class AssignRepBatchTest{

	static final String TIME_ZONE_1 = 'America/Los_Angeles';
	static final String ASSERT_OWNER_MESSAGE = 'Owners should be from the dictionaries only.';
	static final String ROLE_TO_DISTRIBUTE_TO = 'ISR New Business';
	
	@isTest
	static void repCountSortTest(){
		 // Check that RepCount items are really sorted by count
		// Arrange
		List<RepCount> sortedList = new List<RepCount>();
		RepCount greaterItem = new RepCount();
		greaterItem.repId = TestData.getFakeId(User.getSObjectType());
		greaterItem.count = 100;
		RepCount smallerItem = new RepCount();
		smallerItem.repId = TestData.getFakeId(User.getSObjectType());
		smallerItem.count = 0;
		sortedList.add(greaterItem);
		sortedList.add(smallerItem);
		// Act
		sortedList.sort();
		// Assert
		System.assertEquals(sortedList[0], smallerItem, 'RepCount item with smaller count should come first after sorting.');
		System.assertEquals(sortedList[1], greaterItem, 'RepCount item with greater count should come last after sorting.');
	}

	private class AssignRepBatchE2EWrapper extends AssignRepBatch{
		private String productName;
		public AssignRepBatchE2EWrapper(String productName){
			this.productName = productName;
		}

		 // The batch wrapper for an E2E test
		protected override void updateLeads(){
			 // Instead of saving we will make assertions here
			System.assert(leadsToBeUpdated.size() > 0, 'We should have results for saving in DB.');
			System.assert(leadsToBeUpdated[0].OwnerId != null, 'OwnerId should be assigned to the lead.');
			Id assignedRep = leadsToBeUpdated[0].OwnerId;
			System.assert(isCertifiedForTheProduct(assignedRep, this.productName), 
				String.format('The assigned lead should have necessary product certification ({0}).',
				new String[]{this.productName}));
			System.assert(productCertifications.size() > 0, 'We should have product certification loaded.');
			System.assert(workingHoursMidpointUtc.size() > 0, 'We should have working hours calculated.');
		}
	}

	@isTest
	static void fullIntegrationTest(){
		String productName = TestData.getProductNameFromActiveRoleUser(ROLE_TO_DISTRIBUTE_TO);
		 // Run the end-to-end workflow
		AssignRepBatch batch = new AssignRepBatchE2EWrapper(productName);
		List<Lead> unassignedLeads = new List<Lead>();
		unassignedLeads.add(new Lead(Id = TestData.getFakeId(Lead.getSObjectType()), OwnerId = null, Country = null, 
			PostalCode = null, City = null, Set_Google_Timezone__c = true, Product__c = productName, 
			Timezone__c = TIME_ZONE_1));
		batch.execute((Database.BatchableContext)null, unassignedLeads);
	}

	private class AssignRepBatchMidpointChecksWrapper extends AssignRepBatch{
		 // The batch wrapper for testing timezone
		public AssignRepBatchMidpointChecksWrapper(){
			workingHoursMidpointUtc = new Map<Id, Double>();
			Id fakeUserId = TestData.getFakeId(User.getSObjectType());
			workingHoursMidpointUtc.put(fakeUserId, 5);
			System.assert(Math.abs(getDayMidpointUtc(fakeUserId)-5.0) <.1, 'Midpoint does not corresponds to the value saved.');
			System.assert(Math.abs(getDayMidpointUtc(TestData.getFakeId(User.getSObjectType()))-20.0) <.1, 'Unknown timezones should resolves to midpoint equal  20.');
		}
	}

	@isTest
	static void midpointMapTest(){
		 // Run the end-to-end workflow
		new AssignRepBatchMidpointChecksWrapper();
	}

	private class AssignRepBatchDBStubsWrapper extends AssignRepBatch{
		 // The batch wrapper for E2E testing with predefined dictionaries
		public AssignRepBatchDBStubsWrapper(List<User> allRepsData, List<RepCount> repIdsOrderedByCountData, Map<Id, Double> workingHoursMidpointUtcData){
			workingHoursMidpointUtc = workingHoursMidpointUtcData;
			allReps = allRepsData;
			repIdsOrderedByCount = repIdsOrderedByCountData;
		}

		// Public wrappers for protected members
		public List<Lead> leadsToBeUpdatedPublic(){
			return leadsToBeUpdated;
		}

		public List<RepCount> repIdsOrderedByCountPublic(){
			return repIdsOrderedByCount;
		}

		public Boolean isCertifiedForTheProductPublic(Id repId, String product){
			fillProductCertifications();
			return isCertifiedForTheProduct(repId, product);
		}

		// Skip  all method interacting with DB
		protected override void orderRepsByCount(){
		}

		protected override void fillAllReps(){
		}

		protected override void updateLeads(){
		}
	}

	static AssignRepBatchDBStubsWrapper getWrapperWithTwoReps(){
		 // Prepare test data with 2 Sococo reps
		List<RepCount> repCountList = new List<RepCount>(); // Leads count data
		RepCount rep1 = new RepCount();
		rep1.repId = TestData.getFakeId(User.getSObjectType());
		rep1.count = 0;
		RepCount rep2 = new RepCount();
		rep2.repId = TestData.getFakeId(User.getSObjectType());
		rep2.count = 0;
		repCountList.add(rep1);
		repCountList.add(rep2);

		List<User> users = new List<User>(); // User certification data
		users.add(new User(Id = rep1.repId, Product_Certifications__c = 'Sococo'));
		users.add(new User(Id = rep2.repId, Product_Certifications__c = 'Sococo'));

		AssignRepBatchDBStubsWrapper batch = new AssignRepBatchDBStubsWrapper(users, repCountList, new Map<Id, Double>());
		return batch;
	}

	static List<Lead> getTwoUnassignedLeads(){
		List<Lead> unassignedLeads = new List<Lead>();
		unassignedLeads.add(new Lead(Id = TestData.getFakeId(Lead.getSObjectType()), OwnerId = null, Country = null, PostalCode = null, City = null, Set_Google_Timezone__c = true, Product__c = 'Sococo', Timezone__c = TIME_ZONE_1));
		unassignedLeads.add(new Lead(Id = TestData.getFakeId(Lead.getSObjectType()), OwnerId = null, Country = null, PostalCode = null, City = null, Set_Google_Timezone__c = true, Product__c = 'Sococo', Timezone__c = TIME_ZONE_1));
		return unassignedLeads;
	}

	@isTest
	static void equalOwnersDistributionTest(){
		 // Run the end-to-end workflow without DB
		// Arrange
		AssignRepBatchDBStubsWrapper batch = getWrapperWithTwoReps();
		List<Lead> unassignedLeads = getTwoUnassignedLeads();
		// Act
		batch.execute((Database.BatchableContext)null, unassignedLeads);

		// Assert
		List<Lead> result = batch.leadsToBeUpdatedPublic();
		assertResultSize(result);
		System.assert(result[0].OwnerId != result[1].OwnerId, 'Records should be distributed equally.');
		assertOwnerSource(result, batch);
	}

	@isTest
	static void samecompanyTest(){
		 // Run the end-to-end workflow without DB
		// Arrange
		AssignRepBatchDBStubsWrapper batch = getWrapperWithTwoReps();
		List<Lead> unassignedLeads = getTwoUnassignedLeads();
		unassignedLeads[0].Company = 'Real Company';
		unassignedLeads[1].Company = 'Real Company';
		// Act
		batch.execute((Database.BatchableContext)null, unassignedLeads);
		// Assert
		List<Lead> result = batch.leadsToBeUpdatedPublic();
		assertResultSize(result);
		System.assert(result[0].OwnerId == result[1].OwnerId, 'Leads from the same company should get the same ISR.');
	}

	@isTest
	static void equalOwnersDistributionWithoutTimezoneTest(){
		 // Run the end-to-end workflow without timezone assigned to the leads
		// Arrange
		AssignRepBatchDBStubsWrapper batch = getWrapperWithTwoReps();
		List<Lead> unassignedLeads = new List<Lead>();
		unassignedLeads.add(new Lead(Id = TestData.getFakeId(Lead.getSObjectType()), OwnerId = null, Country = null, PostalCode = null, City = null, Set_Google_Timezone__c = true, Product__c = 'Sococo', Timezone__c = null));
		unassignedLeads.add(new Lead(Id = TestData.getFakeId(Lead.getSObjectType()), OwnerId = null, Country = null, PostalCode = null, City = null, Set_Google_Timezone__c = true, Product__c = 'Sococo', Timezone__c = null));

		// Act
		batch.execute((Database.BatchableContext)null, unassignedLeads);

		//Assert
		List<Lead> result = batch.leadsToBeUpdatedPublic();
		assertResultSize(result);
		System.assert(result[0].OwnerId != result[1].OwnerId, 'Records should be distributed equally.');
		assertOwnerSource(result, batch);
	}

	@isTest
	static void wrongProductTest(){
		 // Run the end-to-end workflow with no matching products
		// Arrange
		AssignRepBatchDBStubsWrapper batch = getWrapperWithTwoReps();
		List<Lead> unassignedLeads = new List<Lead>();
		unassignedLeads.add(new Lead(Id = TestData.getFakeId(Lead.getSObjectType()), OwnerId = null, Country = null, PostalCode = null, City = null, Set_Google_Timezone__c = true, Product__c = 'Kayako', Timezone__c = null));

		// Act
		batch.execute((Database.BatchableContext)null, unassignedLeads);

		//Assert
		List<Lead> result = batch.leadsToBeUpdatedPublic();
		System.assertEquals(0, result.size(), 'Records should not receive uncertified owner. Lead product should match the ISR certification.');
	}

	@isTest
	static void noCertTest(){
		 // Check the case with missing certification
		AssignRepBatchDBStubsWrapper batch = getWrapperWithTwoReps();
		System.assertEquals(false, batch.isCertifiedForTheProductPublic(TestData.getFakeId(User.getSObjectType()), 'Sococo'), 'Not existing ISR should not have a certification.');
	}

	@isTest
	static void dataLoadTest(){
		 // Run the end-to-end workflow
		// Let's create a lead before the test run
		String productName = TestData.getProductNameFromActiveRoleUser(ROLE_TO_DISTRIBUTE_TO);
		//Product Configuration
		createProductConfiguration(productName);

		Lead lead = new Lead(OwnerId = [SELECT Id FROM User
										WHERE Product_Certifications__c INCLUDES (:productName) AND IsActive = true 
										AND UserRole.Name = :ROLE_TO_DISTRIBUTE_TO LIMIT 1].Id, Country = null, PostalCode = null, 
										LastName = TestData.LAST_NAME, Company = TestData.TEST_COMPANY, City = null, 
										Set_Google_Timezone__c = true, Product__c = productName, Timezone__c = TIME_ZONE_1);
		insert lead;
		AssignRepBatch batch = new AssignRepBatchE2EWrapper(productName);
		List<Lead> unassignedLeads = new List<Lead>();
		unassignedLeads.add(new Lead(Id = TestData.getFakeId(Lead.getSObjectType()), OwnerId = null, Country = null, 
			PostalCode = null, City = null, Set_Google_Timezone__c = true, Product__c = productName, 
			Timezone__c = TIME_ZONE_1));
		batch.execute((Database.BatchableContext)null, unassignedLeads); // Assertions are in the wrapper
	}

	private static void createProductConfiguration(String productName) {
		Subsidiary__c subsidiary = new Subsidiary__c();
		insert subsidiary;
        Product_Configuration__c prodConfig = TestData.createProductConfiguration(subsidiary.Id, null, productName);
	}

	@isTest
	static void schedulerTest(){
		 // Run the end-to-end workflow
		// Let's create a lead before the test run
		//Product Configuration
		createProductConfiguration('Sococo');

		Lead lead = new Lead(LastName = TestData.LAST_NAME, Company = TestData.TEST_COMPANY, Set_Google_Timezone__c = true, Product__c = 'Sococo', Timezone__c = TIME_ZONE_1);
		insert lead;

		Test.startTest();
		AssignRepBatch assignRep = new AssignRepBatch();
		Database.executeBatch(assignRep, 50);
		Test.stopTest();


		Lead leadFromDB = [SELECT Id, OwnerId
		                   FROM Lead];
		assertOwnerIsNotNull(leadFromDb.OwnerId);
	}

	@isTest
	static void e2eWithCompaniesTest(){
		 // Run the end-to-end workflow for leads from the same company
		// Let's create a lead before the test run
		//Product Configuration
		createProductConfiguration('Sococo');

		Lead lead = new Lead(LastName = TestData.LAST_NAME, Company = TestData.TEST_COMPANY, Set_Google_Timezone__c = true, Product__c = 'Sococo', Timezone__c = TIME_ZONE_1);
		insert lead;

		Test.startTest();
		AssignRepBatch assignRep = new AssignRepBatch();
		Database.executeBatch(assignRep, 50);

		Lead lead2 = new Lead(LastName = TestData.LAST_NAME, Company = TestData.TEST_COMPANY, Set_Google_Timezone__c = true, Product__c = 'Sococo', Timezone__c = TIME_ZONE_1);
		insert lead2;

		assignRep = new AssignRepBatch();
		Database.executeBatch(assignRep, 50);
		Test.stopTest();

		List<Lead> leadFromDB = [SELECT Id, OwnerId, Company
		                         FROM Lead];
		List<AggregateResult> testRes = [SELECT Lead.OwnerId, count(Id)cnt
		                                 FROM Lead
		                                 GROUP BY Lead.OwnerId
		                                 ORDER BY COUNT(Lead.Id) ASC];
		System.debug(testRes);
		System.debug(leadFromDb);
		assertOwnerIsNotNull(leadFromDb[0].OwnerId);
		assertOwnerIsNotNull(leadFromDb[1].OwnerId);
		System.assert(leadFromDb[0].OwnerId == leadFromDb[1].OwnerId, 'Owner should be the same for leads from the same company.');
	}

	private static void assertResultSize(List<Lead> result) {
		System.assertEquals(2, result.size(), 'All records should receive an Owner.');
	}

	private static void assertOwnerSource(List<Lead> result, AssignRepBatchDBStubsWrapper batch) {
		System.assert(result[0].OwnerId == batch.repIdsOrderedByCountPublic()[0].repId || result[0].OwnerId == batch.repIdsOrderedByCountPublic()[1].repId, ASSERT_OWNER_MESSAGE);
		System.assert(result[1].OwnerId == batch.repIdsOrderedByCountPublic()[0].repId || result[1].OwnerId == batch.repIdsOrderedByCountPublic()[1].repId, ASSERT_OWNER_MESSAGE);
	}

	private static void assertOwnerIsNotNull(Id ownerId) {
		System.assert(ownerId != null, 'Owner should be assigned.');
	}
}