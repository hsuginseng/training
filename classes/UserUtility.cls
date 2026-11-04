/**
 * @File Name           :   UserUtility.apxc
 * @Description         :   Apex utility class for miscellaneous functionality around Users
 * @Author              :   Jack Huffman - Aleysian
 *==============================================================================
 * Ver         Date                     Author                      Modification
 *==============================================================================
 * 1.0         05.01.2025               Jack Huffman                Initial Handler
**/
public without sharing class UserUtility {
    @AuraEnabled
    public static String fetchPreferredLanguage() {
        String preferredLang;
        String userId = UserInfo.getUserId();
        if(userId != null && userId != '') {
            for(User u : [SELECT Id, Preferred_Language__c FROM User WHERE Id = :userId LIMIT 1]) {
                switch on u.Preferred_Language__c {
                    when 'English' {
                        preferredLang = 'en-US';
                    }
                    when 'Chinese (Traditional)' {
                        preferredLang = 'zh-TW';
                    }
                    when 'Chinese (Simplified)' {
                       preferredLang = 'zh-CN';
                    }
                }
            }
        }

        return preferredLang;
    }

    @AuraEnabled
    public static String getOrderSummaryNumberFromReference(String orderReferenceNumber){
        List<OrderSummary> orderSummaryList = [SELECT Id, OrderNumber FROM OrderSummary WHERE Order_Reference_Number__c=:orderReferenceNumber LIMIT 1];
        if(orderSummaryList.isEmpty()){ return null; }

        return orderSummaryList[0].OrderNumber;
    }

}