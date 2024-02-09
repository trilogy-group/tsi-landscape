public without sharing class ErrorReporting {
    @TestVisible // Used only for unit tests to prevent wanting to send an email, but still being able to check it
    public static ErrorReportingException LastException;

    @TestVisible
    public static Messaging.SingleEmailMessage LastMessage;

    public static void notifyViaEmail(string subject, string errorMessage) {
        notifyViaEmail(subject, errorMessage, false);
    }

    public static void notifyViaEmail(string subject, string errorMessage, boolean forceRunDuringTests, string toAddress) {
        if (!forceRunDuringTests && Test.isRunningTest()) {
            return;
        }

        List<ApexEmailNotification> admins = [SELECT Email, User.Email FROM ApexEmailNotification];

        if (admins.size() == 0) {
            System.debug('Didn\'t find any users to send the error email to.');
            //throw LastException;
        }

        List<String> emails = new List<String>();

        for (ApexEmailNotification admin : admins) {
            emails.add(admin.Email != null ? admin.Email : admin.User.Email);
        }

        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        if (toAddress != null) {
            mail.setToAddresses(new List<string>{toAddress});
            mail.setCcAddresses(emails);
        } else {
            mail.setToAddresses(emails);
        }
        mail.setSubject(subject);
        String plainTextBody = errorMessage.stripHtmlTags();
        if (errorMessage != plainTextBody) {
            mail.setHtmlBody(errorMessage);
        }
        mail.setPlainTextBody(plainTextBody);

        System.debug('Sending email [subject: ' + subject + ']: ' + errorMessage);
        try {
            if (!Test.isRunningTest()) {
                Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
            } else {
                LastMessage = mail;
            }
        } catch(Exception e) {
            // In sandbox/testing scenario, better throw the error instead of giving
            // "System.EmailException: SendEmail failed. First exception on row 0; first error: NO_MASS_MAIL_PERMISSION"
            // and hiding the actual error
            //LastException = new ErrorReportingException(LastException.getMessage(), e);
            //throw LastException;
            System.debug(e);
        }
    }

    public static void notifyViaEmail(string subject, string errorMessage, boolean forceRunDuringTests) {
        notifyViaEmail(subject, errorMessage, forceRunDuringTests, null);
    }

    public class ErrorReportingException extends Exception {}
}