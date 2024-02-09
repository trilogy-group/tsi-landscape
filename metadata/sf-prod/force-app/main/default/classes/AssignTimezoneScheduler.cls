global class AssignTimezoneScheduler implements Schedulable {
    global void execute(SchedulableContext ctx) {
        try {
            AssignTimezoneBatch assignTimezone = new AssignTimezoneBatch(); 
            Database.executeBatch(assignTimezone, 10);
        }
        catch(Exception e) {
            System.debug('Exception caught: ' + e.getMessage());
        }
    }
}