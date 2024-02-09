public class QCHelper {
    
    @InvocableMethod(label='Set QC_Rule_Result for Grading' 
                     description='Resolve metric field path from QC Rule and fill thresholds in QC Rule Result')
    public static QC_Rule_Result__c[][] fillGradingFields(Task[][] taskIds) {
        Map<String, String> apiPaths = new Map<String, String>();
        List<QC_Rule_Result__c[]> batches = new List<QC_Rule_Result__c[]>();
        for (Task[] ts : taskIds) {
            Set<Id> summaryIds = new Set<Id>();
            for (Task t : ts) {
                if (t.QC_Summary__c != null) {
                    summaryIds.add(t.QC_Summary__c);
                }
            }
            List<QC_Scorecard__c> scorecards = [SELECT Id FROM QC_Scorecard__c WHERE QC_Summary__c IN :summaryIds];
            List<Id> scorecardIds = new List<Id>();
            for (QC_Scorecard__c scorecard : scorecards) {
                scorecardIds.add(scorecard.Id);
            }
            List<QC_Rule_Result__c> results = [
                SELECT Id, QC_Scorecard__r.QC_Summary__c, QC_Rule__r.Metric_Field_Path__c
                FROM QC_Rule_Result__c
                WHERE QC_Scorecard__c IN :scorecardIds
                AND QC_Rule__r.Metric_Field_Path__c != NULL
                AND (Result__c = NULL OR Result__c = 'Unable To Grade')
            ];
            Set<String> fieldPaths = new Set<String>();
            for (QC_Rule_Result__c res : results) {
                fieldPaths.add(res.QC_Rule__r.Metric_Field_Path__c);
            }
            List<String> query = new List<String>();
            query.add('SELECT Id, QC_Summary__c');
            for (String field : fieldPaths) {
                String apiPath = getApiPath('Task', field);
                if (apiPath != null) {
                    apiPaths.put(field, apiPath);
                    query.add(', '+apiPath);
                }
            }
            query.add('FROM Task WHERE QC_Summary__c IN :summaryIds');
            Map<Id, Task> tasks = new Map<Id, Task>();
            for (Task task : Database.query(String.join(query,' '))) {
                tasks.put(task.QC_Summary__c, task);
            }
            updateResults(tasks, apiPaths, results);
            batches.add(results);
        }
        return batches;
    }

    private static void updateResults(Map<Id, Task> tasks, 
            Map<String, String> apiPaths, List<QC_Rule_Result__c> results) {
        for (QC_Rule_Result__c res : results) {
            Task task = tasks.get(res.QC_Scorecard__r.QC_Summary__c);
            String apiPath = apiPaths.get(res.QC_Rule__r.Metric_Field_Path__c);
            if (apiPath == null) {
                res.Metric_Value__c = null;
            } else {
                try {
                    res.Metric_Value__c = (Decimal) getPathValue(task, apiPath);
                } catch (TypeException cause) {
                    String msg = 'Metric Field Path of QC Rule {0} is not a Number';
                    String[] args = new String[] { res.QC_Rule__c };
                    System.debug(String.format(msg, args));
                    res.Metric_Value__c = null;
                }
            }
        }
        update results;
    }
    
    public static String getApiPath(String baseType, String fieldPath) {
        if (fieldPath == null) return null;
        SObjectType objType = Schema.getGlobalDescribe().get(baseType);
        List<String> pathNodes = fieldPath.split('[.]');
        List<String> path = new List<String>();
        for (String fieldLabel : pathNodes) {
            Map<String, Schema.SObjectField> fieldMap = objType.getDescribe().fields.getMap();
            for (String fieldName : fieldMap.keySet()) {
                Schema.SObjectField field = fieldMap.get(fieldName);
                Schema.DescribeFieldResult fieldDesc = field.getDescribe();
                if (fieldDesc.getLabel() == fieldLabel) {
                    path.add(fieldDesc.getName());
                    List<Schema.SObjectType> refs = fieldDesc.getReferenceTo();
                    if (refs.isEmpty()) {
                        return String.join(path,'.').replace('__c.','__r.');
                    } else {
                        objType = refs.get(0);
                        break;
                    }
                }
            }
        }
        return null;
    }
    
    public static Object getPathValue(SObject record, String fieldPath) {
        if (fieldPath == null) return null;
        SObject obj = record;
        List<String> fields = fieldPath.split('[.]');
        for (String field : fields) {
            if (obj == null) return null;
            try {
                obj = obj.getSObject(field);
            } catch (SObjectException e) {
                return obj.get(field);
            }
        }
        return obj;
    }
    
}