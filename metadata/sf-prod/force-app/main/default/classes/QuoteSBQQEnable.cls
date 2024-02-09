/**
 * @description: LAMBDA-62633 enable the CPQ quote triggers manually which were disabled to
 *               prevent unable to lock row
 */
public with sharing class QuoteSBQQEnable {
    @InvocableMethod(label='Enable Quote CPQ trigger' 
    description='Method to enable SBQQ CPQ quote triggers' category='Quote')
    public static void enableCPQTriggers () {
        if(!SBQQ.TriggerControl.isEnabled()) {
            SBQQ.TriggerControl.enable();
        }
    }
}