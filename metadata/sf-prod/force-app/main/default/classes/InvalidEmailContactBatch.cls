public with sharing class InvalidEmailContactBatch implements Database.Batchable<sObject> {
    public Database.QueryLocator start(Database.BatchableContext bc){
        return Database.getQueryLocator(
            'SELECT Email FROM Contact WHERE (NOT Email like \'%.invalid\') and Email != null');
    }

    public void execute(Database.BatchableContext bc, List<sObject> contacts) {
        addInvalidToContacts(contacts);
    }

    public void finish(Database.BatchableContext bc) {
    }

    private void addInvalidToContacts(List<Contact> contacts) {
        for (Contact contact : contacts) {
            contact.Email = InvalidEmailHandler.addInvalid(contact.Email);
        }
        update contacts;
    }
}