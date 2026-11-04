global class LightningSelfRegisterController {

    public LightningSelfRegisterController() {

    }

    @TestVisible 
    private static boolean isValidPassword(String password, String confirmPassword) {
        return password == confirmPassword;
    }
    
    @TestVisible 
    private static boolean siteAsContainerEnabled(String communityUrl) {
        Auth.AuthConfiguration authConfig = new Auth.AuthConfiguration(communityUrl,'');
        return authConfig.isCommunityUsingSiteAsContainer();
    }
    
    @TestVisible 
    private static void validatePassword(User u, String password, String confirmPassword) {
        if(!Test.isRunningTest()) {
        Site.validatePassword(u, password, confirmPassword);
        }
        return;
    }
    
    @AuraEnabled
    // MODIFICATION 1: Added birthday and referralCode to the method signature.
    public static String selfRegister(String firstname ,String lastname, String email, String phone, String password, String confirmPassword, String accountId, String regConfirmUrl, String startUrl, Boolean includePassword, String preferredLanguage, Date birthday, String referralCode) {
        Savepoint sp = null;
        try {
            sp = Database.setSavepoint();
            
            if(firstname == null || String.isEmpty(firstname)) {
                return System.Label.SelfRegisterPortalFirstNameError;         
            }

            if (lastname == null || String.isEmpty(lastname)) {
                return Label.Site.lastname_is_required;
            }
            
            if (email == null || String.isEmpty(email)) {
                return Label.Site.email_is_required;
            }
            
            User u = new User();
            u.Username = email;
            u.put('Email',email);
            
            u.FirstName = firstname;
            u.LastName = lastname;
            u.Phone = phone;
            u.MobilePhone = phone;
            
            String networkId = Network.getNetworkId();

            if(networkId != null && siteAsContainerEnabled(Network.getLoginUrl(networkId))) {
                u.put('UserPreferencesHideS1BrowserUI',true);
            }
            
            String nickname = ((firstname != null && firstname.length() > 0) ? firstname.substring(0,1) : '' ) + lastname.substring(0,1);
            nickname += String.valueOf(Crypto.getRandomInteger()).substring(1,7);
            u.put('CommunityNickname', nickname);
                        
            // if (extraFields != null) {
            //     List<Object> extraFieldsList = (List<Object>) JSON.deserializeUntyped(extraFields);        
            //     for (Object thisFieldObject : extraFieldsList) {
            //         Map<String,Object> thisField = (Map<String,Object>) thisFieldObject;
            //         Schema.SObjectField sof = Schema.SObjectType.User.fields.getMap().get((String) thisField.get('fieldPath'));
            //         u.put(sof, thisField.get('value'));
            //     }
            // }
                        
            if (includePassword) {    
                if (!isValidPassword(password, confirmPassword)) {
                    return Label.site.passwords_dont_match;
                }
             validatePassword(u, password, confirmPassword);
            }
            else {
                password = null;
            }
            
            String userId = Site.createExternalUser(u, accountId, password);

            //User is not available for update in this transaction
            //Asynchronously capture preferred language for new user
            setPreferredLanguageOnUser(userId, preferredLanguage);
            enableUserAsBuyer(userId);
            assignCommerceShopperPermissions(userId);
            addCustomFieldsToAccount(userId, birthday, referralCode, preferredLanguage);

            if (Test.isRunningTest()) {
                userId = 'fakeUserId';            
            }
            if (userId != null) {    
                if (password != null && password.length() > 1) {
                    ApexPages.PageReference lgn = Site.login(email, password, startUrl);
                    if(!Test.isRunningTest()) {
                        String uri = '/';
                        switch on preferredLanguage {
                            when 'simplifiedChinese' { uri='/zh_CN/'; }
                            when 'traditionalChinese' { uri='/zh_TW/'; }
                        }
                    
                        return lgn.getUrl()+uri;
                    }
                }
                else {
                    ApexPages.PageReference confirmRef = new PageReference(regConfirmUrl);
                    if(!Test.isRunningTest()) {
                        aura.redirect(confirmRef);
                   }

                }
            }

            return null;
        }
        catch (Exception ex) {
            Database.rollback(sp);
            System.debug('Error message: ' + ex.getMessage());
            if(ex.getMessage().containsIgnoreCase('user already exists') ||
               ex.getMessage().containsIgnoreCase('用户已存在') ||
               ex.getMessage().containsIgnoreCase('使用者已經存在')) {
                return System.Label.SelfRegisterPortalUserError;
            }
            return ex.getMessage();
        }
    }
    
    // @AuraEnabled
    // public static List<Map<String,Object>> getExtraFields(String extraFieldsFieldSet) {    
    //     List<Map<String,Object>> extraFields = new List<Map<String,Object>>();
    //     Schema.FieldSet fieldSet = Schema.SObjectType.User.fieldSets.getMap().get(extraFieldsFieldSet);
    //     if(!Test.isRunningTest()) {
    //     if (fieldSet != null) {
    //         for (Schema.FieldSetMember f : fieldSet.getFields()) {
    //             Map<String, Object> fieldDetail = new Map<String, Object>();
    //             fieldDetail.put('dbRequired', f.getDBRequired());
    //             fieldDetail.put('fieldPath', f.getFieldPath());
    //             fieldDetail.put('label', f.getLabel());
    //             fieldDetail.put('required', f.getRequired());
    //             fieldDetail.put('type', f.getType());
    //             fieldDetail.put('value', '');
    //             extraFields.add(fieldDetail);
    //         }}}
    //     return extraFields;
    // }
    
    // @AuraEnabled
    // global static String setExperienceId(String expId) {
    //     try {
    //         if (expId != null) {
    //             Site.setExperienceId(expId);    
    //         }
    //         return null;    
    //     } catch (Exception ex) {
    //         return ex.getMessage();            
    //     }        
    // }

    @future
    private static void setPreferredLanguageOnUser(Id userId, String language){
        String userLanguage;
        String userLanguageKey;
        switch on language {
            when 'english' { userLanguage = 'English'; userLanguageKey='en_US'; }
            when 'simplifiedChinese' { userLanguage = 'Chinese (Simplified)'; userLanguageKey='zh_CN'; }
            when 'traditionalChinese' { userLanguage = 'Chinese (Traditional)'; userLanguageKey='zh_TW'; }
            when else { return; }
        }

        update new User(Id=userId, Preferred_Language__c=userLanguage, LanguageLocaleKey=userLanguageKey, LocaleSidKey=userLanguageKey);
    }

    @future
    private static void enableUserAsBuyer(Id userId){
        if(!Test.isRunningTest()){
            User currentUser = [SELECT Name, AccountId FROM User WHERE Id=:userId LIMIT 1];
            BuyerAccount userBuyerAccount = new BuyerAccount(Name=currentUser.Name + ' - Buyer Account', PayerId=currentUser.AccountId, BuyerId=currentUser.AccountId, CommerceType='Buyer', BuyerStatus='Active', IsActive=true);
            insert userBuyerAccount;
        }
    }

    @future
    private static void assignCommerceShopperPermissions(Id userId){
        if(!Test.isRunningTest()){
            PermissionSetGroup commercePsg = [SELECT Id FROM PermissionSetGroup WHERE DeveloperName='Commerce_Shopper' LIMIT 1];
            PermissionSetAssignment psa = new PermissionSetAssignment(PermissionSetGroupId=commercePsg.Id, AssigneeId=userId);
            insert psa;
        }
    }

    @future
    private static void addCustomFieldsToAccount(Id userId, Date birthday, String referralCode, String preferredLanguage){
        if(!(birthday == null && referralCode == null)) {
            Account personAccountToUpdate;
            if(!Test.isRunningTest()){
                User currentUser = [SELECT Name, AccountId FROM User WHERE Id=:userId LIMIT 1];
                personAccountToUpdate = [SELECT PersonBirthdate, Referred_By_Code_Loyalty_Member__c FROM Account WHERE Id=:currentUser.AccountId LIMIT 1];
            } else {
                personAccountToUpdate = [SELECT FirstName, LastName, PersonBirthdate, Referred_By_Code_Loyalty_Member__c FROM Account WHERE FirstName = 'test' AND LastName = 'User' LIMIT 1];
            }
            if(birthday != null) {
                personAccountToUpdate.PersonBirthdate = birthday;
            }
            if (referralCode != null) {
                personAccountToUpdate.Referred_By_Code_Loyalty_Member__c = referralCode;
            }
            if (preferredLanguage != null) {
                String selectedLanguage;

                switch on preferredLanguage {
                    when 'english' { selectedLanguage = 'English'; }
                    when 'simplifiedChinese' { selectedLanguage = 'Chinese (Simplified)'; }
                    when 'traditionalChinese' { selectedLanguage = 'Chinese (Traditional)'; }
                }
                personAccountToUpdate.Preferred_Language__c = selectedLanguage;
            }
            update personAccountToUpdate;
        }
    }
}