public class WelcomeEmailBatch implements Database.Batchable<SObject>, Database.AllowsCallouts {

    public Database.QueryLocator start(Database.BatchableContext bc) {
        // Find users who subscribed in the last 7 days but have never received any newsletter content
        Set<Id> usersWithLogs = new Set<Id>();
        for (TopicDeliveryLog__c log : [SELECT User__c FROM TopicDeliveryLog__c]) {
            usersWithLogs.add(log.User__c);
        }

        Set<Id> newSubscriberIds = new Set<Id>();
        for (AggregateResult ar : [
            SELECT User__c
            FROM UserTopicSubscription__c
            WHERE IsActive__c = true AND CreatedDate = LAST_N_DAYS:7
            GROUP BY User__c
        ]) {
            Id uid = (Id) ar.get('User__c');
            if (!usersWithLogs.contains(uid)) {
                newSubscriberIds.add(uid);
            }
        }

        return Database.getQueryLocator([
            SELECT Id FROM User WHERE Id IN :newSubscriberIds
        ]);
    }

    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        Id userId = ((User) scope[0]).Id;
        DailyNewsletterService.processUserFirstEdition(userId);
    }

    public void finish(Database.BatchableContext bc) {}
}
