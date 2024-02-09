global class AssignOpportunityRepScheduler implements Schedulable {
    global void execute(SchedulableContext ctx) {
        AssignOpportunityRep processor = new AssignOpportunityRep(); // Assign owners to all the opportunities with non-ISR owner
        Id batchId = Database.executeBatch(processor, 10);
        System.debug('Assign Opportunities BatchId: ' + batchId);
    }
}