global class ARRCalculatorScheduler implements Schedulable {
    global void execute(SchedulableContext ctx) {
        ARRCalculatorBatch processor = new ARRCalculatorBatch();
        Database.executeBatch(processor, 50);
    }
}