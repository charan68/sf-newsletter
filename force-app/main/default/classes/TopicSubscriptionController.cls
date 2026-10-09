public without sharing class TopicSubscriptionController {

    @AuraEnabled(cacheable=true)
    public static UserNewsletterPreference__c getUserPreference() {
        Id userId = UserInfo.getUserId();
        List<UserNewsletterPreference__c> prefs = [
            SELECT Id, DeliveryFrequency__c, WeeklyDeliveryDay__c
            FROM UserNewsletterPreference__c
            WHERE User__c = :userId
            LIMIT 1
        ];
        if (!prefs.isEmpty()) return prefs[0];
        return new UserNewsletterPreference__c(DeliveryFrequency__c = 'Daily', WeeklyDeliveryDay__c = 'Monday');
    }

    @AuraEnabled
    public static void saveUserPreference(String frequency, String weeklyDay) {
        Id userId = UserInfo.getUserId();
        List<UserNewsletterPreference__c> existing = [
            SELECT Id FROM UserNewsletterPreference__c WHERE User__c = :userId LIMIT 1
        ];
        UserNewsletterPreference__c pref = existing.isEmpty()
            ? new UserNewsletterPreference__c(User__c = userId)
            : existing[0];
        pref.DeliveryFrequency__c = frequency;
        pref.WeeklyDeliveryDay__c = weeklyDay;
        upsert pref;
    }

    @AuraEnabled(cacheable=true)
    public static List<Topic__c> getTopics() {
        return [
            SELECT Id, Name, Description__c, Category__c, Tab__c
            FROM Topic__c
            WHERE IsActive__c = true
            ORDER BY Category__c, Name
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<Id> getUserSubscriptions() {
        Id userId = UserInfo.getUserId();
        List<UserTopicSubscription__c> subs = [
            SELECT Topic__c
            FROM UserTopicSubscription__c
            WHERE User__c = :userId AND IsActive__c = true
        ];
        List<Id> topicIds = new List<Id>();
        for (UserTopicSubscription__c s : subs) {
            topicIds.add(s.Topic__c);
        }
        return topicIds;
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Integer> getTopicSubscriberCounts() {
        Map<String, Integer> counts = new Map<String, Integer>();
        for (AggregateResult ar : [
            SELECT Topic__c topicId, COUNT(Id) cnt
            FROM UserTopicSubscription__c
            WHERE IsActive__c = true
            GROUP BY Topic__c
        ]) {
            counts.put(String.valueOf(ar.get('topicId')), (Integer)ar.get('cnt'));
        }
        return counts;
    }

    @AuraEnabled(cacheable=true)
    public static List<TopicDeliveryLog__c> getDeliveryHistory() {
        Id userId = UserInfo.getUserId();
        return [
            SELECT Id, Topic__r.Name, Topic__r.Category__c, SentDate__c, GeneratedContent__c
            FROM TopicDeliveryLog__c
            WHERE User__c = :userId
            ORDER BY SentDate__c DESC
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<Topic__c> getSubscribedTopics() {
        Id userId = UserInfo.getUserId();
        List<UserTopicSubscription__c> subs = [
            SELECT Topic__c FROM UserTopicSubscription__c
            WHERE User__c = :userId AND IsActive__c = true
        ];
        Set<Id> topicIds = new Set<Id>();
        for (UserTopicSubscription__c s : subs) { topicIds.add(s.Topic__c); }
        if (topicIds.isEmpty()) return new List<Topic__c>();
        return [SELECT Id, Name, Description__c, Category__c FROM Topic__c WHERE Id IN :topicIds ORDER BY Category__c, Name];
    }

    @AuraEnabled
    public static void removeSubscription(Id topicId) {
        Id userId = UserInfo.getUserId();
        List<UserTopicSubscription__c> subs = [
            SELECT Id FROM UserTopicSubscription__c
            WHERE User__c = :userId AND Topic__c = :topicId AND IsActive__c = true
        ];
        for (UserTopicSubscription__c s : subs) { s.IsActive__c = false; }
        if (!subs.isEmpty()) update subs;
    }

    @AuraEnabled
    public static void saveSubscriptions(List<Id> topicIds) {
        Id userId = UserInfo.getUserId();

        List<UserTopicSubscription__c> existing = [
            SELECT Id FROM UserTopicSubscription__c WHERE User__c = :userId
        ];
        Boolean isFirstSubscription = existing.isEmpty();

        for (UserTopicSubscription__c s : existing) {
            s.IsActive__c = false;
        }
        update existing;

        List<UserTopicSubscription__c> newSubs = new List<UserTopicSubscription__c>();
        for (Id topicId : topicIds) {
            newSubs.add(new UserTopicSubscription__c(
                User__c = userId,
                Topic__c = topicId,
                IsActive__c = true
            ));
        }
        insert newSubs;

        if (isFirstSubscription && !topicIds.isEmpty()) {
            List<String> topicIdStrings = new List<String>();
            for (Id tid : topicIds) topicIdStrings.add(String.valueOf(tid));
            DailyNewsletterService.sendWelcomeEmailAsync(userId, topicIdStrings);
        }
    }
}
