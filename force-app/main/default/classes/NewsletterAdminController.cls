public with sharing class NewsletterAdminController {

    public class DashboardStats {
        @AuraEnabled public Integer activeSubscribers;
        @AuraEnabled public Integer totalTopics;
        @AuraEnabled public Integer emailsSentToday;
        @AuraEnabled public Integer totalEmailsSent;
        @AuraEnabled public Integer totalHelpful;
        @AuraEnabled public Integer totalNotHelpful;
    }

    public class TopicStat {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String category;
        @AuraEnabled public Integer subscribers;
    }

    public class RecentDelivery {
        @AuraEnabled public String id;
        @AuraEnabled public String topicName;
        @AuraEnabled public String userName;
        @AuraEnabled public String userEmail;
        @AuraEnabled public String sentDate;
        @AuraEnabled public String contentPreview;
        @AuraEnabled public String feedbackRating;
    }

    @AuraEnabled(cacheable=true)
    public static DashboardStats getStats() {
        DashboardStats stats = new DashboardStats();

        List<AggregateResult> subResult = [
            SELECT COUNT_DISTINCT(User__c) cnt
            FROM UserTopicSubscription__c
            WHERE IsActive__c = true
        ];
        stats.activeSubscribers = subResult.isEmpty() ? 0 : (Integer) subResult[0].get('cnt');
        stats.totalTopics = [SELECT COUNT() FROM Topic__c WHERE IsActive__c = true];
        stats.emailsSentToday = [SELECT COUNT() FROM TopicDeliveryLog__c WHERE SentDate__c = TODAY];
        stats.totalEmailsSent = [SELECT COUNT() FROM TopicDeliveryLog__c];
        stats.totalHelpful    = [SELECT COUNT() FROM TopicDeliveryLog__c WHERE FeedbackRating__c = 'Helpful'];
        stats.totalNotHelpful = [SELECT COUNT() FROM TopicDeliveryLog__c WHERE FeedbackRating__c = 'Not Helpful'];

        return stats;
    }

    @AuraEnabled(cacheable=true)
    public static List<TopicStat> getTopTopics() {
        List<AggregateResult> results = [
            SELECT Topic__c topicId, COUNT(Id) cnt
            FROM UserTopicSubscription__c
            WHERE IsActive__c = true
            GROUP BY Topic__c
            ORDER BY COUNT(Id) DESC
            LIMIT 10
        ];

        Set<Id> topicIds = new Set<Id>();
        for (AggregateResult ar : results) topicIds.add((Id) ar.get('topicId'));

        Map<Id, Topic__c> topicMap = new Map<Id, Topic__c>(
            [SELECT Id, Name, Category__c FROM Topic__c WHERE Id IN :topicIds]
        );

        List<TopicStat> stats = new List<TopicStat>();
        for (AggregateResult ar : results) {
            Id tid = (Id) ar.get('topicId');
            Topic__c t = topicMap.get(tid);
            if (t == null) continue;
            TopicStat ts = new TopicStat();
            ts.id = tid;
            ts.name = t.Name;
            ts.category = t.Category__c;
            ts.subscribers = (Integer) ar.get('cnt');
            stats.add(ts);
        }
        return stats;
    }

    @AuraEnabled(cacheable=true)
    public static List<RecentDelivery> getRecentDeliveries() {
        List<RecentDelivery> deliveries = new List<RecentDelivery>();
        for (TopicDeliveryLog__c log : [
            SELECT Id, Topic__r.Name, User__r.FirstName, User__r.LastName, User__r.Email, SentDate__c, GeneratedContent__c, FeedbackRating__c
            FROM TopicDeliveryLog__c
            ORDER BY CreatedDate DESC
            LIMIT 20
        ]) {
            RecentDelivery rd = new RecentDelivery();
            rd.id = log.Id;
            rd.topicName = log.Topic__r != null ? log.Topic__r.Name : '—';
            String fn = log.User__r.FirstName != null ? log.User__r.FirstName : '';
            String ln = log.User__r.LastName != null ? log.User__r.LastName : '';
            rd.userName = (fn + ' ' + ln).trim();
            rd.userEmail = log.User__r.Email;
            rd.sentDate = log.SentDate__c != null ? log.SentDate__c.format() : '—';
            String body = log.GeneratedContent__c;
            rd.contentPreview = (body != null && body.length() > 120) ? body.substring(0, 120) + '…' : body;
            rd.feedbackRating = log.FeedbackRating__c;
            deliveries.add(rd);
        }
        return deliveries;
    }
}
