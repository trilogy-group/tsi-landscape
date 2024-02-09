public with sharing class QuoteTriggerHandler {
    public static void generateFinalQuote(Map<Id, SBQQ__Quote__c> oldMap, List<SBQQ__Quote__c> newRecords) {
      List<SBQQ__Quote__c> toGenerate = new List<SBQQ__Quote__c>();
      
      for (SBQQ__Quote__c q : newRecords) {
          if (q.SBQQ__Primary__c && 
              q.SBQQ__Status__c == 'Accepted' &&
              oldMap.get(q.Id).SBQQ__Status__c != 'Accepted'
          ) {
            toGenerate.add(q);
          }
      }
      
      CPQGenerateQuotePDF generateQuotePDF = new CPQGenerateQuotePDF();
      generateQuotePDF.GeneratePDFs(toGenerate);
    }
}