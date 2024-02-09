public with sharing class EmailServiceMock implements IEmailService {   
    private void sendEmail(String subject, String message) {
        // Should always have a valid email address to simulate
        // In unit tests no actual emails are sent
        // If you want to receive an email, change to your email and execute from anonymous window
        List<String> emails = new List<String>();
        emails.add('test@trilogy.com');
        
        if (emails.size() > 0) { 
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(emails);
            mail.setSubject('Mock Email: ' + subject);
            mail.setPlainTextBody(message);
            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
        }
    }

    public void sendEmail(String[] toAddresses, String subject, String message) {
        sendEmail(subject, message);
    }

    public void sendEmailToApexExceptionEmails(String subject, String message) {
        sendEmail(subject,message);
    }
}