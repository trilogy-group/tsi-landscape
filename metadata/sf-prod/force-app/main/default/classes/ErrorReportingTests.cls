@isTest
public class ErrorReportingTests {
    public static testMethod void fakeTest() {
        // Act
        ErrorReporting.notifyViaEmail('subject', 'error message', true);

        // Assert
        //System.assertEquals('subject: error message', ErrorReporting.LastException.getMessage());

        System.assertNotEquals(null, ErrorReporting.LastMessage);
        System.assertEquals('subject', ErrorReporting.LastMessage.getSubject());
        System.assertEquals('error message', ErrorReporting.LastMessage.getPlainTextBody());

        List<ApexEmailNotification> admins = [SELECT User.Email FROM ApexEmailNotification];
        System.assertEquals(admins.size(), ErrorReporting.LastMessage.getToAddresses().size());

        ErrorReporting.notifyViaEmail('subject', '<b>error</b> message', true);

        System.assertNotEquals(null, ErrorReporting.LastMessage);
        System.assertEquals('error message', ErrorReporting.LastMessage.getPlainTextBody());
        System.assertEquals('<b>error</b> message', ErrorReporting.LastMessage.getHtmlBody());
    }
}