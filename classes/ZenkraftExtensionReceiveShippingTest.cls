/**
 * @description Test class for ZenkraftExtensionReceiveShippingOptions.
 * This class performs a true integration test, calling the actual
 * D2cCheckoutCustomShippingLogicController to validate the end-to-end process.
 */
@isTest
public with sharing class ZenkraftExtensionReceiveShippingTest {

    /**
     * @description Sets up common data including Products, Account, and WebStore.
     * This data is used by the helper method to construct various cart scenarios.
     */
    @TestSetup
    static void makeData() {
        // Create Account and WebStore
        Account buyerAccount = new Account(Name = 'Test Buyer Account');
        insert buyerAccount;
        WebStore store = new WebStore(
            Name = 'Test Store', 
            DefaultLanguage = 'en_US',
            SupportedLanguages = 'en_US' // FIX: Added SupportedLanguages to resolve DML exception
        );
        insert store;

        // Create a Standard and Fresh Product
        Product2 standardProduct = new Product2(
            Name = 'Standard Product', IsActive = true, Shipping_Category__c = 'Standard', Shipping_Weight_Oz__c = 48.0
        );
        Product2 freshProduct = new Product2(
            Name = 'Fresh Product', IsActive = true, Shipping_Category__c = 'Fresh', Shipping_Weight_Oz__c = 32.0
        );
        insert new List<Product2>{standardProduct, freshProduct};
    }

    /**
     * @description Reusable helper to create a WebCart with specific items and shipping details.
     * This allows each test to precisely control the inputs to the controller logic.
     * @param shippingState Two-letter state code for the delivery address.
     * @param addFresh If true, adds a fresh product to the cart.
     * @param addStandard If true, adds a standard product to the cart.
     * @return The newly created WebCart record.
     */
    private static WebCart createTestCart(String shippingState, Boolean addFresh, Boolean addStandard) {
        Account buyerAccount = [SELECT Id FROM Account WHERE Name = 'Test Buyer Account' LIMIT 1];
        WebStore store = [SELECT Id FROM WebStore LIMIT 1];
        Product2 stdProduct = [SELECT Id, Shipping_Weight_Oz__c FROM Product2 WHERE Name = 'Standard Product' LIMIT 1];
        Product2 freshProduct = [SELECT Id, Shipping_Weight_Oz__c FROM Product2 WHERE Name = 'Fresh Product' LIMIT 1];

        WebCart cart = new WebCart(
            Name = 'Test Cart',
            WebStoreId = store.Id,
            AccountId = buyerAccount.Id
            // NOTE: We do not set Is_Destination_State_In_Two_Day_Zone__c or Is_Destination_State_In_Lower_48__c here.
            // This will be populated by your org's automation when the CartDeliveryGroup is inserted.
        );
        insert cart;
        
        CartDeliveryGroup cdg = new CartDeliveryGroup(
            CartId = cart.Id, Name = 'Standard Shipment', DeliverToState = shippingState, DeliverToCountry = 'US'
        );
        insert cdg;
        
        List<CartItem> itemsToInsert = new List<CartItem>();

        if (addStandard) {
            itemsToInsert.add(new CartItem(
                CartId = cart.Id, CartDeliveryGroupId = cdg.Id, Product2Id = stdProduct.Id, Name = 'Std Item', Quantity = 1, Type = 'Product'
                // NOTE: We do not set Shipping_Category__c. This should be populated by automation from the Product2 record.
            ));
        }
        if (addFresh) {
            itemsToInsert.add(new CartItem(
                CartId = cart.Id, CartDeliveryGroupId = cdg.Id, Product2Id = freshProduct.Id, Name = 'Fresh Item', Quantity = 1, Type = 'Product'
            ));
        }
        if (!itemsToInsert.isEmpty()) {
            insert itemsToInsert;
        }

        // Re-query the cart to get the field values that were populated by automation
        WebCart updatedCart = [SELECT Id, Total_Shipping_Weight_LBs__c, Fresh_Ginseng_Weight__c FROM WebCart WHERE Id = :cart.Id];

        // Now, we can calculate and set the final weights on the cart record
        Decimal totalWeightLbs = 0;
        Decimal freshWeightLbs = 0;
        
        List<CartItem> insertedItems = [SELECT Product2.Shipping_Weight_Oz__c, Product2.Shipping_Category__c FROM CartItem WHERE CartId = :cart.Id];
        for (CartItem item : insertedItems) {
            if (item.Product2.Shipping_Weight_Oz__c != null) {
                Decimal itemWeightLbs = item.Product2.Shipping_Weight_Oz__c / 16;
                totalWeightLbs += itemWeightLbs;
                if (item.Product2.Shipping_Category__c == 'Fresh') {
                    freshWeightLbs += itemWeightLbs;
                }
            }
        }

        updatedCart.Total_Shipping_Weight_LBs__c = totalWeightLbs;
        updatedCart.Fresh_Ginseng_Weight__c = freshWeightLbs;
        update updatedCart;

        return updatedCart;
    }

    @isTest 
    private static void testSuccessPath_NoSplitOccurs() {
        // SCENARIO: D2cController returns false (e.g. shipping to a 2-day zone).
        // The main Zenkraft logic should then execute successfully.
        WebCart cart = createTestCart('IL', true, true); // IL is a 2-day zone, so no split occurs.

        zkmulti.MultiCarrierCalloutMockImpl mcMockImpl = new zkmulti.MultiCarrierCalloutMockImpl('FedEx');
        mcMockImpl.setMockWebservice();
        
        Test.startTest();
        ZenkraftExtensionReceiveShippingOptions apexSample = new ZenkraftExtensionReceiveShippingOptions();
        sfdc_checkout.IntegrationInfo jobInfo = new sfdc_checkout.IntegrationInfo();
        sfdc_checkout.IntegrationStatus integrationResult = apexSample.startCartProcessAsync(jobInfo, cart.Id);
        Test.stopTest();
        
        System.assertEquals(sfdc_checkout.IntegrationStatus.Status.SUCCESS, integrationResult.status, 
            'Integration should succeed when no new CDG is created.');
    }
    
    @isTest
    private static void testNewCDGCreated_ReturnsFailedStatus() {
        // SCENARIO: D2cController returns true (e.g. shipping to CA requires a split shipment).
        // The method should return FAILED to allow the platform to commit the new CDG.
        WebCart cart = createTestCart('CA', true, true); // CA is not a 2-day zone, so a split occurs.
        
        Test.startTest();
        ZenkraftExtensionReceiveShippingOptions apexSample = new ZenkraftExtensionReceiveShippingOptions();
        sfdc_checkout.IntegrationInfo jobInfo = new sfdc_checkout.IntegrationInfo();
        sfdc_checkout.IntegrationStatus integrationResult = apexSample.startCartProcessAsync(jobInfo, cart.Id);
        Test.stopTest();
        
        System.assertEquals(sfdc_checkout.IntegrationStatus.Status.FAILED, integrationResult.status,
            'Integration should return FAILED to commit the new CDG from the split shipment.');
    }
    
    @isTest
    private static void testExceptionInCDGCreation_ReturnsFailedStatus() {
        // SCENARIO: D2cController throws an exception (e.g. shipping fresh products to AK).
        // The catch block should create a CartValidationOutput and return FAILED.
        WebCart cart = createTestCart('AK', true, true); // Shipping fresh items to Alaska is not allowed.
        
        Test.startTest();
        // FIX: Removed the hyphen from the class name instantiation
        ZenkraftExtensionReceiveShippingOptions apexSample = new ZenkraftExtensionReceiveShippingOptions();
        sfdc_checkout.IntegrationInfo jobInfo = new sfdc_checkout.IntegrationInfo();
        sfdc_checkout.IntegrationStatus integrationResult = apexSample.startCartProcessAsync(jobInfo, cart.Id);
        Test.stopTest();

        System.assertEquals(sfdc_checkout.IntegrationStatus.Status.FAILED, integrationResult.status,
            'Integration should fail when the controller throws an exception.');
        List<CartValidationOutput> errors = [SELECT Id FROM CartValidationOutput WHERE CartId = :cart.Id];
        System.assertEquals(1, errors.size(), 'An error record should have been inserted.');
    }
    
    @isTest
    private static void testEmptyCDG_IsDeletedAfterRateCall() {
        // SCENARIO: After a successful rate call, an empty CDG (weight=0) should be deleted.
        WebCart cart = createTestCart('IL', true, true); // Setup for a non-split scenario.

        // Manually add a second, empty CDG to test the cleanup logic.
        CartDeliveryGroup emptyCdg = new CartDeliveryGroup(
            CartId=cart.Id, Name='Empty CDG', Total_Shipping_Weight_LBs__c = 0
        );
        insert emptyCdg;

        zkmulti.MultiCarrierCalloutMockImpl mcMockImpl = new zkmulti.MultiCarrierCalloutMockImpl('FedEx');
        mcMockImpl.setMockWebservice();
        
        Test.startTest();
        ZenkraftExtensionReceiveShippingOptions apexSample = new ZenkraftExtensionReceiveShippingOptions();
        sfdc_checkout.IntegrationInfo jobInfo = new sfdc_checkout.IntegrationInfo();
        apexSample.startCartProcessAsync(jobInfo, cart.Id);
        Test.stopTest();
        
        List<CartDeliveryGroup> remainingCdgs = [SELECT Id FROM CartDeliveryGroup WHERE CartId = :cart.Id];
        System.assertEquals(1, remainingCdgs.size(), 'The empty CartDeliveryGroup should have been deleted.');
    }

    @isTest
    private static void testAllEmptyCDGs_DeletesCartAfterRateCall() {
        // SCENARIO: After a rate call, all CDGs for a cart are empty. The entire cart should be deleted.
        WebCart cart = createTestCart('IL', false, false); // Create a bare cart with no items.

        // Ensure we have a clean slate by deleting the auto-created CDG.
        delete [SELECT Id FROM CartDeliveryGroup WHERE CartId = :cart.Id];

        // Manually add two empty CDGs to simulate the condition for deletion.
        List<CartDeliveryGroup> emptyCdgs = new List<CartDeliveryGroup>{
            new CartDeliveryGroup(CartId=cart.Id, Name='Empty CDG 1', Total_Shipping_Weight_LBs__c = 0),
            new CartDeliveryGroup(CartId=cart.Id, Name='Empty CDG 2', Total_Shipping_Weight_LBs__c = 0)
        };
        insert emptyCdgs;

        zkmulti.MultiCarrierCalloutMockImpl mcMockImpl = new zkmulti.MultiCarrierCalloutMockImpl('FedEx');
        mcMockImpl.setMockWebservice();
        
        Test.startTest();
        ZenkraftExtensionReceiveShippingOptions apexSample = new ZenkraftExtensionReceiveShippingOptions();
        sfdc_checkout.IntegrationInfo jobInfo = new sfdc_checkout.IntegrationInfo();
        apexSample.startCartProcessAsync(jobInfo, cart.Id);
        Test.stopTest();
        
        // Verify: The WebCart itself should have been deleted.
        List<WebCart> remainingCarts = [SELECT Id FROM WebCart WHERE Id = :cart.Id];
        System.assertEquals(0, remainingCarts.size(), 'The WebCart should have been deleted because all its CDGs were empty.');
    }
}