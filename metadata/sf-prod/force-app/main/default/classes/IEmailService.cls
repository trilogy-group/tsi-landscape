public interface IEmailService {
    void sendEmail(String[] toAddresses, String subject, String message);
    void sendEmailToApexExceptionEmails(String subject, String message);
}