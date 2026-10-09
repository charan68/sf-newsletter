public without sharing class NavController {
    @AuraEnabled(cacheable=true)
    public static User getCurrentUser() {
        return [SELECT Id, FirstName, LastName, Name FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
    }
}
