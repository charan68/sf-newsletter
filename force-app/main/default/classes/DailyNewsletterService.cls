public without sharing class DailyNewsletterService {

    public static void processAllSubscribers() {
        List<AggregateResult> activeUsers = [
            SELECT User__c
            FROM UserTopicSubscription__c
            WHERE IsActive__c = true AND User__c != null
            GROUP BY User__c
        ];

        Map<Id, UserNewsletterPreference__c> prefMap = new Map<Id, UserNewsletterPreference__c>();
        for (UserNewsletterPreference__c p : [
            SELECT User__c, DeliveryFrequency__c, WeeklyDeliveryDay__c
            FROM UserNewsletterPreference__c
        ]) {
            prefMap.put(p.User__c, p);
        }

        String todayName = DateTime.now().format('EEEE'); // e.g. 'Monday'

        for (AggregateResult ar : activeUsers) {
            Id userId = (Id) ar.get('User__c');
            UserNewsletterPreference__c pref = prefMap.get(userId);
            String frequency = (pref != null && pref.DeliveryFrequency__c != null) ? pref.DeliveryFrequency__c : 'Daily';

            if (frequency == 'Weekly') {
                String deliveryDay = (pref.WeeklyDeliveryDay__c != null) ? pref.WeeklyDeliveryDay__c : 'Monday';
                if (todayName == deliveryDay) {
                    processUserWeekly(userId);
                }
            } else {
                processUser(userId);
            }
        }
    }

    public static void processUserFirstEdition(Id userId) {
        List<UserTopicSubscription__c> subscriptions = [
            SELECT Topic__c FROM UserTopicSubscription__c WHERE User__c = :userId AND IsActive__c = true
        ];
        if (subscriptions.isEmpty()) return;

        List<Id> topicIds = new List<Id>();
        for (UserTopicSubscription__c s : subscriptions) topicIds.add(s.Topic__c);
        Integer idx = Math.mod(Math.abs(Crypto.getRandomInteger()), topicIds.size());
        Id chosenId = topicIds[idx];

        Topic__c topic = [SELECT Id, Name, Description__c FROM Topic__c WHERE Id = :chosenId LIMIT 1];
        String content = EinsteinPromptService.generateTopicContent(topic.Name, topic.Description__c);

        User recipient = [SELECT Email, FirstName FROM User WHERE Id = :userId LIMIT 1];
        sendFirstEditionEmail(recipient, topic.Name, content, userId, chosenId);

        insert new TopicDeliveryLog__c(
            User__c = userId, Topic__c = chosenId,
            SentDate__c = Date.today(), GeneratedContent__c = content
        );
    }

    public static void processUser(Id userId) {
        List<UserTopicSubscription__c> subscriptions = [
            SELECT Topic__c FROM UserTopicSubscription__c WHERE User__c = :userId AND IsActive__c = true
        ];
        Set<Id> subscribedTopicIds = new Set<Id>();
        for (UserTopicSubscription__c sub : subscriptions) { subscribedTopicIds.add(sub.Topic__c); }
        if (subscribedTopicIds.isEmpty()) return;

        List<TopicDeliveryLog__c> delivered = [SELECT Topic__c FROM TopicDeliveryLog__c WHERE User__c = :userId];
        Set<Id> deliveredTopicIds = new Set<Id>();
        for (TopicDeliveryLog__c log : delivered) { deliveredTopicIds.add(log.Topic__c); }

        Set<Id> remaining = new Set<Id>(subscribedTopicIds);
        remaining.removeAll(deliveredTopicIds);

        if (remaining.isEmpty()) {
            delete [SELECT Id FROM TopicDeliveryLog__c WHERE User__c = :userId];
            remaining = new Set<Id>(subscribedTopicIds);
        }

        Id chosenTopicId = new List<Id>(remaining)[0];
        Topic__c topic = [SELECT Id, Name, Description__c FROM Topic__c WHERE Id = :chosenTopicId LIMIT 1];
        String content = EinsteinPromptService.generateTopicContent(topic.Name, topic.Description__c);

        User recipient = [SELECT Email, FirstName FROM User WHERE Id = :userId LIMIT 1];
        sendDailyEmail(recipient, topic.Name, content, userId, chosenTopicId);

        insert new TopicDeliveryLog__c(
            User__c = userId, Topic__c = chosenTopicId,
            SentDate__c = Date.today(), GeneratedContent__c = content
        );
    }

    public static void processUserWeekly(Id userId) {
        List<UserTopicSubscription__c> subscriptions = [
            SELECT Topic__c FROM UserTopicSubscription__c WHERE User__c = :userId AND IsActive__c = true
        ];
        Set<Id> subscribedTopicIds = new Set<Id>();
        for (UserTopicSubscription__c sub : subscriptions) { subscribedTopicIds.add(sub.Topic__c); }
        if (subscribedTopicIds.isEmpty()) return;

        List<TopicDeliveryLog__c> delivered = [SELECT Topic__c FROM TopicDeliveryLog__c WHERE User__c = :userId];
        Set<Id> deliveredTopicIds = new Set<Id>();
        for (TopicDeliveryLog__c log : delivered) { deliveredTopicIds.add(log.Topic__c); }

        Set<Id> remaining = new Set<Id>(subscribedTopicIds);
        remaining.removeAll(deliveredTopicIds);

        Boolean resetCycle = remaining.isEmpty();
        if (resetCycle) remaining = new Set<Id>(subscribedTopicIds);

        // Pick up to 3 topics
        List<Id> chosenIds = new List<Id>();
        for (Id tid : remaining) {
            chosenIds.add(tid);
            if (chosenIds.size() == 3) break;
        }

        List<Topic__c> topics = [SELECT Id, Name, Description__c FROM Topic__c WHERE Id IN :chosenIds];

        // Generate content for each — callouts before any DML
        List<String> contents = new List<String>();
        for (Topic__c t : topics) {
            contents.add(EinsteinPromptService.generateTopicContent(t.Name, t.Description__c));
        }

        // Now DML — reset cycle if needed
        if (resetCycle) {
            delete [SELECT Id FROM TopicDeliveryLog__c WHERE User__c = :userId];
        }

        List<TopicDeliveryLog__c> logs = new List<TopicDeliveryLog__c>();
        for (Integer i = 0; i < topics.size(); i++) {
            logs.add(new TopicDeliveryLog__c(
                User__c = userId, Topic__c = topics[i].Id,
                SentDate__c = Date.today(), GeneratedContent__c = contents[i]
            ));
        }
        insert logs;

        User recipient = [SELECT Email, FirstName FROM User WHERE Id = :userId LIMIT 1];
        sendWeeklyDigestEmail(recipient, topics, contents);
    }

    @future
    public static void sendWelcomeEmailAsync(Id userId, List<String> topicIdStrings) {
        if (topicIdStrings == null || topicIdStrings.isEmpty()) return;
        List<Id> topicIds = new List<Id>();
        for (String s : topicIdStrings) topicIds.add((Id) s);

        List<Topic__c> topics = [SELECT Id, Name, Category__c FROM Topic__c WHERE Id IN :topicIds ORDER BY Name];
        if (topics.isEmpty()) return;

        User recipient = [SELECT Email, FirstName FROM User WHERE Id = :userId LIMIT 1];
        sendWelcomeEmail(recipient, topics);
    }

    private static Id getOrgWideEmailAddressId() {
        List<OrgWideEmailAddress> owas = [SELECT Id FROM OrgWideEmailAddress LIMIT 1];
        return owas.isEmpty() ? null : owas[0].Id;
    }

    private static String buildFeedbackFooter(Id userId, Id topicId) {
        String base = 'https://sfdaily6.my.site.com/newsletters/s/feedback';
        String helpful    = base + '?uid=' + userId + '&tid=' + topicId + '&r=helpful';
        String notHelpful = base + '?uid=' + userId + '&tid=' + topicId + '&r=nothelpful';
        return
            '<div style="text-align: center; padding: 20px 0 8px 0; border-top: 1px solid #eee; margin-top: 28px;">' +
            '<p style="color: #706E6B; font-size: 13px; margin: 0 0 12px 0;">Was this edition helpful?</p>' +
            '<a href="' + helpful + '" style="display: inline-block; background: #2E844A; color: white; text-decoration: none; padding: 10px 22px; border-radius: 6px; font-size: 14px; font-weight: 600; margin-right: 10px;">👍 Helpful</a>' +
            '<a href="' + notHelpful + '" style="display: inline-block; background: #C23934; color: white; text-decoration: none; padding: 10px 22px; border-radius: 6px; font-size: 14px; font-weight: 600;">👎 Not Helpful</a>' +
            '</div>';
    }

    private static void sendFirstEditionEmail(User recipient, String topicName, String content, Id feedbackUserId, Id feedbackTopicId) {
        String greeting = String.isBlank(recipient.FirstName) ? 'there' : recipient.FirstName;
        String htmlBody =
            '<html><body style="font-family: Arial, sans-serif; max-width: 600px; margin: auto; padding: 20px; background: #f5f5f5;">' +
            '<div style="background: white; border-radius: 10px; overflow: hidden; box-shadow: 0 2px 8px rgba(0,0,0,0.08);">' +
            '<div style="background: linear-gradient(135deg, #032D60, #1B96FF); padding: 24px;">' +
            '<h1 style="color: white; margin: 0; font-size: 20px;">SF Daily Newsletter</h1>' +
            '<p style="color: #BDE0FF; margin: 4px 0 0 0; font-size: 13px;">Your Salesforce knowledge, delivered daily</p>' +
            '</div>' +
            '<div style="background: #FFF8E1; border-left: 4px solid #F0AD00; padding: 14px 20px;">' +
            '<p style="margin: 0; color: #5D4037; font-size: 14px;">' +
            '<strong>Welcome, ' + greeting + '! This is your first edition.</strong> ' +
            'From now on you\'ll receive one in-depth topic like this every day.</p>' +
            '</div>' +
            '<div style="padding: 28px 24px;">' +
            '<p style="color: #555; font-size: 14px; margin: 0 0 20px 0; line-height: 1.6;">' +
            'Here is an example of the kind of in-depth content you\'ll receive daily, generated specifically for one of your subscribed topics:' +
            '</p>' +
            '<h2 style="color: #032D60; margin: 0 0 16px 0; font-size: 20px;">' + topicName + '</h2>' +
            '<div style="line-height: 1.8; color: #333; font-size: 15px;">' + content.replace('\n', '<br/>') + '</div>' +
            buildFeedbackFooter(feedbackUserId, feedbackTopicId) +
            '<p style="font-size: 12px; color: #aaa; margin: 16px 0 0 0;">To manage your subscriptions or change delivery frequency, visit the newsletter portal.</p>' +
            '</div></div></body></html>';

        Id owaId = getOrgWideEmailAddressId();
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setToAddresses(new List<String>{ recipient.Email });
        if (owaId != null) email.setOrgWideEmailAddressId(owaId);
        email.setSubject('Your First Edition: ' + topicName + ' — Welcome to SF Daily Newsletter!');
        email.setHtmlBody(htmlBody);
        email.setSaveAsActivity(false);
        Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ email });
    }

    private static void sendDailyEmail(User recipient, String topicName, String content, Id feedbackUserId, Id feedbackTopicId) {
        String greeting = String.isBlank(recipient.FirstName) ? 'there' : recipient.FirstName;
        String htmlBody =
            '<html><body style="font-family: Arial, sans-serif; max-width: 600px; margin: auto; padding: 20px; background: #f5f5f5;">' +
            '<div style="background: white; border-radius: 10px; overflow: hidden; box-shadow: 0 2px 8px rgba(0,0,0,0.08);">' +
            '<div style="background: linear-gradient(135deg, #032D60, #1B96FF); padding: 24px;">' +
            '<h1 style="color: white; margin: 0; font-size: 20px;">SF Daily Newsletter</h1>' +
            '<p style="color: #BDE0FF; margin: 4px 0 0 0; font-size: 13px;">Your Salesforce knowledge, delivered daily</p>' +
            '</div>' +
            '<div style="padding: 28px 24px;">' +
            '<p style="color: #555; margin: 0 0 6px 0; font-size: 14px;">Hi ' + greeting + ',</p>' +
            '<h2 style="color: #032D60; margin: 0 0 16px 0; font-size: 20px;">' + topicName + '</h2>' +
            '<div style="line-height: 1.8; color: #333; font-size: 15px;">' + content.replace('\n', '<br/>') + '</div>' +
            buildFeedbackFooter(feedbackUserId, feedbackTopicId) +
            '<p style="font-size: 12px; color: #aaa; margin: 16px 0 0 0;">To manage your subscriptions or change delivery frequency, visit the newsletter portal.</p>' +
            '</div></div></body></html>';

        Id owaId = getOrgWideEmailAddressId();
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setToAddresses(new List<String>{ recipient.Email });
        if (owaId != null) email.setOrgWideEmailAddressId(owaId);
        email.setSubject('Your Daily Topic: ' + topicName);
        email.setHtmlBody(htmlBody);
        email.setSaveAsActivity(false);
        Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ email });
    }

    private static void sendWeeklyDigestEmail(User recipient, List<Topic__c> topics, List<String> contents) {
        String greeting = String.isBlank(recipient.FirstName) ? 'there' : recipient.FirstName;

        String topicSections = '';
        for (Integer i = 0; i < topics.size(); i++) {
            topicSections +=
                '<div style="margin-bottom: 28px; padding-bottom: 24px; border-bottom: 1px solid #eee;">' +
                '<h3 style="color: #032D60; margin: 0 0 10px 0;">' + (i + 1) + '. ' + topics[i].Name + '</h3>' +
                '<p style="line-height: 1.7; color: #333; margin: 0;">' + contents[i].replace('\n', '<br/>') + '</p>' +
                '</div>';
        }

        String htmlBody =
            '<html><body style="font-family: Arial, sans-serif; max-width: 600px; margin: auto; padding: 20px;">' +
            '<div style="background: #032D60; padding: 20px; border-radius: 8px 8px 0 0; display: flex; justify-content: space-between; align-items: center;">' +
            '<h2 style="color: white; margin: 0;">SF Weekly Digest</h2>' +
            '<span style="color: #90CAF9; font-size: 13px;">' + topics.size() + ' topics this week</span>' +
            '</div>' +
            '<div style="background: #F3F9FF; border-left: 4px solid #1B96FF; padding: 12px 20px; border-right: 1px solid #e0e0e0;">' +
            '<p style="margin: 0; color: #032D60; font-size: 14px;">Hi ' + greeting + '! Here\'s your weekly Salesforce knowledge digest.</p>' +
            '</div>' +
            '<div style="border: 1px solid #e0e0e0; border-top: none; padding: 24px; border-radius: 0 0 8px 8px;">' +
            topicSections +
            '<p style="font-size: 12px; color: #999; margin: 0;">To manage your subscriptions or change delivery frequency, visit the newsletter portal.</p>' +
            '</div></body></html>';

        Id owaId = getOrgWideEmailAddressId();
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setToAddresses(new List<String>{ recipient.Email });
        if (owaId != null) email.setOrgWideEmailAddressId(owaId);
        email.setSubject('Your Weekly SF Newsletter Digest — ' + topics.size() + ' Topics Inside');
        email.setHtmlBody(htmlBody);
        email.setSaveAsActivity(false);
        Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ email });
    }

    private static void sendWelcomeEmail(User recipient, List<Topic__c> topics) {
        String greeting = String.isBlank(recipient.FirstName) ? 'there' : recipient.FirstName;

        String topicListHtml = '';
        for (Topic__c t : topics) {
            topicListHtml +=
                '<li style="padding: 6px 0; color: #032D60; font-size: 15px;">' +
                '<strong>' + t.Name + '</strong>' +
                (String.isNotBlank(t.Category__c) ? ' <span style="color:#888; font-size:13px;">(' + t.Category__c + ')</span>' : '') +
                '</li>';
        }

        String htmlBody =
            '<html><body style="font-family: Arial, sans-serif; max-width: 600px; margin: auto; padding: 20px; background: #f5f5f5;">' +
            '<div style="background: white; border-radius: 10px; overflow: hidden; box-shadow: 0 2px 8px rgba(0,0,0,0.08);">' +
            '<div style="background: linear-gradient(135deg, #032D60, #1B96FF); padding: 28px 24px;">' +
            '<h1 style="color: white; margin: 0; font-size: 22px; font-weight: 700;">SF Daily Newsletter</h1>' +
            '<p style="color: #BDE0FF; margin: 6px 0 0 0; font-size: 14px;">Your Salesforce knowledge, delivered daily</p>' +
            '</div>' +
            '<div style="padding: 28px 24px;">' +
            '<h2 style="color: #032D60; margin: 0 0 8px 0; font-size: 20px;">Welcome aboard, ' + greeting + '! 🎉</h2>' +
            '<p style="color: #444; line-height: 1.6; margin: 0 0 20px 0;">You\'ve successfully subscribed to the SF Daily Newsletter. ' +
            'Starting <strong>tomorrow</strong>, you\'ll receive in-depth, AI-generated insights on the topics you care about — delivered straight to your inbox.</p>' +

            '<div style="background: #F3F9FF; border: 1px solid #C9E4FF; border-radius: 8px; padding: 18px 20px; margin-bottom: 24px;">' +
            '<p style="margin: 0 0 10px 0; color: #032D60; font-weight: 600; font-size: 14px;">Your subscribed topics:</p>' +
            '<ul style="margin: 0; padding-left: 20px; list-style: disc;">' +
            topicListHtml +
            '</ul>' +
            '</div>' +

            '<div style="background: #FFF8E1; border-left: 4px solid #F0AD00; padding: 14px 18px; border-radius: 0 6px 6px 0; margin-bottom: 24px;">' +
            '<p style="margin: 0; color: #5D4037; font-size: 14px; line-height: 1.5;">' +
            '<strong>What to expect:</strong> Each edition covers one topic in depth — key concepts, practical examples, ' +
            'and the latest Salesforce best practices — all generated by Einstein AI and tailored to your interests.' +
            '</p>' +
            '</div>' +

            '<p style="color: #555; font-size: 14px; line-height: 1.6; margin: 0 0 24px 0;">' +
            'You can update your topics, change delivery frequency (daily or weekly), or unsubscribe at any time ' +
            'from the <a href="https://sfdaily6.my.site.com/newsletters/" style="color: #1B96FF;">newsletter portal</a>.' +
            '</p>' +

            '<hr style="border: none; border-top: 1px solid #eee; margin: 0 0 16px 0;"/>' +
            '<p style="font-size: 12px; color: #aaa; margin: 0;">SF Daily Newsletter • Salesforce Internal</p>' +
            '</div></div></body></html>';

        Id owaId = getOrgWideEmailAddressId();
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setToAddresses(new List<String>{ recipient.Email });
        if (owaId != null) email.setOrgWideEmailAddressId(owaId);
        email.setSubject('Welcome to SF Daily Newsletter — Your AI-Powered Salesforce Digest Starts Tomorrow!');
        email.setHtmlBody(htmlBody);
        email.setSaveAsActivity(false);
        Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ email });
    }
}
