// Caching timezone caloouts class (to avoid hitting the 100 callouts limit)
public virtual class CachedTimezoneService {
    static Map<String, TimezoneService.TimeZone> cache = new Map<String, TimezoneService.TimeZone>(); // Cached timezones
    public TimezoneService.TimeZone defaultTimeZone = getTimeZone('', 'us', ''); // Whenever we don't have enough information we will use this timezone

    // Get timezone for the address
    public virtual TimezoneService.TimeZone getTimezone(String city, String country, String postalCode){
        if(city == null){
            city = '';
        }
        if(country == null){
            country = '';
        }
        if(postalCode == null){
            postalCode = '';
        }
        if(country!='' && city!='') postalCode = ''; // We need to avoid excessive callouts
        String key = String.Format('{0}:{1}:{2}', new String[]{city, country, postalCode});
        try {
            if(cache.containsKey(key)){ 
                return cache.get(key);
            }
            
            TimezoneService.Timezone tz = TimezoneService.getTimeZone(EncodingUtil.urlEncode(city, 'UTF-8'), EncodingUtil.urlEncode(country, 'UTF-8'), EncodingUtil.urlEncode(postalCode, 'UTF-8'));
            if(tz == null || tz.timeZoneId == null){
                tz = defaultTimeZone;
            }
            cache.put(key, tz);
            return tz;
        } catch (Exception e) {
            System.debug('Timezone error: ' + e.getMessage());
            return defaultTimeZone;
        }
    }
}