@IsTest
public with sharing class AgentOAITests { //NOSONAR

    @IsTest
    static void Should_Include_Prompt_In_The_Request() { //NOSONAR
        // Arrange
        String testPrompt = 'Test prompt 1';
        AgentOAIHttpCalloutMockTestReply httpMock = new AgentOAIHttpCalloutMockTestReply('Some reply');
        Test.setMock(HttpCalloutMock.class, httpMock);

        // Act
        new AgentOAI().runPrompt(testPrompt);

        // Assert
        // Verify that the prompt is included in the request payload
        AgentOAI.AIMessage expectedMessage = new AgentOAI.AIMessage('user', testPrompt);
        String requestBody = httpMock.requestBody;
        System.assert(requestBody.contains(JSON.serialize(expectedMessage)), 
            'The prompt should be included in the request payload');
    }

    @IsTest
    static void Should_Handle_HTTP_Exceptions() { //NOSONAR
        // Arrange
        String testPrompt = 'Test prompt 2';
        Test.setMock(HttpCalloutMock.class, new AgentOAIHttpCalloutMockExcept());

        // Act & Assert
        try {
            new AgentOAI().runPrompt(testPrompt);
            System.assert(false, 'An OAIHttpException should have been thrown');
        } catch (AgentOAI.OAIHttpException e) {
            System.assert(true, 'OAIHttpException was thrown as expected');
        }
    }

    @IsTest
    static void Should_Handle_Invalid_HTTP_Response() { //NOSONAR
        // Arrange
        String testPrompt = 'Test prompt 3';
        Test.setMock(HttpCalloutMock.class, new AgentOAIHttpCalloutMockInvalidJSONResponse());

        // Act & Assert
        try {
            new AgentOAI().runPrompt(testPrompt);
            System.assert(false, 'An OAIInvalidHTTPResponseException should have been thrown');
        } catch (AgentOAI.OAIInvalidHTTPResponseException e) {
            System.assert(true, 'OAIInvalidHTTPResponseException was thrown as expected');
        }
    }

    @IsTest
    static void Should_Return_AI_Reply() { //NOSONAR
        // Arrange
        String testPrompt = 'Test prompt 4';
        String testReply = 'Test reply2';
        Test.setMock(HttpCalloutMock.class, new AgentOAIHttpCalloutMockTestReply(testReply));

        // Act
        String result = new AgentOAI().runPrompt(testPrompt);

        // Assert
        System.assertNotEquals(null, result, 'The AI reply should not be null');
        System.assert(result.contains(testReply), 'The AI reply should contain the mock reply');
    }


    @IsTest
    static void Should_Deserialize_To_Target_Type() { //NOSONAR
        // Arrange
        String testPrompt = 'Test prompt 5';
        Test.setMock(HttpCalloutMock.class, new AgentOAIHttpCalloutMockReturnListOfObjects());

        // Act
        Object result = new AgentOAI().runPrompt(testPrompt, List<AgentOAI.AIMessage>.class);

        // Assert
        System.assertNotEquals(null, result, 'The result should not be null');
        System.assertEquals(true, result instanceof List<AgentOAI.AIMessage>, 
            'The result should be a List<AgentOAI.AIMessage>');
    }

    @IsTest
    static void Should_Throw_Exception_When_No_Assitant_Role_In_Reply() { //NOSONAR
        // Arrange
        String testPrompt = 'Test prompt 6';
        Test.setMock(HttpCalloutMock.class, new AgentOAIHttpCalloutMockNoAssistantInReply());

        // Act
        try {
            new AgentOAI().runPrompt(testPrompt, List<AgentOAI.AIChoice>.class);
            System.assert(false, 'An OAIInvalidHTTPResponseException should have been thrown');
        } catch (AgentOAI.OAIInvalidHTTPResponseException e) {
            System.assert(true, 'OAIInvalidHTTPResponseException was thrown as expected');
            System.assert(e.getMessage().contains('no assistant response found'), 
                'The exception message should contain "no assistant response found"');
        }
    }

    private static HttpResponse getBaseResponse(Integer statusCode) {
        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');
        res.setStatusCode(statusCode);
        return res;
    }

    private class AgentOAIHttpCalloutMockExcept implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            return res;
        }
    }

    private class AgentOAIHttpCalloutMockInvalidJSONResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = AgentOAITests.getBaseResponse(200);
            res.setBody('Invalid JSON');
            return res;
        }
    }

    // Mock classes for HTTP callouts
    private class AgentOAIHttpCalloutMockTestReply implements HttpCalloutMock {
        public String requestBody;
        String m_reply;

        public AgentOAIHttpCalloutMockTestReply(String reply) {
            m_reply = reply;
        }
        public HTTPResponse respond(HTTPRequest req) {
            requestBody = req.getBody();
            HttpResponse res = AgentOAITests.getBaseResponse(200);
            res.setBody(prepChatCompletionDS('assistant', m_reply));
            return res;
        }
    }

    // Mock classes for HTTP callouts
    private class AgentOAIHttpCalloutMockReturnListOfObjects implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = AgentOAITests.getBaseResponse(200);

            List<AgentOAI.AIMessage> messages = new List<AgentOAI.AIMessage>();
            messages.add(new AgentOAI.AIMessage('user', 'User\'s reply'));
            messages.add(new AgentOAI.AIMessage('assistant', 'Assistant Test reply'));
            String content = '```json' + JSON.serialize(messages) + '```';
            res.setBody(prepChatCompletionDS('assistant', content));
            return res;
        }
    }

    private class AgentOAIHttpCalloutMockNoAssistantInReply implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = AgentOAITests.getBaseResponse(200);
            res.setBody(prepChatCompletionDS('some_role', 'Test reply 4'));
            return res;
        }
    }
    private static String prepChatCompletionDS(String role, String content) {

        AgentOAI.AIChoice choice = new AgentOAI.AIChoice();
        choice.index = 0;
        choice.message = new AgentOAI.AIMessage(role, content);
        choice.finish_reason = 'completed';
        List<AgentOAI.AIChoice> choices = new List<AgentOAI.AIChoice>{ choice };

        AgentOAI.ChatCompletion chatCompletion = new AgentOAI.ChatCompletion();
        chatCompletion.id = 'test_id';
        chatCompletion.created = 123456789;
        chatCompletion.model = 'gpt-4-1106-preview';
        chatCompletion.choices = choices;

        return JSON.serialize(chatCompletion);
    }
}