@isTest(seeAllData = false)
public class QCHelperTest {
    
    @IsTest
    static void fillGradingFields_ShouldFillValueWhenOkay() {
        String callDurationField = 'Call Coach Metrics.Call Duration';
        QC_Summary__c summary = new QC_Summary__c();
        insert summary;
        QC_Scorecard__c scorecard = new QC_Scorecard__c();
        scorecard.QC_Summary__r = summary;
        scorecard.QC_Summary__c = summary.Id;
        insert scorecard;
        Task task = new Task();
        task.QC_Summary__r = summary;
        task.QC_Summary__c = summary.Id;
        insert task;
        QC_Rule__c rule = new QC_Rule__c();
        rule.Enforced_On__c = 'Renewal Call';
        rule.Metric_Field_Path__c = callDurationField;
        insert rule;
        QC_Rule_Result__c result = new QC_Rule_Result__c();
        result.QC_Rule__r = rule;
        result.QC_Rule__c = rule.Id;
        result.QC_Scorecard__r = scorecard;
        result.QC_Scorecard__c = scorecard.Id;
        result.Result__c = 'Unable To Grade';
        insert result;
        System.assert(result.QC_Scorecard__r != null);
        // no metrics
        Task[][] tasks = new Task[][]{ new Task[]{ task }};
        result = QCHelper.fillGradingFields(tasks).get(0).get(0);
        System.assertEquals(null, result.Metric_Value__c);
        // result already set
        TCAP__Call_Coach_Metrics__c metrics = new TCAP__Call_Coach_Metrics__c();
        metrics.TCAP__Call_Duration__c = 44;
        insert metrics;
        task.TCAP__Call_Coach_Metrics__r = metrics;
        task.TCAP__Call_Coach_Metrics__c = metrics.Id;
        update task;
        rule.Metric_Field_Path__c = callDurationField;
        update rule;
        result.Result__c = 'Fail';
        update result;
        SObject obj = task;
        obj = obj.getSObject('TCAP__Call_Coach_Metrics__r');
        System.assertEquals(44, obj.get('TCAP__Call_Duration__c'));
        QC_Rule_Result__c[] results = QCHelper.fillGradingFields(tasks).get(0);
        System.assertEquals(0, results.size());
        // no metric field
        result.Result__c = null;
        update result;
        rule.Metric_Field_Path__c = null;
        update rule;
        results = QCHelper.fillGradingFields(tasks).get(0);
        System.assertEquals(0, results.size());
        // invalid metric field: not exists
        rule.Metric_Field_Path__c = 'Garbage.More Garbage';
        update rule;
        result = QCHelper.fillGradingFields(tasks).get(0).get(0);
        System.assertEquals(null, result.Metric_Value__c);
        // invalid metric field: not a number
        rule.Metric_Field_Path__c = 'Call Coach Metrics.Call Coach Metrics';
        update rule;
        result = QCHelper.fillGradingFields(tasks).get(0).get(0);
        System.assertEquals(null, result.Metric_Value__c);
        // okay
        rule.Metric_Field_Path__c = callDurationField;
        update rule;
        result = QCHelper.fillGradingFields(tasks).get(0).get(0);
        System.assertEquals(44, result.Metric_Value__c);
    }
        
    @IsTest
    static void getApiPath_ShouldReturnApiNames() {
        System.assertEquals('Type', QCHelper.getApiPath('Task', 'Type'));
        System.assertEquals('QC_Summary__r.Name', QCHelper.getApiPath('Task', 'QC Summary.QC Summary Name'));
        System.assertEquals(null, QCHelper.getApiPath('Task', 'Not_A_Valid_Field__c'));
        System.assertEquals(null, QCHelper.getApiPath('Task', null));
    }
    
    @IsTest
    static void getPathValue_ShouldReturnValue() {
        QC_Summary__c summary = new QC_Summary__c();
        Task t = new Task(Type = 'Call', QC_Summary__r=summary);
        System.assertEquals('Call', QCHelper.getPathValue(t, 'Type'));
        System.assertEquals(summary, QCHelper.getPathValue(t, 'QC_Summary__r'));
        System.assertEquals(null, QCHelper.getPathValue(t, null));
        System.assertEquals(null, QCHelper.getPathValue(t, 'Task_Dispatcher__c.Name'));
    }
}