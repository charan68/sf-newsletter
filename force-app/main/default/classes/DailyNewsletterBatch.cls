public class DailyNewsletterBatch implements Database.Batchable<SObject>, Database.AllowsCallouts {

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator(
            'SELECT Id FROM User WHERE Id IN (SELECT User__c FROM UserTopicSubscription__c WHERE IsActive__c = true)'
        );
    }

    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        String todayName = DateTime.now().format('EEEE');

        Set<Id> userIds = new Set<Id>();
        for (SObject s : scope) userIds.add(s.Id);

        Map<Id, UserNewsletterPreference__c> prefMap = new Map<Id, UserNewsletterPreference__c>();
        for (UserNewsletterPreference__c p : [
            SELECT User__c, DeliveryFrequency__c, WeeklyDeliveryDay__c
            FROM UserNewsletterPreference__c
            WHERE User__c IN :userIds
        ]) {
            prefMap.put(p.User__c, p);
        }

        for (SObject s : scope) {
            Id userId = s.Id;
            UserNewsletterPreference__c pref = prefMap.get(userId);
            String frequency = (pref != null && pref.DeliveryFrequency__c != null)
                ? pref.DeliveryFrequency__c : 'Daily';

            if (frequency == 'Weekly') {
                String deliveryDay = (pref.WeeklyDeliveryDay__c != null)
                    ? pref.WeeklyDeliveryDay__c : 'Monday';
                if (todayName == deliveryDay) {
                    DailyNewsletterService.processUserWeekly(userId);
                }
            } else {
                DailyNewsletterService.processUser(userId);
            }
        }
    }

    public void finish(Database.BatchableContext bc) {}
}
