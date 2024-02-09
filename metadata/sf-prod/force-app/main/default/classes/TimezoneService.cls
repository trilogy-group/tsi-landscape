public without sharing class  TimezoneService {
    static final String GOOGLE_API_KEY = 'AIzaSyB7Dx36jrImg5lFNuwTzTkjDxNF3cPkVNU';
    
    public class TimeZone {
        public Integer dstOffset;  // Daytime offset in seconds
        public Decimal rawOffset;  // UTC offset in hours
        public String timeZoneId;  // Standard Time Zone name
        public String timeZoneName; // Long Time Zone name
    }

    public static String prepareGoogleAddressRequest(String city, String country, String postalCode){
        String requestUrl = 'https://maps.googleapis.com/maps/api/geocode/json?address=';
        
        if (String.isBlank(city)) {
            // get capital city from Country metadata if city is not present. 
            city = getCapitalCity(country);
        }
        
        if (String.isNotBlank(city)) {
            city = city.replaceAll('\\s+','+');
            requestUrl += city;
        }

        if (String.isNotBlank(postalCode)) {
            requestUrl = requestUrl + ',' + postalCode;
        }

        if (String.isNotBlank(country)) {
            if(country.length() == 2) {
                // We have a region code (EasyApply applicaiton)
                requestUrl = requestUrl + '&region=' + country;
            } else {
                // Treat as a full country name
                country = country.replaceAll('\\s+','+');
                requestUrl = requestUrl + ',' + country;
            }
        }

        requestUrl += '&key=' + GOOGLE_API_KEY;
        return requestUrl;
    }
    
    public static HTTPCalloutMock httpMock;

    public static Map<String, Object> getResponseBody(String requestUrl) {
        HttpRequest request = new HttpRequest();
        request.setMethod('GET');
        request.setEndpoint(requestUrl);
        Http h = new Http();
        HTTPResponse response = (httpMock==null? h.send(request) : httpMock.respond(request)); // replace the real request with the mock (tests only)
        return (Map<String, Object>)JSON.deserializeUntyped(response.getBody());
    }

    public static TimeZone getTimeZone(String city, String country, String postalCode) {
        TimeZone returnValue = new TimeZone();
        If(String.isBlank(city) && String.isBlank(country)) {
            return returnValue;   // nothing to do
        }
        
        String requestUrl = prepareGoogleAddressRequest(city, country, postalCode);
        Map<String, Object> responseBody = getResponseBody(requestUrl);
        String status = (String)responseBody.get('status');
        if (status != 'OK') {
            System.debug('LOCATION REQUEST FAILED' + status);
            return returnValue;  // Nothing to do
        }

        List<Object> results = (List<Object>)responseBody.get('results');
        Map<String, Object> result = (Map<String, Object>)results[0];
        Map<String, Object> geometry = (Map<String, Object>)result.get('geometry');
        Map<String, Object> location = (Map<String, Object>)geometry.get('location');
        Double lat = (Double)location.get('lat');
        Double lng = (Double)location.get('lng');

        requestUrl = 'https://maps.googleapis.com/maps/api/timezone/json?location=' + lat + ',' + lng + '&timestamp=11111111&key=' + GOOGLE_API_KEY;
        responseBody = getResponseBody(requestUrl);
        status = (String)responseBody.get('status');
        if (status == 'OK') {
            returnValue.dstOffset = (Integer)responseBody.get('dstOffset');
            returnValue.rawOffset = (Decimal)responseBody.get('rawOffset');
            returnValue.rawOffset = returnValue.rawOffset.divide(3600, 1);
            returnValue.timeZoneId = (String)responseBody.get('timeZoneId');
            returnValue.timeZoneName = (String)responseBody.get('timeZoneName');
        } else {
            System.debug('TIME ZONE REQUEST FAILED ' + status);
        }

        return returnValue;
    }
    
    private static string getCapitalCity(String country) {
        
       List<Country__mdt> country_mdt;
        if (String.isNotBlank(country)) {
            if(country.length() == 2) {
                country_mdt = [SELECT Capital__c FROM Country__mdt WHERE Code__c = :country];
            } else {
                country_mdt = [SELECT Capital__c FROM Country__mdt WHERE Label = :country];
                if (country_mdt.size() == 0){
                    country_mdt = [SELECT Capital__c FROM Country__mdt WHERE DeveloperName = :country];
                }
            }
        }
        
        if (country_mdt != null && country_mdt.size() > 0){
            return country_mdt.get(0).Capital__c;
        }
        
        return null;
    }
}