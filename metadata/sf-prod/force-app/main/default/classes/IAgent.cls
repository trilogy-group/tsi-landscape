public interface IAgent {
    String runPrompt(String prompt);
    Object runPrompt(String prompt, Type targetType);
}