public with sharing virtual class TaskDispatchReportService implements ITaskDispatchReportService {
    private List<TaskDispatchInfo> taskDispatches = new List<TaskDispatchInfo>();
    private Map<Id,TaskDispatchInfo> mapDispatches = new Map<Id,TaskDispatchInfo>();
    private Set<Id> assigneeIds = new Set<Id>();
    protected DateTime initialTime = null;
    protected DateTime finalTime = null;

    public virtual void configure(Integer sendHour, Integer sendDurationInMinutes) {
        DateTime today = System.now().dateGMT();
        initialTime = today.addHours(sendHour);
        finalTime = initialTime.addMinutes(sendDurationInMinutes);
    }

    public void addTaskDispatch(Id id, String name) {
        TaskDispatchInfo taskDispatchInfo = new TaskDispatchInfo(name);
        taskDispatches.add(taskDispatchInfo);
        mapDispatches.put(id,taskDispatchInfo);
    }

    public Boolean addBacklogReport(Id taskDispatcherId, Id backlogReportId, String backlogReportName) {
        TaskDispatchInfo taskDispatchInfo = mapDispatches.get(taskDispatcherId);
        if (taskDispatchInfo == null) {
            return false;
        }
        taskDispatchInfo.addBacklogReport(backlogReportId, backlogReportName);
        return true;
    }

    public Boolean addValueToBacklogReport(Id taskDispatcherId,Id backlogReportId,String name,Integer value) {
        TaskDispatchInfo taskDispatchInfo = mapDispatches.get(taskDispatcherId);
        if (taskDispatchInfo == null) {
            return false;
        }
        return taskDispatchInfo.addValueToBacklogReport(backlogReportId, name, value);
    }

    public Boolean addAssignee(Id taskDispatcherId, Id assigneeId) {
        TaskDispatchInfo taskDispatchInfo = mapDispatches.get(taskDispatcherId);
        if (taskDispatchInfo == null) {
            return false;
        }
        taskDispatchInfo.addAssignee(assigneeId);
        assigneeIds.add(assigneeId);
        return true;
    }

    public Boolean addAssignee(Id taskDispatcherId, Id backlogReportId, Id assigneeId) {
        TaskDispatchInfo taskDispatchInfo = mapDispatches.get(taskDispatcherId);
        if (taskDispatchInfo == null) {
            return false;
        }
        Boolean added = taskDispatchInfo.addAssignee(backlogReportId, assigneeId);
        if (added) {
            assigneeIds.add(assigneeId);
        } 
        return added;
    }

    public Boolean addValueToAssignee(Id taskDispatcherId, Id assigneeId, String name, Integer value) {
        TaskDispatchInfo taskDispatchInfo = mapDispatches.get(taskDispatcherId);
        if (taskDispatchInfo == null) {
            return false;
        }
        return taskDispatchInfo.addValueToAssignee(assigneeId, name, value);
    }

    public Boolean addValueToAssignee(Id taskDispatcherId,Id backlogReportId,Id assigneeId,String name,Integer value) {
        TaskDispatchInfo taskDispatchInfo = mapDispatches.get(taskDispatcherId);
        if (taskDispatchInfo == null) {
            return false;
        }
        return taskDispatchInfo.addValueToAssignee(backlogReportId, assigneeId, name, value);
    }

    public String sendReport() {
        DateTime now = System.now();
        if (initialTime != null && finalTime != null && now >= initialTime && now <= finalTime) {
            IEmailService emailService = Injector.getInstance().getEmailService();
            String report = generateReport();
            emailService.sendEmailToApexExceptionEmails('Task Dispatcher Report', report);
            return report;
        }
        return null;
    }

    private void associateAssigneesNames() {
        Map<Id, User> usersMap = (new Map<Id, User>([SELECT Id, Name FROM User WHERE Id IN :assigneeIds]));
        for (TaskDispatchInfo tdInfo : taskDispatches) {
            tdInfo.associateAssigneesNames(usersMap);
        }
    }

    private String generateReport() {
        associateAssigneesNames();
        String message = '';
        for(TaskDispatchInfo dispatch : taskDispatches) {
            message += dispatch.generateMessage() + '\n';
        }
        return message;
    }

    private class TaskDispatchInfo extends AssigneeList{
        private String name;
        private List<BacklogReportInfo> backlogReports  = new List<BacklogReportInfo>();
        private Map<Id,BacklogReportInfo> mapBacklogReports = new Map<Id,BacklogReportInfo>();

        public TaskDispatchInfo(String name) {
            this.name = name;
        }

        public void addBacklogReport(Id id, String name) {
            BacklogReportInfo backlogReportInfo = new BacklogReportInfo(id, name);
            backlogReports.add(backlogReportInfo);
            mapBacklogReports.put(id,backlogReportInfo);
        }

        public Boolean addValueToBacklogReport(Id backlogReportId, String name, Integer value) {
            BacklogReportInfo backlogReportInfo = mapBacklogReports.get(backlogReportId);
            if (backlogReportInfo == null) {
                return false;
            }
            backlogReportInfo.addValue(name, value);
            return true;
        }

        public Boolean addAssignee(Id backlogReportId, Id assigneeId) {
            BacklogReportInfo backlogReportInfo = mapBacklogReports.get(backlogReportId);
            if (backlogReportInfo == null) {
                return false;
            }
            backlogReportInfo.addAssignee(assigneeId);
            return true;
        }

        public Boolean addValueToAssignee(Id backlogReportId, Id assigneeId, String name, Integer value) {
            BacklogReportInfo backlogReportInfo = mapBacklogReports.get(backlogReportId);
            if (backlogReportInfo == null) {
                return false;
            }
            return backlogReportInfo.addValueToAssignee(assigneeId, name, value);
        }

        public override void associateAssigneesNames(Map<Id, User> usersMap) {
            super.associateAssigneesNames(usersMap);
            for (BacklogReportInfo backlog : backlogReports) {
                backlog.associateAssigneesNames(usersMap);
            }
        }

        public String generateMessage() {
            String message = String.format('{0}\n',new String[]{name.toUpperCase()});
            if (backlogReports.size() == 0) {
                message += 'Task dispatcher without backlog items or without active users\n';
            } else {
                for(BacklogReportInfo backlog : backlogReports) {
                    message += backlog.generateMessage();
                }
            }

            if (assignees.size() == 0) {
                message += 'Nothing to process in this report\n';
            } else {
                message += 'TASK DISPATCHER PROCESSING RESULTS\n';
                for(AssigneeInfo assignee : assignees){
                    message += assignee.generateLineMessage();
                }
            }

            return message;
        }
    }

    private class BacklogReportInfo extends AssigneeList{
        private Id id;
        private String name;
        private List<String> values = new List<String>();

        public BacklogReportInfo(Id id, String name) {
            this.id = id;
            this.name = name;
        }

        public void addValue(String name, Integer value) {
            values.add(String.valueOf(value) + ' ' + name);
        }

        public String generateMessage() {
            String message = String.format('Backlog {0} - {1}/{2}\n',
                new String[]{name, URL.getSalesforceBaseUrl().toExternalForm(), id});
            if (values.size() > 0){
                message += String.format('Backlog report processing: {0}\n', new String[]{String.join(values,' / ')});
            }
            if (assignees.size() == 0){
                message += 'Backlog report without user records\n';
            } else {
                for(AssigneeInfo assignee : assignees){
                    message += assignee.generateLineMessage();
                }
            }
            return message;
        }
    }

    private class AssigneeInfo{
        private Id id;
        private String name;
        private List<String> values = new List<String>();

        public AssigneeInfo(Id id) {
            this.id = id;
        }

        public void setName(String name) {
            this.name = name;
        }

        public void addValue(String name, Integer value) {
            values.add(String.valueOf(value) + ' ' + name);
        }

        public String generateLineMessage() {
            String nameOrId = name != null ? name : id;
            return String.format('{0}: {1}\n', new String[]{nameOrId, String.join(values,' / ')});
        }
    }

    private virtual class AssigneeList {
        protected List<AssigneeInfo> assignees  = new List<AssigneeInfo>();
        protected Map<Id,AssigneeInfo> mapAssignees = new Map<Id,AssigneeInfo>();

        public void addAssignee(Id assigneeId) {
            AssigneeInfo assigneeInfo = new AssigneeInfo(assigneeId);
            assignees.add(assigneeInfo);
            mapAssignees.put(assigneeId, assigneeInfo);
        }

        public Boolean addValueToAssignee(Id assigneeId, String name, Integer value) {
            AssigneeInfo assigneeInfo = mapAssignees.get(assigneeId);
            if (assigneeInfo == null) {
                return false;
            }
            assigneeInfo.addValue(name, value);
            return true;
        }

        public virtual void associateAssigneesNames(Map<Id, User> usersMap) {
            for (AssigneeInfo assignee : assignees) {
                User user = usersMap.get(assignee.id);
                if (user != null) {
                    assignee.setName(user.Name);
                }
            }
        }
    }

}