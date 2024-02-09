@isTest
global class GetSubscriptionItemsFromNetsuiteMock implements HttpCalloutMock {
    private String mockResponseBody;

    public GetSubscriptionItemsFromNetsuiteMock(String responseBody) {
        this.mockResponseBody = responseBody;
    }

    global HTTPResponse respond(HTTPRequest req) {
        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');
        res.setBody(this.mockResponseBody);
        res.setStatusCode(200);
        return res;
    }
}