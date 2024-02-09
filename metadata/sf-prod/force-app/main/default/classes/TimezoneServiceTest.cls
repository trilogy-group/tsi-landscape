@isTest
private class TimezoneServiceTest {
        private class GoogleAPIMock implements HTTPCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            String body;
            if(req.getEndpoint().contains('geocode')){
                body = '{"results":[{"geometry":{"location":{"lat":47.6084921,"lng":-122.336407}}}],"status":"OK"}';
            } else {
                body = '{"dstOffset":3600,"rawOffset":-28800,"status":"OK","timeZoneId":"America/Los_Angeles","timeZoneName":"PacificDaylightTime"}';
            }
            HttpResponse res = new HTTPResponse();
            res.setHeader('Content-Type', 'application/JSON');
            res.setBody(body);
            res.setStatusCode(200);
            return res;
        }
    }
    static final String NON_EMPTY_TIMEZONE_MESSAGE = 'The timezone should not be empty.';
    @isTest static void getTzTest() {
        TimezoneService.httpMock = new GoogleAPIMock();
        TimezoneService.TimeZone tz = TimezoneService.getTimeZone('Seattle', 'US', '98101');
        System.assertNotEquals(null, tz.timeZoneId, NON_EMPTY_TIMEZONE_MESSAGE);
    }

    @isTest static void emptyCityTest() {
        TimezoneService.httpMock = new GoogleAPIMock();
        TimezoneService.TimeZone tz = TimezoneService.getTimeZone(null, 'US', null);
        System.assertNotEquals(null, tz.timeZoneId, NON_EMPTY_TIMEZONE_MESSAGE);
        tz = TimezoneService.getTimeZone(null, 'USA', null);
        System.assertNotEquals(null, tz.timeZoneId, NON_EMPTY_TIMEZONE_MESSAGE);
    }
}