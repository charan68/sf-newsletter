public without sharing class NewsletterFeedbackController {

    @AuraEnabled
    public static String saveFeedback(String userId, String topicId, String rating) {
        if (String.isBlank(userId) || String.isBlank(topicId) || String.isBlank(rating)) {
            return 'error';
        }
        List<TopicDeliveryLog__c> logs = [
            SELECT Id, FeedbackRating__c
            FROM TopicDeliveryLog__c
            WHERE User__c = :userId AND Topic__c = :topicId
            ORDER BY SentDate__c DESC
            LIMIT 1
        ];
        if (logs.isEmpty()) return 'notfound';
        if (String.isNotBlank(logs[0].FeedbackRating__c)) return 'already';
        logs[0].FeedbackRating__c = rating;
        update logs[0];
        return 'saved';
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Integer> getFeedbackStats() {
        Integer helpful = [SELECT COUNT() FROM TopicDeliveryLog__c WHERE FeedbackRating__c = 'Helpful'];
        Integer notHelpful = [SELECT COUNT() FROM TopicDeliveryLog__c WHERE FeedbackRating__c = 'Not Helpful'];
        return new Map<String, Integer>{ 'helpful' => helpful, 'notHelpful' => notHelpful };
    }
}
