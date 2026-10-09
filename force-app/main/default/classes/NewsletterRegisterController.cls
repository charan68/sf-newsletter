public without sharing class NewsletterRegisterController {

    private static final String COMMUNITY_ACCOUNT_NAME = 'Newsletter Community Users';
    private static final String COMMUNITY_PROFILE_NAME = 'Newsletter Community Profile';

    @future
    private static void assignPermissionSetAsync(Id userId) {
        List<PermissionSet> ps = [SELECT Id FROM PermissionSet WHERE Name = 'Newsletter_User' LIMIT 1];
        if (!ps.isEmpty()) {
            insert new PermissionSetAssignment(AssigneeId = userId, PermissionSetId = ps[0].Id);
        }
    }

    @AuraEnabled
    public static Boolean isUsernameAvailable(String username) {
        if (String.isBlank(username)) return false;
        return [SELECT COUNT() FROM User WHERE Username = :username] == 0;
    }

    @AuraEnabled
    public static String registerUser(String firstName, String lastName, String email, String password, String username) {
        try {
            if (String.isBlank(username)) {
                throw new AuraHandledException('Please choose a username.');
            }

            List<User> existingUsers = [SELECT Id FROM User WHERE Username = :username LIMIT 1];
            if (!existingUsers.isEmpty()) {
                return 'USERNAME_TAKEN';
            }

            List<Account> accounts = [
                SELECT Id FROM Account WHERE Name = :COMMUNITY_ACCOUNT_NAME LIMIT 1
            ];
            if (accounts.isEmpty()) {
                throw new AuraHandledException('Registration unavailable: community account not found.');
            }

            List<Profile> profiles = [
                SELECT Id FROM Profile WHERE Name = :COMMUNITY_PROFILE_NAME LIMIT 1
            ];
            if (profiles.isEmpty()) {
                throw new AuraHandledException('Registration unavailable: community profile not found.');
            }

            List<Contact> existing = [
                SELECT Id FROM Contact WHERE Email = :email AND AccountId = :accounts[0].Id LIMIT 1
            ];
            Id contactId;
            if (existing.isEmpty()) {
                Contact c = new Contact(
                    FirstName = firstName,
                    LastName = lastName,
                    Email = email,
                    AccountId = accounts[0].Id
                );
                insert c;
                contactId = c.Id;
            } else {
                contactId = existing[0].Id;
            }

            String alias = (firstName.left(1) + lastName.left(7)).toLowerCase();
            String nickname = (firstName + lastName).replaceAll('[^a-zA-Z0-9]', '').left(36)
                              + String.valueOf(Math.abs(Math.mod(email.hashCode(), 9999)));

            User u = new User(
                FirstName = firstName,
                LastName = lastName,
                Email = email,
                Username = username.toLowerCase(),
                Alias = alias,
                CommunityNickname = nickname.left(40),
                ProfileId = profiles[0].Id,
                ContactId = contactId,
                TimeZoneSidKey = 'America/Los_Angeles',
                LocaleSidKey = 'en_US',
                LanguageLocaleKey = 'en_US',
                EmailEncodingKey = 'UTF-8'
            );

            // Pass accountId as second param; ignored by Salesforce when ContactId is set on the user
            String userId = Site.createExternalUser(u, accounts[0].Id, password, false);
            if (String.isBlank(userId)) {
                return 'ALREADY_EXISTS';
            }

            assignPermissionSetAsync((Id) userId);
            return 'SUCCESS';

        } catch (AuraHandledException ex) {
            throw ex;
        } catch (Exception ex) {
            throw new AuraHandledException('Registration failed: ' + ex.getMessage());
        }
    }
}
