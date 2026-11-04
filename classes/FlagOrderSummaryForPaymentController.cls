public with sharing class FlagOrderSummaryForPaymentController {
    @AuraEnabled
    public static void updateLastViewedDateOnOrderSummary(Id orderSummaryId){
        try {
            OrderSummary os = [SELECT Id, Last_Viewed_Date__c
                        FROM OrderSummary
                        WHERE Id =: orderSummaryId];
            
            datetime currentDateTime = datetime.now();

            os.Last_Viewed_Date__c = currentDateTime;

            update os;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}