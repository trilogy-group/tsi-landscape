public with sharing class AgentOAI implements IAgent {

    private class AIRequest {
        public String model;
        public Decimal temperature;
        public List<AIMessage> messages;
    }
    @TestVisible
    private class AIMessage {
        public AIMessage(String role, String content) {
            this.role = role;
            this.content = content;
        }
        public String role;
        public String content;
    }    
    @TestVisible
    private class AIChoice {
        public Integer index;
        public AIMessage message;
        public String finish_reason;
    }
    @TestVisible
    private class ChatCompletion {
        public String id;
        public Long created;
        public String model;
        public List<AIChoice> choices;
    }

    public class OAIHttpException extends Exception {}
    public class OAIInvalidHTTPResponseException extends Exception {}
    public class OAIInvalidParameterException extends Exception {}
    
    @InvocableMethod(label='Run a prompt' description='Runs a prompt with OpenAI')
    public static List<String> runPrompt_OpenAI(List<String> prompts) {
        IAgent agent = new AgentOAI();
        List<String> results = new List<String>();
        for (String prompt : prompts) {
            results.add((String)agent.runPrompt(prompt));
        }
        return results;
    }

    public Object runPrompt(String prompt, Type targetType) {
        if(targetType == null) {
            throw new OAIInvalidParameterException('targetType cannot be null');
        }

        String jsonString = this.runPrompt(prompt);
        if(jsonString == null) {
            return null;
        }

        // Parse the reply's content
        if (jsonString.startsWith('```json') && jsonString.endsWith('```')) {
            // Extract JSON string from the response body
            jsonString = jsonString.substringBetween('```json', '```');
        }

        // Deserialize jsonString into a record of the given type
        return JSON.deserialize(jsonString, targetType);
    }

    public String runPrompt(String prompt) {
        HttpRequest request = new HttpRequest();
        request.setEndpoint('callout:NamedCred_OpenAI/v1/chat/completions');
        request.setMethod('POST');
        request.setHeader('Content-Type', 'application/json');

        AIRequest requestPayload = new AIRequest();
        requestPayload.model = 'gpt-4-1106-preview';
        requestPayload.temperature = 0.0;
        requestPayload.messages = new List<AIMessage>();
        requestPayload.messages.add(new AIMessage('system', ''));
        requestPayload.messages.add(new AIMessage('user', prompt));

        String jsonPayload = JSON.serialize(requestPayload);

        request.setBody(jsonPayload);

        // Make the request
        Http http = new Http();
        request.setTimeout(120000); // Set timeout to 120 seconds
        HttpResponse response = http.send(request);

        // Process the response
        if (response.getStatusCode() != 200) {
            String msg = 'HTTP error: ' + response.getStatusCode() + '. Body: ' + response.getBody();
            throw new OAIHttpException(msg);
        }

        // Parse the LLM reply
        ChatCompletion chatCompletion;
        try {
            String body = response.getBody();
            chatCompletion = (ChatCompletion)JSON.deserialize(body, ChatCompletion.class);
        } catch (Exception e) {
            String msg = 'Error parsing OpenAI response as JSON: ' + e.getMessage();
            msg += '\n\nResponse body: \n' + response.getBody();
            throw new OAIInvalidHTTPResponseException(msg);
        }
        String aiReply = null;
        for (AIChoice choice : chatCompletion.choices) {
            if (choice.message.role == 'assistant') {
                aiReply = choice.message.content;
                break;
            }
        }

        if (aiReply == null) {
            String msg = 'Error parsing OpenAI response, no assistant response found.';
            msg += '\n\nResponse body: \n' + response.getBody();
            throw new OAIInvalidHTTPResponseException(msg);
        }

        return aiReply;
    }

}