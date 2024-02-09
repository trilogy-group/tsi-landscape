public with sharing class EmailService implements IEmailService{

    private void sendEmail(String[] toAddresses, String subject, String message, Boolean hideException) {
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(toAddresses);
        mail.setSubject(subject);
        mail.setPlainTextBody(message);

        try {
            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
        } catch(Exception e) {
            if (hideException) {
                System.debug(e);
            } else {
                throw e;
            }
        }
    }

    public void sendEmail(String[] toAddresses, String subject, String message) {
        sendEmail(toAddresses, subject, message, false);
    }

    public void sendEmailToApexExceptionEmails(String subject, String message) {
        List<ApexEmailNotification> admins = [SELECT Email, User.Email FROM ApexEmailNotification];        
        if (admins.size() == 0) {
            System.debug('Didn\'t find any users to send the error email to.');
            return;
        }
        List<String> emailsTo = new List<String>();
        for (ApexEmailNotification admin : admins) {
            emailsTo.add(admin.Email != null ? admin.Email : admin.User.Email);
        }
        sendEmail(emailsTo, subject, message, true);
    }
}