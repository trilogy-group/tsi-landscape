@isTest
public class InvalidEmailTests {
    @isTest
    static void invalidEmailTest() {
        //Arrange
        String emailTest = 'test@test.com';
        Contact contact = new Contact(
            Email = emailTest,
            LastName = 'test'
        );
        insert contact;
        
        Subsidiary__c subsidiary = new Subsidiary__c();
        insert subsidiary;
		Product_Configuration__c prodConfig = TestData.createProductConfiguration(subsidiary.Id, null, TestData.PRODUCT_FAMILY);
		prodConfig.Additional_Notification_Party__c = emailTest;
        prodConfig.Fulfillment_Email__c = emailTest;
        update prodConfig;
        Product_Configuration__c prodConfigNoEmail = TestData.createProductConfiguration(subsidiary.Id, null, TestData.PRODUCT_FAMILY);
        prodConfigNoEmail.Fulfillment_Email__c=null;
        update prodConfigNoEmail;
        //Act
        Test.startTest();
        Test.testSandboxPostCopyScript(new InvalidEmailHandler(), UserInfo.getOrganizationId(),
            UserInfo.getOrganizationId(), UserInfo.getOrganizationName());
        Test.stopTest();

        //Assert
        contact = [SELECT Email FROM Contact WHERE Id = :contact.Id];
        prodConfig = [SELECT Additional_Notification_Party__c, Fulfillment_Email__c 
                        FROM Product_Configuration__c WHERE Id = :prodConfig.Id];
        prodConfigNoEmail = [SELECT Additional_Notification_Party__c, Fulfillment_Email__c 
                                FROM Product_Configuration__c WHERE Id = :prodConfigNoEmail.Id];
        String invalidEmail = emailTest + '.invalid';
        System.assertEquals(invalidEmail, contact.Email, 'The contact email address is not invalid.');
        System.assertEquals(invalidEmail, prodConfig.Additional_Notification_Party__c, 
            'The Additional Notification Party email address is not invalid.');
        System.assertEquals(invalidEmail, prodConfig.Fulfillment_Email__c, 
            'The Fulfillment email address is not invalid.');
        System.assertEquals(null, prodConfigNoEmail.Fulfillment_Email__c, 
            'The Fulfillment email address should be null.');
    }
}