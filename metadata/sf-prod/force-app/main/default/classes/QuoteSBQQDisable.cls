/**
 * @description: LAMBDA-62633 enable the CPQ quote triggers manually which were disabled to
 *               prevent unable to lock row
 */
public with sharing class QuoteSBQQDisable {
    @InvocableMethod(label='Toggle CPQ Quote Triggers' 
    description='Method to disable SBQQ CPQ quote triggers' category='Quote')
    public static void disableCPQTriggers () {
        if(SBQQ.TriggerControl.isEnabled()) {
            SBQQ.TriggerControl.disable();
        }
    }
}