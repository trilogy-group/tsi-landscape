// Opportunities count for a rep
public with sharing class RepCount implements Comparable {
    public Id repId;         // User Id
    public Integer count;   // Number of opportunities assigned

     // Compare object based on opportunities count
     public Integer compareTo(Object compareTo) {
        RepCount compareToOppy = (RepCount)compareTo;
        if (this.count > compareToOppy.count) {
            return 1;
        } else if (this.count < compareToOppy.count) {
            return -1;
        }        
        return 0;
    }
}