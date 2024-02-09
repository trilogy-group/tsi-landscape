global class Injector {
    public static final String EmailServiceName = 'EmailService';
    public static final String TaskDispatchReportServiceName = 'TaskDispatchReportService';
    
    private static Injector instance = null;
    private Map<String,String> config = new Map<String,String>();
    
    private Injector() {
        useDefaultConfig();
    }

    public static Injector getInstance() {
        if (instance == null){
            instance = new Injector();
        }
        return instance;
    }

    public void setConfig(String service, String className) {
        config.put(service,className);
    }

    public void useDefaultConfig() {
        config.put(Injector.EmailServiceName,'EmailService');
        config.put(Injector.TaskDispatchReportServiceName,'TaskDispatchReportService');
    }

    public void useTestConfig() {
        config.put(Injector.EmailServiceName,'EmailServiceMock');
        config.put(Injector.TaskDispatchReportServiceName,'TaskDispatchReportServiceMock');
    }

    public IEmailService getEmailService(){
        Type t = Type.forName(config.get(Injector.EmailServiceName));
        return (IEmailService)t.newInstance();
    }

    public ITaskDispatchReportService getTaskDispatchReportService(){
        Type t = Type.forName(config.get(Injector.TaskDispatchReportServiceName));
        return (ITaskDispatchReportService)t.newInstance();
    }
}