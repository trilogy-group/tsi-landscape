public class SubscriptionItem {
    @AuraEnabled
    @InvocableVariable(label='bundleCode')
    public String bundleCode;
    @AuraEnabled
    @InvocableVariable(label='code')
    public String code;
    @AuraEnabled
    @InvocableVariable(label='supportCode')
    public String supportCode;
    @AuraEnabled
    @InvocableVariable(label='quantity')
    public Integer quantity;
    @AuraEnabled
    @InvocableVariable(label='isMainItem')
    public Boolean isMainItem;
    @AuraEnabled
    @InvocableVariable(label='ARR')
    public Double ARR;
    @AuraEnabled
    @InvocableVariable(label='percentARR')
    public Double percentARR;
}