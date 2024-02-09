/**
 * @description: LAMBDA-64039 a utility class created for Email batch containing generic methods
*                It can be used by other classes as well
 */
public without sharing class GeneralUtility {
    private static Map<String, Id> emailToIdMap = new Map<String, Id>();
    //Utility to log apex exception for Asynchronous apex
    public static void logApexException(Exception ex, String recordId) {
        insert new ApexLogger__c (Exception_Message__c = ex.getMessage(), 
        Exception_Type_Name__c=ex.getTypeName(),
        Stack_Trace_String__c  =ex.getStackTraceString(),
        RecordId__c = recordId,
        ownerId = UserInfo.getUserId() );
    }
    public static Id getOrgWideEmailIdbyName(String domain) {
        String emailId = 'renewals@'+domain;
        System.debug('==domain=='+domain);
        if(emailToIdMap==null || emailToIdMap.isEmpty()) {
            //initialize map
             List<OrgWideEmailAddress> lstOwa = [SELECT Id,address FROM OrgWideEmailAddress];
          for(OrgWideEmailAddress owa: lstOwa) {
              emailToIdMap.put(owa.address, owa.Id);
          }
        }
        if (emailToIdMap.containsKey(emailId)) {
            return emailToIdMap.get(emailId);
      }
        return null;
    }
    public static void postToRecord(String recordId, List<String> userIds, String customMessage) {
        try {
            // Initialize the FeedElementInput and MessageBodyInput
            ConnectApi.FeedItemInput feedItemInput = new ConnectApi.FeedItemInput();
            ConnectApi.MessageBodyInput messageBodyInput = new ConnectApi.MessageBodyInput();
            messageBodyInput.messageSegments = new List<ConnectApi.MessageSegmentInput>();

            // Append the custom message to the body.
            ConnectApi.TextSegmentInput textSegmentInput = new ConnectApi.TextSegmentInput();
            textSegmentInput.text = customMessage;
            messageBodyInput.messageSegments.add(textSegmentInput);

            // Iterate over the user Ids to build mentions.
            for(String userId : userIds) {
                ConnectApi.MentionSegmentInput mentionSegmentInput = new ConnectApi.MentionSegmentInput();
                mentionSegmentInput.id = userId;

                ConnectApi.TextSegmentInput spaceSegment = new ConnectApi.TextSegmentInput();
                spaceSegment.text = ' ';
                
                // Append the mention and a space to the body.
                messageBodyInput.messageSegments.add(mentionSegmentInput);
                messageBodyInput.messageSegments.add(spaceSegment);
            }

            // Set the body and subjectId
            feedItemInput.body = messageBodyInput;
            feedItemInput.subjectId = recordId;
            feedItemInput.feedElementType = ConnectApi.FeedElementType.FeedItem;
            // Post it
            System.debug('==Posting feed element=='+customMessage);
            ConnectApi.ChatterFeeds.postFeedElement(Network.getNetworkId(), feedItemInput);
            
        } catch (Exception e) {
            System.debug('Could not post to Chatter: ' + e.getMessage());
        }
    }
    public static void postChatterInBulk(List<OpportunityChatterWrapper> oppChatterWrappers) {
    List<ConnectApi.BatchInput> batchInputs = new List<ConnectApi.BatchInput>();

    for (OpportunityChatterWrapper wrapper : oppChatterWrappers) {
        ConnectApi.FeedItemInput feedItemInput = new ConnectApi.FeedItemInput();
        ConnectApi.MessageBodyInput messageBodyInput = new ConnectApi.MessageBodyInput();
        messageBodyInput.messageSegments = new List<ConnectApi.MessageSegmentInput>();

        // Add custom message
        ConnectApi.TextSegmentInput textSegmentInput = new ConnectApi.TextSegmentInput();
        textSegmentInput.text = wrapper.customMessage;
        messageBodyInput.messageSegments.add(textSegmentInput);

        // Add user mentions
        for (String userId : wrapper.userIds) {
            ConnectApi.MentionSegmentInput mentionSegmentInput = new ConnectApi.MentionSegmentInput();
            mentionSegmentInput.id = userId;
            messageBodyInput.messageSegments.add(mentionSegmentInput);
        }

        feedItemInput.body = messageBodyInput;
        feedItemInput.subjectId = wrapper.opportunityId;
        feedItemInput.feedElementType = ConnectApi.FeedElementType.FeedItem;

        ConnectApi.BatchInput batchInput = new ConnectApi.BatchInput(feedItemInput);
        batchInputs.add(batchInput);
    }

    // Perform the batch post
    try {
            String communityId = Network.getNetworkId(); // Or specific community ID
            ConnectApi.BatchResult[] results = ConnectApi.ChatterFeeds.postFeedElementBatch(communityId, batchInputs);

        } catch (Exception e) {
            System.debug('Error posting to Chatter in bulk: ' + e.getMessage());
        }
  }
  public static Id getRecordTypeIdByName(String objectName, String recordTypeDeveloperName) {
    try {
        // Query for the RecordType Id using the object name and developer name
        RecordType rt = [
            SELECT Id 
            FROM RecordType 
            WHERE SObjectType = :objectName 
            AND DeveloperName = :recordTypeDeveloperName 
            LIMIT 1
        ];
        return rt.Id;
    } catch (Exception e) {
        System.debug('Error retrieving RecordType Id: ' + e.getMessage());
        return null;
    }
}

}