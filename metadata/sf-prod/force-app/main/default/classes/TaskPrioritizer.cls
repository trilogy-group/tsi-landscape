public with sharing class TaskPrioritizer { // Class is used in creation of prioritized tasks
    // Wrapper to sort opportunities based on their weight
    public class OpportunityPriorityWrapper implements Comparable {
        public Opportunity opp;
        public Decimal weight; // Multiplication of all the coefficients
        public String priority; // string representation of the priority

        public OpportunityPriorityWrapper(Opportunity o) {
            opp = o;
        }

        public Integer compareTo(Object compareTo) {
            OpportunityPriorityWrapper compareToTask = (OpportunityPriorityWrapper)compareTo;
            Integer returnValue = 0;
            if (this.weight < compareToTask.weight) {
                returnValue = 1;
            } else if (this.weight > compareToTask.weight) {
                returnValue = -1;
            }
            return returnValue;
        }
    }
    static final Integer HIGHEST_PRIORITY_WEIGHT = 9999; 
    List<Opportunity> opps; // Opportunities to be processed
    Set<Id> oppIds; // Ids of the opportunities
    Map<Id, Date> stageChages; // Stage changed date for each opportunity (or created date if there are no changes)
    Map<Id, List<OpportunityPriorityWrapper>> weightedOpps = new Map<Id, List<OpportunityPriorityWrapper>>();
    Map<Id, String> opportunityPriorityMap = new Map<Id, String>(); // Priority for the opportunity mapping
    Integer maximumTaskNumber = 180;
    Integer maxPriority = 9; //[30..0]

    public TaskPrioritizer(Integer maxTasks) {
        System.debug('Task prioritizer is being created with Max Tasks number: ' + maxTasks);
        maximumTaskNumber = maxTasks;
        opps = [
        SELECT Id, Name, Account.LastActivityDate, CreatedDate, Next_Follow_Up_Date__c, Amount, StageName, CloseDate, OwnerId
        FROM Opportunity
        WHERE IsClosed=false
        AND ContactId != null
        AND StageName IN ('Renewal Engagement','Outreach', 'Engaged', 'Proposal', 'Final Quote', 'Quote Follow-Up')
        ];

        oppIds = new Map<Id, Sobject> (opps).keySet();
        getStageEnterDates();
        prioritizeTasks(); // Calculate the weights
        sortAndAssignPriorities();
    }

    public void sortAndAssignPriorities() {
        for (Id ownerId : weightedOpps.keySet()) { // Sort the opportunities for each owner
            weightedOpps.get(ownerId).sort();
        }

        for (Id ownerId : weightedOpps.keySet()) { // Print the sorted opportunities
            Integer counter = 0;
            Integer max = Math.min(maximumTaskNumber, weightedOpps.get(ownerId).size());
            for (OpportunityPriorityWrapper w : weightedOpps.get(ownerId)) {
                Integer integerPriority = (Integer)(Math.ceil((maxPriority+1)*(max*1.0-counter)/max)-1);//(maxPriority * (max-counter))/max);
                if(w.weight == HIGHEST_PRIORITY_WEIGHT) { integerPriority = 10; }
                if (integerPriority < 0 ) { integerPriority = 0; }
                String priority = String.valueOf(integerPriority);//.leftPad(2, '0'); // Add leading zeroes if needed                
                w.priority = priority;
                opportunityPriorityMap.put(w.opp.Id, priority); // Store the priority
                counter++;
            }            
        }        
    }

    public String getPriority(Id priorityId) {
        String priority = opportunityPriorityMap.get(priorityId);
        if (priority == null) {
            System.debug('Prioritizer skipped the opportunity, Id: ' + priorityId);
            priority = '0';
        }
        return priority;
    }

    public void getStageEnterDates() {
        List<OpportunityFieldHistory> stageHistory = [
            SELECT OpportunityId, CreatedDate, Field, NewValue, OldValue
            FROM OpportunityFieldHistory
            WHERE Field = 'StageName'
            AND OpportunityId IN :oppIds
            ORDER BY CreatedDate DESC];
        stageChages = new Map<Id, Date>();
        for (OpportunityFieldHistory record : stageHistory) { // The records are ordered by CreatedDate, so the first encountered is the latest
            if(!stageChages.containsKey(record.OpportunityId)) {
                stageChages.put(record.OpportunityId, record.CreatedDate.date());
            }
        }
        for (Opportunity o : opps) { // If there are no stage changes, put opportunity creation date
            if(!stageChages.containsKey(o.Id)) {
                stageChages.put(o.Id, o.CreatedDate.date());
            }
        }
    }

    public OpportunityPriorityWrapper getWrapper(Opportunity o) { // Create a wrapper and store it for future sorting
        OpportunityPriorityWrapper wrapper = new OpportunityPriorityWrapper(o);
        if(!weightedOpps.containsKey(o.OwnerId)) {
            weightedOpps.put(o.OwnerId, new List<OpportunityPriorityWrapper>());
        }
        weightedOpps.get(o.OwnerId).add(wrapper); // Store all the wrappers grouped by owners
        return wrapper;
    }

    public void prioritizeTasks() {                
        // Header
        //System.debug('Id,High,Total,FollowUp,Next Follow-Up Date,High Next Follow-Up Date,Amount,Stage,Days In Stage,Close Date Proximity,High Close Date');
        for (Opportunity o : opps) {
            OpportunityPriorityWrapper wrapper = getWrapper(o);
            Date today = System.today();
            Date lastFollowUpDate = o.Account.LastActivityDate != null ? o.Account.LastActivityDate : o.CreatedDate.date(); // If there is no activity, count the period from the opportunity creation date
            Integer daysFromFollowUp = - today.daysBetween(lastFollowUpDate);
            if(daysFromFollowUp < 0) { daysFromFollowUp = 0; } // Somebody marked a future event as completed (timezone difference maybe)
            Boolean setHighPriority = false; // With this set to true we assign the highest priority for the task
            Boolean setHighPrioritynextFollowUp = false;
            Boolean setHighPriorityCloseDate = false;

            // Last Follow-up coefficient
            Decimal followUpCoef = daysFromFollowUp/5.0;

            // Next Follow-up Date
            Date nextFollowUp = o.Next_Follow_Up_Date__c;
            Decimal nextFollowUpDateCoef = 1;
            if (nextFollowUp != null) {
                if (nextFollowUp > today) {
                    nextFollowUpDateCoef = 0; // We need to just wait for the follow-up scheduled
                } else {
                    if(o.Account.LastActivityDate < nextFollowUp) {
                        setHighPriority = true;
                        setHighPrioritynextFollowUp = true;
                    }
                }
            } else {
                nextFollowUpDateCoef = 1.5; // Without a next follow-up date we have higher risk level for the opportunity
            }

            // Opportunity size
            Decimal amountCoef = 1;
            if(o.Amount < 10000) {
                amountCoef = .5;
            } else if (o.Amount > 50000) {
                amountCoef = 2;
            }

            // Stage
            Decimal stageCoef = 1;
            if (o.StageName == 'Quote Follow-Up'
            || o.StageName == 'Proposal' ) {
                stageCoef = 3;
            }

            // Time in Stage
            Integer daysInStage = stageChages.get(o.Id).daysBetween(today);
            Integer daysAccepted = 5; // 5 days is ok for the most of the stages
            Decimal daysInStageCoef = 1;
            if(o.StageName == 'Engaged') { daysAccepted = 15; } // In Engaged it is ok to be longer
            if(daysInStage < daysAccepted) { daysInStageCoef = .5; } // We do not wait long enough to give this priority

            // Close Date
            Decimal closeDateCoef = 1;
            if(today.daysBetween(o.CloseDate) < 30) { closeDateCoef = 1.5; }
            if(today.daysBetween(o.CloseDate) < 14) { closeDateCoef = 2; setHighPriority = true; setHighPriorityCloseDate = true; }

            Decimal totalCoef = followUpCoef * nextFollowUpDateCoef * amountCoef * stageCoef * daysInStageCoef * closeDateCoef;
            if(setHighPriority) {
                totalCoef = 9999;
            }
            wrapper.weight = totalCoef; // Store the result value            
            // // Rows
            // //System.debug(String.format('{10},{7} totalCoef = {0}, followUpCoef = {1} * nextFollowUpDateCoef = {2} {8} * amountCoef = {3} * stageCoef = {4} * daysInStageCoeff = {5} * closeDateCoeff = {6} {9}',
            // System.debug(String.format('{10},{7},{0},{1},{2},{8},{3},{4},{5},{6},{9}',
            // new String[] {
            //     String.valueOf(totalCoef),
            //     String.valueOf(followUpCoef),
            //     String.valueOf(nextFollowUpDateCoef),
            //     String.valueOf(amountCoef),
            //     String.valueOf(stageCoef),
            //     String.valueOf(daysInStageCoef),
            //     String.valueOf(closeDateCoef),
            //     setHighPriority ? '!' : ' ',
            //     setHighPrioritynextFollowUp ? '!' : ' ',
            //     setHighPriorityCloseDate ? '!' : ' ',
            //     o.Id
            // }));
        }
    }
}