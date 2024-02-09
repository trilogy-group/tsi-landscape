global class TaskDispatchSchedulerV2 implements Schedulable {
    global void execute(SchedulableContext ctx) {
        try {
            TaskDispatchBatchV2 taskDispatcher = new TaskDispatchBatchV2(); 
            Database.executeBatch(taskDispatcher, 1);
        }
        catch(Exception e){
        	System.debug('Exception caught: ' + e.getMessage());
        }
    }
}