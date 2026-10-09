public without sharing class NewsletterSiteRegisterController {

    private static final String COMMUNITY_ACCOUNT_NAME = 'Newsletter Community Users';
    private static final String COMMUNITY_PROFILE_NAME = 'Newsletter Community Profile';

    public String firstName     { get; set; }
    public String lastName      { get; set; }
    public String email         { get; set; }
    public String password      { get; set; }
    public String confirmPassword { get; set; }
    public String errorMessage  { get; set; }
    public Boolean registered   { get; set; }

    public NewsletterSiteRegisterController() {
        registered = false;
        errorMessage = '';
    }

    public PageReference registerUser() {
        errorMessage = '';

        // Basic validation
        if (String.isBlank(firstName) || String.isBlank(lastName) || String.isBlank(email)) {
            errorMessage = 'Please fill in all required fields.';
            return null;
        }
        if (String.isBlank(password) || password != confirmPassword) {
            errorMessage = 'Passwords do not match.';
            return null;
        }
        if (password.length() < 8) {
            errorMessage = 'Password must be at least 8 characters.';
            return null;
        }

        try {
            // Get the community Account
            List<Account> accounts = [
                SELECT Id FROM Account WHERE Name = :COMMUNITY_ACCOUNT_NAME LIMIT 1
            ];
            if (accounts.isEmpty()) {
                errorMessage = 'Registration is unavailable. Please contact the administrator.';
                return null;
            }

            // Get the community Profile
            List<Profile> profiles = [
                SELECT Id FROM Profile WHERE Name = :COMMUNITY_PROFILE_NAME LIMIT 1
            ];
            if (profiles.isEmpty()) {
                errorMessage = 'Registration is unavailable. Please contact the administrator.';
                return null;
            }

            // Check if a Contact already exists for this email
            List<Contact> existingContacts = [
                SELECT Id FROM Contact WHERE Email = :email AND AccountId = :accounts[0].Id LIMIT 1
            ];

            Id contactId;
            if (existingContacts.isEmpty()) {
                Contact c = new Contact(
                    FirstName = firstName,
                    LastName = lastName,
                    Email = email,
                    AccountId = accounts[0].Id
                );
                insert c;
                contactId = c.Id;
            } else {
                contactId = existingContacts[0].Id;
            }

            // Create the community user
            String username = email;
            User u = new User(
                FirstName = firstName,
                LastName = lastName,
                Email = email,
                Username = username,
                Alias = (firstName.left(1) + lastName.left(7)).toLowerCase(),
                CommunityNickname = (firstName + lastName + String.valueOf(System.currentTimeMillis()).right(4)).left(40),
                ProfileId = profiles[0].Id,
                ContactId = contactId,
                TimeZoneSidKey = 'America/Los_Angeles',
                LocaleSidKey = 'en_US',
                LanguageLocaleKey = 'en_US',
                EmailEncodingKey = 'UTF-8'
            );

            String userId = Site.createExternalUser(u, contactId, password, false);

            if (String.isBlank(userId)) {
                errorMessage = 'Registration failed. This email may already be registered.';
                return null;
            }

            // Log the user in and redirect to home
            PageReference homeRef = new PageReference(Site.getBaseUrl() + '/');
            PageReference loginRef = Site.login(email, password, homeRef.getUrl());
            return (loginRef != null) ? loginRef : homeRef;

        } catch (Site.ExternalUserCreateException ex) {
            errorMessage = ex.getMessage();
            return null;
        } catch (Exception ex) {
            errorMessage = 'An error occurred during registration. Please try again.';
            return null;
        }
    }
}
