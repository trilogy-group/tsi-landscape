@isTest 
public with sharing class ElectronicSignTests {
   static final String DOCUMENT_NAME = 'Test';
   static final String AFTER_SENDING_STAGE_NAME = 'Quote Follow-Up';
   static final Id DMITRY_BAKAEV_ID = [SELECT Id FROM User WHERE Name='Dmitry Bakaev'].Id;

   @isTest
   static void e2eTest(){ // Run the process with inserting a CPQ Quote document to test End2End
      Opportunity resultOpportunity = e2eTestCommon('Kayako', 'Renewal', false, false);
      System.assert(resultOpportunity.StageName == AFTER_SENDING_STAGE_NAME, 
         'After sending to signing the opportunity should move to Quote Follow-Up.');
      System.assert(resultOpportunity.Description.contains('quote'), 
         'After sending to signing a record should be added to the description.');
   }

   @isTest
   static void e2eTestManualQuote(){ // We should not process manual quotes
      Opportunity resultOpportunity = e2eTestCommon('SLI', 'Renewal', true, false);
      System.assert(resultOpportunity.StageName != AFTER_SENDING_STAGE_NAME, 
         'Manual quotes should not be processed for eSigning.');
      System.assert(String.isBlank(resultOpportunity.Description), 
         'Manual quotes should not be processed for eSigning.');
   }

   @isTest
   static void e2eTestProcessViaOtcQuote(){ // We should not process manual quotes
      Opportunity resultOpportunity = e2eTestCommon('SLI', 'Renewal', false, true);
      System.assert(resultOpportunity.StageName != AFTER_SENDING_STAGE_NAME, 
         'Quotes processed via OTC should not be processed for eSigning.');
      System.assert(String.isBlank(resultOpportunity.Description), 
         'Quotes processed via OTC should not be processed for eSigning.');
   }
   
   
   // Creates an opportunity with the given Owner, Product Familty and Type and runs the eSigning sequence with the config given
   static Opportunity e2eTestCommon(String family, String type,  Boolean manualQuote, Boolean prcessedViaOtc ){
      Test.startTest();
      SBQQ.TriggerControl.disable();
      User user = TestData.getUser('System Administrator');
      
      
      // Product_Configuration__c
      Subsidiary__c subsidiary = new Subsidiary__c(
               Name = 'Skyvera, LLC',
               City__c = 'New York',
               State__c = 'NY',
               Country__c = 'United States',
               Street__c = 'Test Broadway and fifth'
      );
      insert subsidiary;
      Product_Configuration__c prodConfig = TestData.createProductConfiguration(subsidiary.Id, null, family);
      prodConfig.Manual_Quote__c = manualQuote;
      prodConfig.Processed_via_OTC__c = prcessedViaOtc;
      update prodConfig;
      Product_Configuration__c prodConfigDb = [SELECT Id FROM Product_Configuration__c
                                               WHERE Id = :prodConfig.Id];

      user.echosign_dev1__EchoSign_Allow_Delegated_Sending__c = true;
      user.echosign_dev1__EchoSign_Email_Verified__c = true;
      update user;

      User dmitryUser = [select Id from User where id = :DMITRY_BAKAEV_ID];
      System.runAs(dmitryUser) {
         UserRole userRole = [select id from UserRole where name = 'System Administrator'];
        
         user.UserRoleId = userRole.Id;
         user.isActive = true;
         update user;
      }

      // 'Quote Approver' is not configured in the 'Product Configuration'
      Opportunity testOpportunity = TestData.createOpportunityForCPQDocument(type, family);
      testOpportunity.OwnerId = user.Id;
      testOpportunity.Product__c = family;
      testOpportunity.Type = type;
      testOpportunity.Product_Configuration__c = prodConfigDb.Id;
      testOpportunity.Product_Configuration__r = prodConfigDb;
      testOpportunity.StageName = 'Final Quote';
      testOpportunity.NetSuite_ID__c = 'TEST-ElectronicSignTests-'+family;
      testOpportunity.Addresses_Validated__c = true;
      update testOpportunity;

      SBQQ__QuoteDocument__c doc = TestData.createCpqQuoteDocument(testOpportunity, DOCUMENT_NAME); // Insert trigger for SBQQ_QuoteDocument is executed        
      SBQQ.TriggerControl.enable();
      update new SBQQ__Quote__c(Id = doc.SBQQ__Quote__c, SBQQ__Status__c = 'Accepted');

      List<SBQQ__QuoteDocument__c> toSend = new List<SBQQ__QuoteDocument__c>();
      toSend.add(doc);
      QuoteSigningQueuable.EnqueueSigningTasks(toSend);
      Test.stopTest();
      Opportunity resultOpportunity = [SELECT StageName, Description, Product_Configuration__c 
                                       FROM Opportunity WHERE Id=:testOpportunity.Id];

      return resultOpportunity;
   }
}