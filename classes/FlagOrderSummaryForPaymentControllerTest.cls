@IsTest
private class FlagOrderSummaryForPaymentControllerTest {
    @IsTest(SeeAllData=true)
    static void testUpdateLastViewedDate() {
        // Retrieve the test OrderSummary
        OrderSummary os = [SELECT Id FROM OrderSummary LIMIT 1];

        // Execute the method
        Test.startTest();
        FlagOrderSummaryForPaymentController.updateLastViewedDateOnOrderSummary(os.Id);
        Test.stopTest();

        // Verify the update
        OrderSummary updatedOs = [SELECT Last_Viewed_Date__c FROM OrderSummary WHERE Id = :os.Id];
        
        Assert.areNotEqual(null, updatedOs.Last_Viewed_Date__c, 'Last Viewed Date should have been updated.');
        // Verify it was updated to roughly "now" (within a 1-minute margin)
        Assert.isTrue(updatedOs.Last_Viewed_Date__c > DateTime.now().addMinutes(-1), 'Date should be recent.');
    }

    @IsTest(SeeAllData=true)
    static void testUpdateLastViewedDate_Error() {
        // Test with an invalid ID to trigger the catch block
        Boolean exceptionThrown = false;
        
        try {
            Test.startTest();
            // Passing a dummy Account ID instead of OrderSummary ID
            FlagOrderSummaryForPaymentController.updateLastViewedDateOnOrderSummary(null);
            Test.stopTest();
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }

        Assert.isTrue(exceptionThrown, 'An AuraHandledException should have been thrown for a null ID.');
    }
}