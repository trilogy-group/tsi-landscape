public interface ITaskDispatchReportService {
    void configure(Integer sendHour, Integer sendDurationInMinutes);
    void addTaskDispatch(Id id, String name);
    Boolean addBacklogReport(Id taskDispatcherId, Id backlogReportId, String backlogReportName);
    Boolean addValueToBacklogReport(Id taskDispatcherId, Id backlogReportId, String name,Integer value);
    Boolean addAssignee(Id taskDispatcherId, Id assigneeId);
    Boolean addAssignee(Id taskDispatcherId, Id backlogReportId, Id assigneeId);
    Boolean addValueToAssignee(Id taskDispatcherId, Id assigneeId ,String name ,Integer value);
    Boolean addValueToAssignee(Id taskDispatcherId,Id backlogReportId,Id assigneeId,String name,Integer value);
    String sendReport();
}