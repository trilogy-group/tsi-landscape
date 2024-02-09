global class TaskWrapper implements Comparable {
    public Task tsk;
    public TaskWrapper(Task t) {
        if(prioritiesOrder == null) { initMap(); }
        tsk = t;
    }
    global Integer compareTo(Object compareTo) { // Sorting is done based on the picklist position. All missing values are below and threated as the same value
        TaskWrapper compareToTask = (TaskWrapper)compareTo;
        Integer returnValue = 0;
        Integer t = 999;
        Integer tCompare = 999;
        if(prioritiesOrder.containsKey(tsk.priority)) { t = prioritiesOrder.get(tsk.priority); }
        if(prioritiesOrder.containsKey(compareToTask.tsk.priority)) { tCompare = prioritiesOrder.get(compareToTask.tsk.priority); }
        if (t > tCompare) {
            returnValue = 1;
        } else if (t < tCompare) {
            returnValue = -1;
        }
        return returnValue;      
    }

    // Priority order support
    static Map<String, Integer> prioritiesOrder;
    static void initMap() {
        prioritiesOrder = new Map<String, Integer>();
        List<String> priorities = getPriorityPickListValues();
        for (Integer i = 0; i < priorities.size(); i++) {
            prioritiesOrder.put(priorities[i], i);
        }
    }

    public static List<String> getPriorityPickListValues() {
        List<String> pickListValuesList= new List<String>();
        Schema.DescribeFieldResult fieldResult = Task.Priority.getDescribe();
        List<Schema.PicklistEntry> ple = fieldResult.getPicklistValues();
        for( Schema.PicklistEntry pickListVal : ple) {
            pickListValuesList.add(pickListVal.getLabel());
        }     
        return pickListValuesList;
    }
}