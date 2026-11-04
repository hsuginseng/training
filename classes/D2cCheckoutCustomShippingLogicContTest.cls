/**
 * @description Test class for the D2cCheckoutCustomShippingLogicController.
 * It provides full test coverage by simulating user actions that trigger platform
 * automation, ensuring a realistic test of the controller's logic.
 */
@IsTest
private class D2cCheckoutCustomShippingLogicContTest {

    /**
     * @description Sets up common test data. This method creates Products with the
     * necessary Shipping_Category__c and weight values that drive the automation
     * tested in this class.
     */
    @TestSetup
    static void makeData() {
        // A buyer account is required for creating a cart
        Account buyerAccount = new Account(Name = 'Test Buyer Account');
        insert buyerAccount;

        // A WebStore is the parent record for a WebCart
        WebStore store = new WebStore(
            Name = 'Test Store',
            DefaultLanguage = 'en_US',
            SupportedLanguages = 'en_US',
            Type = 'B2C'
        );
        insert store;

        // Get the standard price book ID. This is the correct and safe way to
        // access it within a test context, avoiding SOQL query errors.
        Id pricebookId = Test.getStandardPricebookId();

        // Create a "Standard" product. The Shipping_Category__c and weight fields
        // are what trigger the automation to correctly categorize and weigh the CartItem.
        Product2 standardProduct = new Product2(
            Name = 'Standard Product',
            IsActive = true,
            Shipping_Category__c = 'Standard', // This value drives automation
            Shipping_Weight_Oz__c = 48.0 // 3 lbs in ounces. This field drives weight automation.
        );
        insert standardProduct;
        PricebookEntry standardPbe = new PricebookEntry(
            Pricebook2Id = pricebookId,
            Product2Id = standardProduct.Id,
            UnitPrice = 10,
            IsActive = true
        );
        insert standardPbe;

        // Create a "Fresh" product.
        Product2 freshProduct = new Product2(
            Name = 'Fresh Product',
            IsActive = true,
            Shipping_Category__c = 'Fresh', // This value drives automation
            Shipping_Weight_Oz__c = 32.0 // 2 lbs in ounces. This field drives weight automation.
        );
        insert freshProduct;
        PricebookEntry freshPbe = new PricebookEntry(
            Pricebook2Id = pricebookId,
            Product2Id = freshProduct.Id,
            UnitPrice = 50,
            IsActive = true
        );
        insert freshPbe;
    }

    //--- removeFreshProductsFromCart Method Tests ---//

    /**
     * @description Verifies removeFreshProductsFromCart deletes the WebCart when
     * it only contains fresh products.
     */
    @IsTest
    static void testRemoveFreshProducts_DeletesCart() {
        // Setup: Create a cart shipping to IL (2-day zone) with only a fresh product.
        WebCart cart = createCartWithItems(true, false, 'IL', 'US');

        Test.startTest();
        // Action: Call the method to remove fresh products.
        Boolean wasCartDeleted = D2cCheckoutCustomShippingLogicController.removeFreshProductsFromCart(cart.Id);
        Test.stopTest();

        // Verify: The method returns true, indicating the cart was deleted.
        System.assertEquals(true, wasCartDeleted, 'The cart should have been deleted.');
        // Verify: The cart and item records are gone from the database.
        System.assertEquals(0, [SELECT COUNT() FROM WebCart WHERE Id = :cart.Id], 'WebCart record should be deleted.');
    }

    /**
     * @description Verifies removeFreshProductsFromCart does NOT delete the WebCart
     * when standard products remain.
     */
    @IsTest
    static void testRemoveFreshProducts_KeepsCart() {
        // Setup: Create a cart with both fresh and standard products.
        WebCart cart = createCartWithItems(true, true, 'WI', 'US');

        Test.startTest();
        // Action: Call the method to remove fresh products.
        Boolean wasCartDeleted = D2cCheckoutCustomShippingLogicController.removeFreshProductsFromCart(cart.Id);
        Test.stopTest();

        // Verify: The method returns false, indicating the cart was NOT deleted.
        System.assertEquals(false, wasCartDeleted, 'The cart should not have been deleted.');
        // Verify: The standard item remains, but the fresh item is gone.
        List<CartItem> itemsAfter = [SELECT Id FROM CartItem WHERE CartId = :cart.Id AND Shipping_Category__c = 0];
        System.assertEquals(1, itemsAfter.size(), 'The standard product CartItem should remain.');
    }

    /**
     * @description Verifies that the catch block in removeFreshProductsFromCart
     * correctly throws an AuraHandledException when an invalid Cart ID is provided,
     * causing a QueryException.
     */
    @IsTest
    static void testRemoveFreshProducts_ExceptionOnInvalidId() {
        // Setup: Create a fake ID that does not correspond to a real record.
        // The '0A3' prefix is for the WebCart object.
        Id invalidCartId = '0A3000000000000AAA';
        Boolean exceptionThrown = false;

        Test.startTest();
        try {
            // Action: Call the method with an invalid ID. This should cause a QueryException
            // inside the controller, which is then caught and re-thrown.
            D2cCheckoutCustomShippingLogicController.removeFreshProductsFromCart(invalidCartId);
        } catch (AuraHandledException e) {
            // If we catch the expected exception, we set the flag and confirm the message exists.
            exceptionThrown = true;
            System.assertNotEquals(null, e.getMessage(), 'The exception message should not be null.');
        } catch (Exception e) {
            // Fail if any other type of exception is caught.
            System.assert(false, 'An unexpected exception type was thrown: ' + e.getTypeName());
        }
        Test.stopTest();

        // Verify that the expected exception was indeed thrown.
        System.assertEquals(true, exceptionThrown, 'An AuraHandledException should have been thrown for an invalid ID.');
    }


    //--- createOrderDeliveryGroup Method Tests ---//

    /**
     * @description Verifies a new 'Fresh' CartDeliveryGroup is created when a cart
     * meets the split shipment criteria (e.g., shipping outside 2-day zone).
     */
    @IsTest
    static void testCreateCDG_SplitShipmentNewGroup() {
        // Setup: Create a cart shipping to CA (outside 2-day zone) with both product types.
        WebCart cart = createCartWithItems(true, true, 'CA', 'US');

        Test.startTest();
        // Action: Call the method that should split the shipment.
        Boolean result = D2cCheckoutCustomShippingLogicController.createOrderDeliveryGroup(cart.Id);
        Test.stopTest();

        // Verify: The method returns true, indicating a change was made.
        System.assertEquals(true, result, 'Method should return true as a new CDG was created.');
        // Verify: A second delivery group was created.
        System.assertEquals(2, [SELECT COUNT() FROM CartDeliveryGroup WHERE CartId = :cart.Id], 'There should now be two CartDeliveryGroups.');
        // Verify: The new group is named correctly.
        System.assertEquals(1, [SELECT COUNT() FROM CartDeliveryGroup WHERE CartId = :cart.Id AND Name = 'Fresh Ginseng Shipment'],
                             'A fresh shipment group should have been created.');
    }
    
    /**
     * @description Verifies shipments are combined when the destination is within
     * the 2-day shipping zone.
     */
    @IsTest
    static void testCreateCDG_CombineInTwoDayZone() {
        // Setup: Create a cart shipping to WI (in 2-day zone).
        WebCart cart = createCartWithItems(true, true, 'WI', 'US');
        
        // Get the address from the first delivery group to ensure consistency.
        CartDeliveryGroup originalCdg = [SELECT DeliverToStreet, 
                                            DeliverToCity, 
                                            DeliverToState, 
                                            DeliverToPostalCode, 
                                            DeliverToCountry 
                                        FROM CartDeliveryGroup 
                                        WHERE CartId = :cart.Id 
                                        LIMIT 1];

        // Manually create a second delivery group with the same address to simulate a pre-combined state.
        CartDeliveryGroup freshCdg = new CartDeliveryGroup(
            CartId = cart.Id, Name = 'Fresh Ginseng Shipment',
            DeliverToStreet = originalCdg.DeliverToStreet,
            DeliverToCity = originalCdg.DeliverToCity,
            DeliverToState = originalCdg.DeliverToState,
            DeliverToPostalCode = originalCdg.DeliverToPostalCode,
            DeliverToCountry = originalCdg.DeliverToCountry
        );
        insert freshCdg;

        // Get the fresh product Id to reliably query for the cart item, avoiding automation race conditions.
        Product2 freshProduct = [SELECT Id FROM Product2 WHERE Name = 'Fresh Product' LIMIT 1];
        CartItem freshItem = [SELECT Id FROM CartItem WHERE CartId = :cart.Id AND Product2Id = :freshProduct.Id LIMIT 1];
        
        // Associate the fresh item with the new delivery group to properly test the combine logic.
        freshItem.CartDeliveryGroupId = freshCdg.Id;
        update freshItem;

        Test.startTest();
        // Action: Call the method that should combine the shipments.
        Boolean result = D2cCheckoutCustomShippingLogicController.createOrderDeliveryGroup(cart.Id);
        Test.stopTest();

        // Verify: The method returns true because a CDG was deleted.
        System.assertEquals(true, result, 'Method should return true as CDGs were combined.');
        // Verify: Only one delivery group remains.
        System.assertEquals(1, [SELECT COUNT() FROM CartDeliveryGroup WHERE CartId = :cart.Id], 'There should only be one CDG after combining.');
    }

    /**
     * @description Verifies that a fresh product item is correctly moved to an
     * existing 'Fresh Ginseng Shipment' group if it was incorrectly assigned.
     */
    @IsTest
    static void testCreateCDG_UpdateExistingFreshGroup() {
        // Setup: Create a cart that qualifies for split shipment.
        WebCart cart = createCartWithItems(true, true, 'CA', 'US');
        CartDeliveryGroup standardCdg = [SELECT Id FROM CartDeliveryGroup WHERE CartId = :cart.Id LIMIT 1];

        // Manually create the 'Fresh' group beforehand.
        CartDeliveryGroup freshCdg = new CartDeliveryGroup(
            CartId = cart.Id, Name = 'Fresh Ginseng Shipment', DeliverToStreet = '123 Main St',
            DeliverToCity = 'Anytown', DeliverToState = 'CA', DeliverToPostalCode = '12345',
            DeliverToCountry = 'US'
        );
        insert freshCdg;
        
        // All items start in the standard group, including the fresh item,
        // which is the incorrect state we want the controller to fix.
        
        Test.startTest();
        Boolean result = D2cCheckoutCustomShippingLogicController.createOrderDeliveryGroup(cart.Id);
        Test.stopTest();

        // Verify: The method returns true because it moved the fresh item.
        System.assertEquals(true, result, 'Method should return true as it updated the cart item.');
        
        // Verify: The fresh item is now in the correct delivery group.
        CartItem freshItem = [SELECT CartDeliveryGroupId FROM CartItem WHERE CartId = :cart.Id AND Shipping_Category__c = 1 LIMIT 1];
        System.assertEquals(freshCdg.Id, freshItem.CartDeliveryGroupId, 'Fresh cart item should be moved to the fresh delivery group.');
    }

    /**
     * @description Verifies that the method returns false when Is_OOBO_Cart__c = true on the WebCart
     */
    @IsTest
    static void testCreateCDG_IsOOBOCartReturnFalse() {
        // Setup: Create a cart with fresh items shipping to Alaska (AK).
        WebCart cart = createCartWithItems(false, true, 'WI', 'US');
        cart.Is_OOBO_Cart__c = true;
        update cart;

        Test.startTest();
            // Action: Call the method that should return false
            Boolean result = D2cCheckoutCustomShippingLogicController.createOrderDeliveryGroup(cart.Id);
        Test.stopTest();

        // Verify: The correct exception was thrown.
        System.assertEquals(false, result, 'Method should return false as the cart originated from an OOBO process.');
    }

    /**
     * @description Verifies that the matchCartDeliveryGroupDeliveryAddresses logic
     * correctly syncs addresses based on the controller's `ORDER BY Name DESC` sort.
     * This test asserts every line of the address for accuracy.
     */
    @IsTest
    static void testMatchCartDeliveryGroupAddresses() {
        // Setup: Create a WebCart using the account and store from TestSetup.
        Account buyerAccount = [SELECT Id FROM Account WHERE Name = 'Test Buyer Account' LIMIT 1];
        WebStore store = [SELECT Id FROM WebStore LIMIT 1];
        WebCart cart = new WebCart(
            WebStoreId = store.Id,
            AccountId = buyerAccount.Id,
            Name = 'Test Cart for Address Match',
            Status = 'Active',
            // Initialize weight fields to prevent NullPointerException in the controller.
            Fresh_Ginseng_Weight__c = 0,
            Total_Shipping_Weight_LBs__c = 0
        );
        insert cart;

        // Create a 'Standard Shipment' group. Due to the DESC sort in the controller,
        // this will be the first group in the list and its address will be primary.
        CartDeliveryGroup standardCdg = new CartDeliveryGroup(
            CartId = cart.Id, Name = 'Standard Shipment', DeliverToStreet = '123 Main St',
            DeliverToCity = 'Chicago', DeliverToState = 'IL', DeliverToPostalCode = '60601',
            DeliverToCountry = 'US'
        );
        insert standardCdg;

        // Create a 'Fresh Ginseng Shipment' group with a completely different address.
        // This will be the second group in the list and its address should be updated.
        CartDeliveryGroup freshCdg = new CartDeliveryGroup(
            CartId = cart.Id, Name = 'Fresh Ginseng Shipment', DeliverToStreet = '999 Different Ave',
            DeliverToCity = 'Madison', DeliverToState = 'WI', DeliverToPostalCode = '53703',
            DeliverToCountry = 'CA'
        );
        insert freshCdg;
        
        Test.startTest();
        // Action: Call the main method. This internally calls the address matching logic.
        D2cCheckoutCustomShippingLogicController.createOrderDeliveryGroup(cart.Id);
        Test.stopTest();

        // Verify: The 'Fresh Ginseng Shipment' group's address should now match the 'Standard' group's address.
        CartDeliveryGroup updatedFreshCdg = [SELECT DeliverToStreet, 
                                                DeliverToCity, 
                                                DeliverToState, 
                                                DeliverToPostalCode, 
                                                DeliverToCountry 
                                            FROM CartDeliveryGroup 
                                            WHERE Id = :freshCdg.Id];
        
        System.assertEquals(standardCdg.DeliverToStreet, updatedFreshCdg.DeliverToStreet, 'The street on the Fresh CDG should have been updated.');
        System.assertEquals(standardCdg.DeliverToCity, updatedFreshCdg.DeliverToCity, 'The city on the Fresh CDG should have been updated.');
        System.assertEquals(standardCdg.DeliverToState, updatedFreshCdg.DeliverToState, 'The state on the Fresh CDG should have been updated.');
        System.assertEquals(standardCdg.DeliverToPostalCode, updatedFreshCdg.DeliverToPostalCode, 'The postal code on the Fresh CDG should have been updated.');
        System.assertEquals(standardCdg.DeliverToCountry, updatedFreshCdg.DeliverToCountry, 'The country on the Fresh CDG should have been updated.');
    }

    /**
     * @description Verifies a HandledException is thrown when shipping fresh
     * products outside the lower 48 states.
     */
    @IsTest
    static void testCreateCDG_ExceptionNotInLower48() {
        // Setup: Create a cart with fresh items shipping to Alaska (AK).
        WebCart cart = createCartWithItems(true, false, 'AK', 'US');
        String expectedExceptionMessage = 'Fresh ginseng cannot be shipped to your location.';
        String actualExceptionMessage;

        Test.startTest();
        try {
            // Action: Call the method that should throw an exception.
            D2cCheckoutCustomShippingLogicController.createOrderDeliveryGroup(cart.Id);
        } catch (HandledException e) {
            actualExceptionMessage = e.getMessage();
        }
        Test.stopTest();

        // Verify: The correct exception was thrown.
        System.assertEquals(expectedExceptionMessage, actualExceptionMessage, 'A HandledException should have been thrown for shipping outside lower 48.');
    }    
    
    /**
     * @description Verifies no changes are made when the cart does not meet any
     * criteria for special shipping logic.
     */
    @IsTest
    static void testCreateCDG_NoChange() {
        // Setup: A cart with only standard products requires no special logic.
        WebCart cart = createCartWithItems(false, true, 'CA', 'US');
        
        Test.startTest();
        // Action: Call the method.
        Boolean result = D2cCheckoutCustomShippingLogicController.createOrderDeliveryGroup(cart.Id);
        Test.stopTest();
        
        // Verify: The method returns false as no changes were made.
        System.assertEquals(false, result, 'Method should return false as no changes were needed.');
        // Verify: The delivery group count is unchanged.
        System.assertEquals(1, [SELECT COUNT() FROM CartDeliveryGroup WHERE CartId = :cart.Id], 'Should still be one CartDeliveryGroup.');
    }

    /**
     * @description Reusable helper method to create a WebCart with items and a shipping address.
     * @param createFresh If true, adds a fresh product to the cart.
     * @param createStandard If true, adds a standard product to the cart.
     * @param shippingState The two-letter state code for the shipping address.
     * @param shippingCountry The two-letter country code for the shipping address.
     * @return The newly created WebCart record for use in a test method.
     */
    private static WebCart createCartWithItems(Boolean createFresh, Boolean createStandard, String shippingState, String shippingCountry) {
        WebStore store = [SELECT Id FROM WebStore LIMIT 1];
        Account buyerAccount = [SELECT Id FROM Account WHERE Name = 'Test Buyer Account' LIMIT 1];
        Product2 standardProduct = [SELECT Id, Name FROM Product2 WHERE Name = 'Standard Product' LIMIT 1];
        Product2 freshProduct = [SELECT Id, Name FROM Product2 WHERE Name = 'Fresh Product' LIMIT 1];

        WebCart cart = new WebCart(
            WebStoreId = store.Id,
            AccountId = buyerAccount.Id,
            Name = 'Test Cart',
            Status = 'Active'
        );
        insert cart;

        CartDeliveryGroup cdg = new CartDeliveryGroup(
            CartId = cart.Id, Name = 'Standard Shipment', DeliverToStreet = '123 Main St',
            DeliverToCity = 'Anytown', DeliverToState = shippingState, DeliverToPostalCode = '12345',
            DeliverToCountry = shippingCountry
        );
        insert cdg;

        List<CartItem> itemsToInsert = new List<CartItem>();
        if (createStandard) {
            itemsToInsert.add(new CartItem(
                Name = standardProduct.Name, 
                CartId = cart.Id,
                CartDeliveryGroupId = cdg.Id,
                Product2Id = standardProduct.Id,
                Quantity = 1,
                Type = 'Product'
            ));
        }
        if (createFresh) {
            itemsToInsert.add(new CartItem(
                Name = freshProduct.Name, 
                CartId = cart.Id,
                CartDeliveryGroupId = cdg.Id,
                Product2Id = freshProduct.Id,
                Quantity = 1,
                Type = 'Product'
            ));
        }
        if(!itemsToInsert.isEmpty()){
            insert itemsToInsert;
        }

        return [SELECT Id FROM WebCart WHERE Id = :cart.Id];
    }
}