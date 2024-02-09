public without sharing class ARPackageController {
    public Id oppId {get; set;}
    private Opportunity opp;

    // Lists to store related records
    public List<ActivityHistory> relatedActivities {get; private set;}
    public List<EmailMessage> relatedEmails {get; private set;}
    public SBQQ__Quote__c previousYearQuote {get; private set;}

    // Constructor
    public ARPackageController(ApexPages.StandardController stdController) {
        this.oppId = stdController.getId();
        loadOpportunityDetails();
    }

    // Method to load opportunity details
    private void loadOpportunityDetails() {
        opp = [SELECT Id,Name,Amount,Owner.Name,(SELECT Id,Subject, ActivityDate, ActivitySubtype,
        ActivityType,Status,Description, WhoId, WhatId,Who.Name,What.Name,AccountId,Account.Name,
        CallDisposition,OwnerId,Owner.Name,PrimaryWho.Name
        FROM ActivityHistories WHERE (NOT Subject like 'Email:%')  order by ActivityDate  ),
        (SELECT ID, Subject, FromAddress,FromName,ToAddress,CCAddress,CreatedDate,textBody FROM Emails)
        FROM Opportunity WHERE Id = :oppId];
        //Apexpages.currentPage().getHeaders().put('content-disposition', 'attachment; filename='+opp.name+'_docs.pdf');
        // Load related activities
        relatedActivities = opp.ActivityHistories;
        relatedEmails = opp.Emails;
    }

    // Method to get the opportunity
    public Opportunity getOpportunity() {
        return opp;
    }
}