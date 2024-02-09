// if you get this error when running tests in sandbox:
// System.EmailException: SendEmail failed. First exception on row 0; first error: NO_MASS_MAIL_PERMISSION, 
// Single email is not enabled for your organization or profile.: []
// You need to go in Setup > Email > Deliverability and change 'Access level' to 'All email'

@isTest
public class EmailServiceTest {
    static final string ERROR_MESSAGE = 'At least one email should be sent';

    @isTest static void emailShouldBeSentToDirectAddress() {
        Injector.getInstance().useDefaultConfig();
        IEmailService emailService = Injector.getInstance().getEmailService();
        emailService.sendEmail(new String[]{'test@trilogy.com'},'subject','message');
        Integer invocations = Limits.getEmailInvocations();
        System.assertNotEquals(0, invocations, ERROR_MESSAGE);
        
        Injector.getInstance().setConfig(Injector.EmailServiceName,'EmailServiceMock');
        emailService = Injector.getInstance().getEmailService();
        emailService.sendEmail(new String[]{'test@trilogy.com'},'subject','message');
        Integer invocationsMock = Limits.getEmailInvocations();
        System.assertNotEquals(invocations, invocationsMock, ERROR_MESSAGE);
    }

    @isTest static void emailShouldBeSentToApexExceptionEmails() {
        Injector.getInstance().useDefaultConfig();
        IEmailService emailService = Injector.getInstance().getEmailService();
        emailService.sendEmailToApexExceptionEmails('subject','message');
        
        Integer invocations = Limits.getEmailInvocations();
        Boolean isSandbox = [SELECT IsSandbox FROM Organization LIMIT 1].IsSandbox;
        // in sandbox we may don't have any apex exception email configured
        if (!isSandbox) {
            System.assertNotEquals(0, invocations, ERROR_MESSAGE);
        }
        
        Injector.getInstance().setConfig(Injector.EmailServiceName,'EmailServiceMock');
        emailService = Injector.getInstance().getEmailService();
        emailService.sendEmailToApexExceptionEmails('subject','message');
        Integer invocationsMock = Limits.getEmailInvocations();
        System.assertNotEquals(invocations, invocationsMock, ERROR_MESSAGE);
    }

    @isTest static void wrongEmailShouldNotBeSent() {
        Injector.getInstance().useDefaultConfig();
        IEmailService emailService = Injector.getInstance().getEmailService();
        Exception error = null;
        try {
            emailService.sendEmail(new String[]{'test'},'subject','message');
        } catch (Exception ex) {
            error = ex;
        }
        System.assertNotEquals(null, error, 'Exception should be triggered');
    }
}