public with sharing class TaskDispatchReportServiceMock extends TaskDispatchReportService {
    public TaskDispatchReportServiceMock() {
        setToSendEmailWholeDay();
    }

    public override void configure(Integer sendHour, Integer sendDurationInMinutes) {
        setToSendEmailWholeDay();
    }

    private void setToSendEmailWholeDay() {
        DateTime today = System.today();
        initialTime = today.addHours(0);
        finalTime = initialTime.addMinutes(1440);
    }
}