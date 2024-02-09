global class InvalidEmailHandler implements SandboxPostCopy {
    global void runApexClass(SandboxContext context) {
        addInvalidToAll();
    }

    public static void addInvalidToAll() {
        List<Product_Configuration__c> productConfigs = [SELECT Additional_Notification_Party__c, Fulfillment_Email__c 
                                                            FROM Product_Configuration__c];
        for (Product_Configuration__c config : productConfigs) {
            config.Additional_Notification_Party__c = addInvalid(config.Additional_Notification_Party__c);
            config.Fulfillment_Email__c = addInvalid(config.Fulfillment_Email__c);
        }
        update productConfigs;
        InvalidEmailContactBatch contactBatch = new InvalidEmailContactBatch();
        Database.executeBatch(contactBatch,2000);
    }

    public static String addInvalid(String email) {
        if (String.isBlank(email)) {
            return null;
        }
        return email + '.invalid';
    }
}