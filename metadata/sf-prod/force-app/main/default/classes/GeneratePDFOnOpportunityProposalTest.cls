@IsTest
private class GeneratePDFOnOpportunityProposalTest {
  static SBQQ__Quote__c arrange(Boolean templateNeeded) {
    //Arrange
    SBQQ.TriggerControl.disable();
    UpdateOpportunityMRRFromProductsTest.arrange('Monthly', 15.00, 20, '1', false);
    SBQQ.TriggerControl.enable();
    Opportunity opp = [SELECT Id, Name, StageName, AccountId FROM Opportunity];
    Contact contact = new Contact(Email = 'test@test.tt', LastName = 'Test', AccountId = opp.AccountId);
    insert contact;
    OpportunityContactRole contactRole = new OpportunityContactRole(
      IsPrimary = true,
      ContactId = contact.Id,
      OpportunityId = opp.Id
    );

    insert contactRole;
    Id templateId = null;
    if(templateNeeded) {
        SBQQ__QuoteTemplate__c template = new SBQQ__QuoteTemplate__c(
        Name = 'Sococo Template',
        SBQQ__Default__c = true
        );
        insert template;
        templateId=template.Id;
    }

    SBQQ__Quote__c quote = [SELECT SBQQ__Type__c , SBQQ__SubscriptionTerm__c, SBQQ__PricebookId__c, SBQQ__QuoteTemplateId__c FROM SBQQ__Quote__c];
    quote.SBQQ__QuoteTemplateId__c = templateId;
    quote.SBQQ__Status__c = 'Accepted';
    update quote;
    return quote;
  }

  @IsTest
  static void generatePDFTest() {
    SBQQ__Quote__c quote = arrange(true);
    Opportunity opp = [SELECT Id, Name, StageName FROM Opportunity];
    opp.StageName = 'Final Quote';
    // Act
    Test.startTest();
    quote.SBQQ__Status__c = 'Accepted'; // trigger pdf generation
    update quote;
    Test.stopTest();

    // Assert
    SBQQ__QuoteDocument__c document = [
      SELECT Id, Name, SBQQ__Opportunity__c
      FROM SBQQ__QuoteDocument__c
    ][0];
    System.assertEquals(
      QuoteDocumentMockGenerator.TEST_QUOTE_GENERATED_DOCUMENT,
      document.Name
    );
  }

  @IsTest
  static void contextCheckTest() {
    SBQQ__Quote__c quote = arrange(false);
    CPQGenerateQuotePDF generator = new CPQGenerateQuotePDF();
    String result = generator.save(
      quote.Id,
      quote.SBQQ__QuoteTemplateId__c,
      'Test'
    );
    System.assert(result == 'test'); // We do not need to check anything, we just want to ensure this does not fail with an exception
  }

  @IsTest
  static void noTemplateIdSetTest() {
    SBQQ__Quote__c quote = arrange(false);    

    // Act
    Test.startTest();
    quote.SBQQ__Status__c = 'Accepted'; // trigger pdf generation
    update quote;
    Test.stopTest();

    // Assert
    List<SBQQ__QuoteDocument__c> documents = [
      SELECT Id, Name, SBQQ__Opportunity__c
      FROM SBQQ__QuoteDocument__c
    ];
    System.assert(
        documents.size() == 0,
        'No document should be generated without TemplateId set'
    );

    System.assertNotEquals(null, ErrorReporting.LastMessage, 'An error should be generated if TemplateId is not set.');
  }
}