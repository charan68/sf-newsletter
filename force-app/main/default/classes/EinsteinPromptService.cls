public with sharing class EinsteinPromptService {

    private static final Boolean EINSTEIN_ENABLED = true;
    private static final String PROMPT_TEMPLATE_NAME = 'Newsletter_Topic_Generator';
    public static String generateWelcomeTopicContent(String topicName, String topicDescription) {
        // Uses same working template as daily email — content depth controlled by the prompt
        return generateTopicContent(topicName, topicDescription);
    }

    public static String generateTopicContent(String topicName, String topicDescription) {
        if (EINSTEIN_ENABLED) {
            try {
                return callEinsteinPromptBuilder(topicName, topicDescription, PROMPT_TEMPLATE_NAME);
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'Einstein generateTopicContent FAILED: ' + e.getTypeName() + ' — ' + e.getMessage());
                return formatFallbackContent(topicDescription);
            }
        }
        return formatFallbackContent(topicDescription);
    }

    private static String callEinsteinPromptBuilder(String topicName, String topicDescription, String templateName) {
        ConnectApi.EinsteinPromptTemplateGenerationsInput promptInput =
            new ConnectApi.EinsteinPromptTemplateGenerationsInput();
        promptInput.additionalConfig = new ConnectApi.EinsteinLLMAdditionalConfigInput();
        promptInput.additionalConfig.applicationName = 'PromptBuilderPreview';
        promptInput.isPreview = false;

        Map<String, ConnectApi.WrappedValue> valueMap = new Map<String, ConnectApi.WrappedValue>();

        ConnectApi.WrappedValue nameVal = new ConnectApi.WrappedValue();
        nameVal.value = topicName;
        valueMap.put('Input:topic_name', nameVal);

        ConnectApi.WrappedValue descVal = new ConnectApi.WrappedValue();
        descVal.value = String.isBlank(topicDescription) ? topicName : topicDescription;
        valueMap.put('Input:topic_description', descVal);

        promptInput.inputParams = valueMap;

        ConnectApi.EinsteinPromptTemplateGenerationsRepresentation result =
            ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate(templateName, promptInput);
        return result.generations[0].text;
    }

    private static String formatFallbackContent(String description) {
        if (String.isBlank(description)) {
            return 'No description available yet for this topic. Check back as content is enriched.';
        }
        return description;
    }
}
