@IsTest
global with sharing class QuoteDocumentMockGenerator implements HTTPCalloutMock {
    public static final String TEST_QUOTE_GENERATED_DOCUMENT = 'Test Quote Generated Document';


    public static void generateDocument(Id quoteId, Id opportunityId) {
        insert new SBQQ__QuoteDocument__c(
                Name = TEST_QUOTE_GENERATED_DOCUMENT,
                SBQQ__Quote__c = quoteId,
                SBQQ__Opportunity__c = opportunityId
        );
    }

    global HTTPResponse respond(HTTPRequest req) {

        HttpResponse res = new HTTPResponse();
        res.setHeader('Content-Type', 'application/JSON');
        res.setBody('{"test": "data"}');
        res.setStatusCode(200);
        return res;
    }
}