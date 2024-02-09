@isTest
public class IPromptBuilderTests {

    @IsTest
    static void Should_Have_QCPrompt_Metadata_Available() {

        // Execute the method with the test data
        IPromptBuilder.PromptRegistryImpl registry = new IPromptBuilder.PromptRegistryImpl();
        String result = registry.getQCTaskPromptPrefix();

        Assert.isNotNull(result, 'Prompt for QC Task is not defined in the metadata');
    }

    @IsTest
    static void Should_Have_QCPlatinumOfferPrompt_Metadata_Available() {
        // Execute the method with the test data
        IPromptBuilder.PromptRegistryImpl registry = new IPromptBuilder.PromptRegistryImpl();
        String result = registry.getQCTaskPlatinumOfferPromptPrefix();

        // Verify the result
        Assert.isNotNull(result, 'Prompt for QC Platinum Offers is not defined in the metadata');
    }
}