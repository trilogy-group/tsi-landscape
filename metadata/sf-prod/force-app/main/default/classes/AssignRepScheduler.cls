global class AssignRepScheduler implements Schedulable {
    global void execute(SchedulableContext ctx) {
        try {
            AssignRepBatch assignRep = new AssignRepBatch(); 
            Database.executeBatch(assignRep, 5);
        }
        catch(Exception e){
            System.debug('Exception caught: ' + e.getMessage());
        }
    }
}