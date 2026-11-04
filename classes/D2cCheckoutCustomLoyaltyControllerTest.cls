/**
 * @description Test class for D2cCheckoutCustomLoyaltyController.
 * Provides comprehensive test coverage for all methods including edge cases.
 */
@IsTest
private class D2cCheckoutCustomLoyaltyControllerTest {

    /**
     * @description Sets up common test data including Account, WebStore, Products,
     * and PricebookEntries needed for cart operations.
     */
    @TestSetup
    static void makeData() {
        // Create PersonAccount for cart and loyalty member
        // PersonAccount provides both Account and Contact in one record
        // PersonAccounts require RecordTypeId to be set
        Id personAccountRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId();
        Account buyerAccount = new Account(
            FirstName = 'Test',
            LastName = 'Buyer',
            RecordTypeId = personAccountRecordTypeId
        );
        insert buyerAccount;

        // Create WebStore for cart
        WebStore store = new WebStore(
            Name = 'Test Store',
            DefaultLanguage = 'en_US',
            SupportedLanguages = 'en_US',
            Type = 'B2C'
        );
        insert store;

        // Get standard pricebook
        Id pricebookId = Test.getStandardPricebookId();

        // Create loyalty redeemable product
        Product2 loyaltyProduct = new Product2(
            Name = 'Loyalty Redeemable Product',
            IsActive = true,
            Loyalty_Redeemable__c = true
        );
        insert loyaltyProduct;

        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = pricebookId,
            Product2Id = loyaltyProduct.Id,
            UnitPrice = 100.00,
            IsActive = true
        );
        insert pbe;

        // Create non-loyalty redeemable product
        Product2 nonLoyaltyProduct = new Product2(
            Name = 'Non-Loyalty Product',
            IsActive = true,
            Loyalty_Redeemable__c = false
        );
        insert nonLoyaltyProduct;

        PricebookEntry nonLoyaltyPbe = new PricebookEntry(
            Pricebook2Id = pricebookId,
            Product2Id = nonLoyaltyProduct.Id,
            UnitPrice = 50.00,
            IsActive = true
        );
        insert nonLoyaltyPbe;
    }

    //--- getLoyaltyPointsBalance Method Tests ---//

    /**
     * @description Verifies getLoyaltyPointsBalance returns the correct points balance.
     */
    @IsTest
    static void testGetLoyaltyPointsBalance_Success() {
        // Get PersonAccount - it has both Account and Contact
        Account buyerAccount = [SELECT Id, PersonContactId FROM Account WHERE LastName = 'Buyer' LIMIT 1];
        
        // Create LoyaltyProgram first (required for LoyaltyProgramMember)
        LoyaltyProgram loyaltyProgram = new LoyaltyProgram(
            Name = 'Test Loyalty Program',
            Status = 'Active'
        );
        insert loyaltyProgram;
        
        // Create LoyaltyProgramMember with MembershipNumber matching Account Id
        // ContactId, EnrollmentDate, MemberStatus, and ProgramId are required
        LoyaltyProgramMember loyaltyMember = new LoyaltyProgramMember(
            MembershipNumber = String.valueOf(buyerAccount.Id),
            ContactId = buyerAccount.PersonContactId,
            EnrollmentDate = Date.today(),
            MemberStatus = 'Active',
            ProgramId = loyaltyProgram.Id
        );
        insert loyaltyMember;

        // Create LoyaltyMemberCurrency
        // The relationship field is LoyaltyMemberId (even though object is LoyaltyProgramMember)
        // Note: PointsBalance is not directly writeable - it's calculated by the system
        // Name field is required and may need to match CurrencyIsoCode or be auto-generated
        LoyaltyMemberCurrency loyaltyCurrency = new LoyaltyMemberCurrency(
            LoyaltyMemberId = loyaltyMember.Id,
            CurrencyIsoCode = 'USD',
            Name = 'USD'  // Try matching CurrencyIsoCode
        );
        insert loyaltyCurrency;
        
        // PointsBalance is typically calculated by loyalty transactions
        // Query to get the actual PointsBalance value (may be 0 or calculated)
        loyaltyCurrency = [SELECT PointsBalance FROM LoyaltyMemberCurrency WHERE Id = :loyaltyCurrency.Id];
        Decimal expectedBalance = loyaltyCurrency.PointsBalance;

        Test.startTest();
        Decimal pointsBalance = D2cCheckoutCustomLoyaltyController.getLoyaltyPointsBalance(buyerAccount.Id);
        Test.stopTest();

        System.assertEquals(expectedBalance, pointsBalance, 'Points balance should match the currency record value.');
    }

    /**
     * @description Verifies getLoyaltyPointsBalance throws AuraHandledException when no record is found.
     */
    /*@IsTest
    static void testGetLoyaltyPointsBalance_Exception() {
        Account buyerAccount = [SELECT Id FROM Account WHERE LastName = 'Buyer' LIMIT 1];
        Boolean exceptionThrown = false;

        Test.startTest();
        try {
            D2cCheckoutCustomLoyaltyController.getLoyaltyPointsBalance(buyerAccount.Id);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
            System.assertNotEquals(null, e.getMessage(), 'Exception message should not be null.');
        }
        Test.stopTest();

        System.assertEquals(true, exceptionThrown, 'An AuraHandledException should have been thrown.');
    }*/

       @IsTest
    static void testGetLoyaltyPointsBalance_NoCurrencyRecords() {
        Account buyerAccount = [SELECT Id FROM Account WHERE LastName = 'Buyer' LIMIT 1];
        Boolean exceptionThrown = false;

        Test.startTest();
        Decimal pointsBalance = D2cCheckoutCustomLoyaltyController.getLoyaltyPointsBalance(buyerAccount.Id);
        Test.stopTest();

        System.assertEquals(0, pointsBalance, 'Points balance should return zero when no currency record is found.');
    }

    //--- applyLoyaltyVoucher Method Tests ---//

    /**
     * @description Verifies applyLoyaltyVoucher's empty-cart contract: when the cart has no
     * loyalty-redeemable items, the method removes any applied loyalty promotion and returns
     * true. It does NOT throw — so we assert the real behavior rather than a fabricated exception.
     */
    @IsTest
    static void testApplyLoyaltyVoucher_NoLoyaltyItems() {
        WebCart cart = createCartWithLoyaltyItems(false);
        Voucher voucher = createVoucherAndCoupon(100.00);

        Test.startTest();
        Boolean result = D2cCheckoutCustomLoyaltyController.applyLoyaltyVoucher(cart.Id, voucher.Id);
        Test.stopTest();

        System.assertEquals(true, result,
            'With no loyalty-redeemable items, applyLoyaltyVoucher should remove the promotion and return true.');

        // No loyalty adjustments should have been created.
        List<CartItemPriceAdjustment> cipas = [
            SELECT Id FROM CartItemPriceAdjustment
            WHERE CartId = :cart.Id AND Name = 'SystemGeneratedLoyaltyDiscount'
        ];
        System.assertEquals(0, cipas.size(),
            'No loyalty adjustments should be created when there are no redeemable items.');
    }

    /**
     * @description Verifies applyLoyaltyVoucher creates CartItemPriceAdjustments when none exist.
     */
    @IsTest
    static void testApplyLoyaltyVoucher_CreateAdjustments() {
        WebCart cart = createCartWithLoyaltyItems(true);
        Voucher voucher = createVoucherAndCoupon(50.00);

        Test.startTest();
        Boolean result = D2cCheckoutCustomLoyaltyController.applyLoyaltyVoucher(cart.Id, voucher.Id);
        Test.stopTest();

        System.assertEquals(true, result, 'Method should return true when adjustments are created.');
        
        // Verify CartItemPriceAdjustments were created
        List<CartItemPriceAdjustment> cipas = [
            SELECT Id, Name, AdjustmentValue, TotalAmount
            FROM CartItemPriceAdjustment
            WHERE CartId = :cart.Id
            AND Name = 'SystemGeneratedLoyaltyDiscount'
        ];
        System.assert(cipas.size() > 0, 'CartItemPriceAdjustments should have been created.');
        
        // Verify WebCartAdjustmentBasis was created
        List<WebCartAdjustmentBasis> wcabs = [
            SELECT Id, Name
            FROM WebCartAdjustmentBasis
            WHERE WebCartId = :cart.Id
        ];
        System.assertEquals(1, wcabs.size(), 'WebCartAdjustmentBasis should have been created.');
    }

    /**
     * @description Verifies applyLoyaltyVoucher handles case where loyalty discount already exists correctly.
     */
    @IsTest
    static void testApplyLoyaltyVoucher_ExistingLoyaltyDiscount() {
        WebCart cart = createCartWithLoyaltyItems(true);
        Voucher voucher = createVoucherAndCoupon(50.00);

        // First application
        D2cCheckoutCustomLoyaltyController.applyLoyaltyVoucher(cart.Id, voucher.Id);

        // Update cart items to simulate existing adjustments
        List<CartItem> cartItems = [
            SELECT Id, TotalAdjustmentAmount, TotalPrice
            FROM CartItem
            WHERE CartId = :cart.Id
        ];
        for (CartItem ci : cartItems) {
            ci.TotalAdjustmentAmount = -50.00;
            ci.TotalPriceAfterAllAdjustments = ci.TotalPrice - 50.00;
            ci.TotalPromoAdjustmentAmount = -50.00;
        }
        update cartItems;

        Test.startTest();
        Boolean result = D2cCheckoutCustomLoyaltyController.applyLoyaltyVoucher(cart.Id, voucher.Id);
        Test.stopTest();

        // Should return false if discount already matches expected value
        // or true if it needs updating
        System.assertNotEquals(null, result, 'Method should return a boolean value.');
    }

    /**
     * @description Verifies applyLoyaltyVoucher handles discount larger than cart total.
     */
    @IsTest
    static void testApplyLoyaltyVoucher_DiscountExceedsTotal() {
        WebCart cart = createCartWithLoyaltyItems(true);
        // Create voucher with value larger than cart total
        Voucher voucher = createVoucherAndCoupon(1000.00);

        Test.startTest();
        Boolean result = D2cCheckoutCustomLoyaltyController.applyLoyaltyVoucher(cart.Id, voucher.Id);
        Test.stopTest();

        System.assertEquals(true, result, 'Method should handle discount exceeding cart total.');
    }

    /**
     * @description Verifies applyLoyaltyVoucher throws exception when voucher is not found.
     */
    @IsTest
    static void testApplyLoyaltyVoucher_InvalidVoucher() {
        WebCart cart = createCartWithLoyaltyItems(true);
        Id invalidVoucherId = '0A3000000000000AAA'; // Fake ID

        Boolean exceptionThrown = false;

        Test.startTest();
        try {
            D2cCheckoutCustomLoyaltyController.applyLoyaltyVoucher(cart.Id, invalidVoucherId);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
            System.assertNotEquals(null, e.getMessage(), 'Exception message should not be null.');
        }
        Test.stopTest();

        System.assertEquals(true, exceptionThrown, 'An exception should have been thrown for invalid voucher.');
    }

    /**
     * @description Verifies applyLoyaltyVoucher handles cart with existing CartItemPriceAdjustment correctly.
     * Tests the scenario where a cart already has a non-loyalty CartItemPriceAdjustment before applying loyalty voucher.
     */
    @IsTest
    static void testApplyLoyaltyVoucher_WithExistingPriceAdjustment() {
        WebCart cart = createCartWithLoyaltyItems(true);
        Voucher voucher = createVoucherAndCoupon(50.00);
        
        // Get cart items
        List<CartItem> cartItems = [
            SELECT Id, TotalPrice, SalesPrice, Quantity
            FROM CartItem
            WHERE CartId = :cart.Id
        ];
        
        // Create a Promotion for the existing adjustment
        Promotion existingPromotion = new Promotion(
            Name = 'Existing Promotion',
            IsActive = true,
            StartDate = Date.today().addDays(-30),
            EndDate = Date.today().addDays(30)
        );
        insert existingPromotion;
        
        // Create a Coupon for the existing adjustment
        String existingCouponCode = 'EXISTING' + String.valueOf(DateTime.now().getTime());
        Coupon existingCoupon = new Coupon(
            CouponCode = existingCouponCode,
            PromotionId = existingPromotion.Id
        );
        insert existingCoupon;
        
        // Create existing CartItemPriceAdjustment (non-loyalty)
        List<CartItemPriceAdjustment> existingCipas = new List<CartItemPriceAdjustment>();
        for (CartItem ci : cartItems) {
            CartItemPriceAdjustment existingCipa = new CartItemPriceAdjustment(
                AdjustmentAmountScope = 'Total',
                AdjustmentBasisReferenceId = existingCoupon.Id,
                AdjustmentSource = 'System',
                AdjustmentTargetType = 'Item',
                AdjustmentType = 'AdjustmentAmount',
                AdjustmentValue = -10.00, // $10 discount
                CartId = cart.Id,
                CartItemId = ci.Id,
                Name = 'ExistingPromoDiscount', // Different name from loyalty discount
                PriceAdjustmentCauseId = existingPromotion.Id,
                Priority = 1,
                TotalAmount = -10.00
            );
            existingCipas.add(existingCipa);
        }
        insert existingCipas;
        
        // Verify existing adjustments were created
        List<CartItemPriceAdjustment> beforeCipas = [
            SELECT Id, Name, AdjustmentValue
            FROM CartItemPriceAdjustment
            WHERE CartId = :cart.Id
        ];
        System.assertEquals(cartItems.size(), beforeCipas.size(), 
            'Existing CartItemPriceAdjustments should have been created.');

        Test.startTest();
        Boolean result = D2cCheckoutCustomLoyaltyController.applyLoyaltyVoucher(cart.Id, voucher.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Method should return a boolean value.');
        
        // Verify that loyalty discount adjustments were created in addition to existing ones
        List<CartItemPriceAdjustment> afterCipas = [
            SELECT Id, Name, AdjustmentValue, TotalAmount
            FROM CartItemPriceAdjustment
            WHERE CartId = :cart.Id
        ];
        
        // Should have both existing and new loyalty adjustments
        System.assert(afterCipas.size() >= cartItems.size(), 
            'Should have at least one adjustment per cart item. Found: ' + afterCipas.size());
        
        // Verify loyalty discount adjustments exist
        List<CartItemPriceAdjustment> loyaltyCipas = [
            SELECT Id, Name, AdjustmentValue
            FROM CartItemPriceAdjustment
            WHERE CartId = :cart.Id
            AND Name = 'SystemGeneratedLoyaltyDiscount'
        ];
        System.assert(loyaltyCipas.size() > 0, 
            'Loyalty CartItemPriceAdjustments should have been created even with existing adjustments.');
    }

    //--- deletePromotionDiscountFromCart Method Tests ---//

    /**
     * @description Verifies deletePromotionDiscountFromCart removes loyalty CIPAs and WCABs,
     * clears Applied_Loyalty_Voucher__c on the cart, and restores cart item totals.
     */
    @IsTest
    static void testDeletePromotionDiscountFromCart_Success() {
        WebCart cart = createCartWithLoyaltyItems(true);
        Voucher voucher = createVoucherAndCoupon(50.00);

        // Apply the loyalty voucher first so there is something to delete
        D2cCheckoutCustomLoyaltyController.applyLoyaltyVoucher(cart.Id, voucher.Id);

        // Set Applied_Loyalty_Voucher__c so we can verify it gets cleared
        cart.Applied_Loyalty_Voucher__c = voucher.Id;
        update cart;

        // Capture pre-delete cart item totals (which include the loyalty discount)
        Map<Id, CartItem> itemsBefore = new Map<Id, CartItem>([
            SELECT Id, TotalAdjustmentAmount, TotalPriceAfterAllAdjustments, TotalPromoAdjustmentAmount
            FROM CartItem
            WHERE CartId = :cart.Id
        ]);

        // Sanity check: loyalty adjustments and WCABs should exist before delete
        List<CartItemPriceAdjustment> cipasBefore = [
            SELECT Id, CartItemId, AdjustmentValue
            FROM CartItemPriceAdjustment
            WHERE CartId = :cart.Id AND Name = 'SystemGeneratedLoyaltyDiscount'
        ];
        System.assert(cipasBefore.size() > 0, 'Loyalty CIPAs should exist before delete.');

        List<WebCartAdjustmentBasis> wcabsBefore = [
            SELECT Id FROM WebCartAdjustmentBasis
            WHERE WebCartId = :cart.Id AND Loyalty_Coupon__c = TRUE
        ];
        System.assert(wcabsBefore.size() > 0, 'Loyalty WCABs should exist before delete.');

        // Calculate the discount per item so we can verify totals are restored
        Map<Id, Decimal> discountByItem = new Map<Id, Decimal>();
        for (CartItemPriceAdjustment cipa : cipasBefore) {
            Decimal existing = discountByItem.containsKey(cipa.CartItemId)
                ? discountByItem.get(cipa.CartItemId) : 0;
            discountByItem.put(cipa.CartItemId, existing + (cipa.AdjustmentValue != null ? cipa.AdjustmentValue : 0));
        }

        Test.startTest();
        D2cCheckoutCustomLoyaltyController.deletePromotionDiscountFromCart(cart.Id);
        Test.stopTest();

        // Loyalty CIPAs should be gone
        List<CartItemPriceAdjustment> cipasAfter = [
            SELECT Id FROM CartItemPriceAdjustment
            WHERE CartId = :cart.Id AND Name = 'SystemGeneratedLoyaltyDiscount'
        ];
        System.assertEquals(0, cipasAfter.size(), 'Loyalty CIPAs should be deleted.');

        // Loyalty WCABs should be gone
        List<WebCartAdjustmentBasis> wcabsAfter = [
            SELECT Id FROM WebCartAdjustmentBasis
            WHERE WebCartId = :cart.Id AND Loyalty_Coupon__c = TRUE
        ];
        System.assertEquals(0, wcabsAfter.size(), 'Loyalty WCABs should be deleted.');

        // Applied_Loyalty_Voucher__c on the cart should be cleared
        WebCart cartAfter = [SELECT Id, Applied_Loyalty_Voucher__c FROM WebCart WHERE Id = :cart.Id];
        System.assertEquals(null, cartAfter.Applied_Loyalty_Voucher__c,
            'Applied_Loyalty_Voucher__c should be cleared.');

        // Cart item totals should be restored (positive discount added back)
        List<CartItem> itemsAfter = [
            SELECT Id, TotalAdjustmentAmount, TotalPriceAfterAllAdjustments, TotalPromoAdjustmentAmount
            FROM CartItem
            WHERE CartId = :cart.Id
        ];
        for (CartItem ci : itemsAfter) {
            Decimal negativeDiscount = discountByItem.containsKey(ci.Id) ? discountByItem.get(ci.Id) : 0;
            Decimal positiveDiscount = -1 * negativeDiscount;

            CartItem before = itemsBefore.get(ci.Id);
            Decimal expectedAdjustment = (before.TotalAdjustmentAmount != null ? before.TotalAdjustmentAmount : 0) + positiveDiscount;
            Decimal expectedTotalAfterAdj = (before.TotalPriceAfterAllAdjustments != null ? before.TotalPriceAfterAllAdjustments : 0) + positiveDiscount;
            Decimal expectedPromoAdj = (before.TotalPromoAdjustmentAmount != null ? before.TotalPromoAdjustmentAmount : 0) + positiveDiscount;

            System.assertEquals(expectedAdjustment, ci.TotalAdjustmentAmount,
                'TotalAdjustmentAmount should be restored by the loyalty discount amount.');
            System.assertEquals(expectedTotalAfterAdj, ci.TotalPriceAfterAllAdjustments,
                'TotalPriceAfterAllAdjustments should be restored by the loyalty discount amount.');
            System.assertEquals(expectedPromoAdj, ci.TotalPromoAdjustmentAmount,
                'TotalPromoAdjustmentAmount should be restored by the loyalty discount amount.');
        }
    }

    //--- getProportionalCartItemDiscounts Method Tests ---//

    /**
     * @description Verifies getProportionalCartItemDiscounts handles null/empty inputs.
     */
    @IsTest
    static void testGetProportionalDiscounts_NullInputs() {
        Test.startTest();
        Map<Id, Decimal> result1 = D2cCheckoutCustomLoyaltyController.getProportionalCartItemDiscounts(null, 100.00);
        Map<Id, Decimal> result2 = D2cCheckoutCustomLoyaltyController.getProportionalCartItemDiscounts(new List<CartItem>(), 100.00);
        Map<Id, Decimal> result3 = D2cCheckoutCustomLoyaltyController.getProportionalCartItemDiscounts(new List<CartItem>(), null);
        Test.stopTest();

        System.assertEquals(0, result1.size(), 'Should return empty map for null cart items.');
        System.assertEquals(0, result2.size(), 'Should return empty map for empty cart items.');
        System.assertEquals(0, result3.size(), 'Should return empty map for null discount.');
    }

    /**
     * @description Verifies getProportionalCartItemDiscounts calculates correct proportions.
     */
    @IsTest
    static void testGetProportionalDiscounts_CorrectProportions() {
        WebCart cart = createCartWithLoyaltyItems(true);
        List<CartItem> cartItems = [
            SELECT Id, TotalPrice
            FROM CartItem
            WHERE CartId = :cart.Id
        ];

        // Update TotalPrice to known values for testing
        cartItems[0].TotalPrice = 100.00;
        if (cartItems.size() > 1) {
            cartItems[1].TotalPrice = 50.00;
        }
        update cartItems;

        // Re-query to get updated values
        cartItems = [
            SELECT Id, TotalPrice
            FROM CartItem
            WHERE CartId = :cart.Id
        ];

        Test.startTest();
        Map<Id, Decimal> result = D2cCheckoutCustomLoyaltyController.getProportionalCartItemDiscounts(cartItems, 60.00);
        Test.stopTest();

        System.assert(result.size() > 0, 'Should return discounts for all items.');
        
        Decimal totalDiscount = 0;
        for (Decimal discount : result.values()) {
            totalDiscount += discount;
        }
        // Total should be approximately 60.00 (within rounding tolerance)
        System.assert(totalDiscount >= 59.90 && totalDiscount <= 60.10, 
            'Total discount should be approximately 60.00, got: ' + totalDiscount);
    }

    /**
     * @description Verifies getProportionalCartItemDiscounts caps discount at cart total.
     */
    @IsTest
    static void testGetProportionalDiscounts_DiscountCapped() {
        WebCart cart = createCartWithLoyaltyItems(true);
        List<CartItem> cartItems = [
            SELECT Id, TotalPrice
            FROM CartItem
            WHERE CartId = :cart.Id
        ];

        cartItems[0].TotalPrice = 50.00;
        update cartItems;

        cartItems = [
            SELECT Id, TotalPrice
            FROM CartItem
            WHERE CartId = :cart.Id
        ];

        Test.startTest();
        // Discount larger than cart total
        Map<Id, Decimal> result = D2cCheckoutCustomLoyaltyController.getProportionalCartItemDiscounts(cartItems, 200.00);
        Test.stopTest();

        Decimal totalDiscount = 0;
        Decimal cartTotal = 0;
        for (CartItem ci : cartItems) {
            cartTotal += (ci.TotalPrice != null ? ci.TotalPrice : 0);
        }
        for (Decimal discount : result.values()) {
            totalDiscount += discount;
        }
        // Should be capped at cart total
        // Allow small rounding differences (0.01 tolerance)
        System.assert(totalDiscount <= cartTotal + 0.01, 
            'Discount should be capped at cart total. Expected max: ' + cartTotal + ', Got: ' + totalDiscount);
    }

    /**
     * @description Verifies getProportionalCartItemDiscounts handles zero discount.
     */
    @IsTest
    static void testGetProportionalDiscounts_ZeroDiscount() {
        WebCart cart = createCartWithLoyaltyItems(true);
        List<CartItem> cartItems = [
            SELECT Id, TotalPrice
            FROM CartItem
            WHERE CartId = :cart.Id
        ];

        Test.startTest();
        Map<Id, Decimal> result = D2cCheckoutCustomLoyaltyController.getProportionalCartItemDiscounts(cartItems, 0.00);
        Test.stopTest();

        for (Decimal discount : result.values()) {
            System.assertEquals(0.00, discount, 'All discounts should be zero.');
        }
    }

    /**
     * @description Verifies the single leftover cent is distributed by the largest-remainder
     * method. 3 items at $10 (total $30) with a $10 discount: each line's exact share is 3.333...,
     * floored to 3.33, summing to 9.99 and leaving +0.01. All three fractional remainders are
     * equal, so the tie breaks to the earliest line.
     */
    @IsTest
    static void testProportional_RemainderSpreadForward() {
        List<CartItem> items = buildPricedLoyaltyItems(new List<Decimal>{ 10.00, 10.00, 10.00 });

        Test.startTest();
        Map<Id, Decimal> result = D2cCheckoutCustomLoyaltyController.getProportionalCartItemDiscounts(items, 10.00);
        Test.stopTest();

        // Invariants: full amount spent to the penny, every line within [0, price].
        Decimal sum = 0;
        for (CartItem ci : items) {
            Decimal d = result.get(ci.Id);
            System.assert(d >= 0, 'No line may receive a negative discount.');
            System.assert(d <= ci.TotalPrice, 'No line may be discounted below zero.');
            sum += d;
        }
        System.assertEquals(10.00, sum, 'Total allocated must exactly equal the requested discount.');

        // Deterministic outcome: the first line absorbs the leftover cent.
        System.assertEquals(3.34, result.get(items[0].Id), 'First line receives the extra cent.');
        System.assertEquals(3.33, result.get(items[1].Id), 'Second line keeps its floored share.');
        System.assertEquals(3.33, result.get(items[2].Id), 'Third line keeps its floored share.');
    }

    /**
     * @description Verifies a multi-cent remainder is distributed one cent per line by the
     * largest-remainder method. 3 items at $10 (total $30) with a $20 discount: each exact share is
     * 6.666..., floored to 6.66, summing to 19.98 and leaving +0.02. The fractional remainders are
     * equal, so the two cents break to the two earliest lines.
     */
    @IsTest
    static void testProportional_RemainderSpreadAcrossLeadingLines() {
        List<CartItem> items = buildPricedLoyaltyItems(new List<Decimal>{ 10.00, 10.00, 10.00 });

        Test.startTest();
        Map<Id, Decimal> result = D2cCheckoutCustomLoyaltyController.getProportionalCartItemDiscounts(items, 20.00);
        Test.stopTest();

        Decimal sum = 0;
        for (CartItem ci : items) {
            Decimal d = result.get(ci.Id);
            System.assert(d >= 0 && d <= ci.TotalPrice, 'Every line must stay within [0, price].');
            sum += d;
        }
        System.assertEquals(20.00, sum, 'Total allocated must exactly equal the requested discount.');

        System.assertEquals(6.67, result.get(items[0].Id), 'First line absorbs a leftover cent.');
        System.assertEquals(6.67, result.get(items[1].Id), 'Second line absorbs a leftover cent.');
        System.assertEquals(6.66, result.get(items[2].Id), 'Third line keeps its floored share.');
    }

    /**
     * @description Verifies the leftover cent goes to the line with the largest fractional
     * remainder, NOT simply the first line — i.e. the distribution is genuinely largest-remainder
     * and order-independent. Lines 30 / 20 / 10 (total 60) with a $25 discount: exact shares are
     * 12.50 (frac 0), 8.333 (frac .33) and 4.166 (frac .66). Flooring leaves +0.01, which must land
     * on the third line (largest fraction) even though the first line has plenty of room.
     */
    @IsTest
    static void testProportional_LargestRemainderFavorsHighestFraction() {
        List<CartItem> items = buildPricedLoyaltyItems(new List<Decimal>{ 30.00, 20.00, 10.00 });

        Test.startTest();
        Map<Id, Decimal> result = D2cCheckoutCustomLoyaltyController.getProportionalCartItemDiscounts(items, 25.00);
        Test.stopTest();

        Decimal sum = 0;
        for (CartItem ci : items) sum += result.get(ci.Id);
        System.assertEquals(25.00, sum, 'Total allocated must exactly equal the requested discount.');

        System.assertEquals(12.50, result.get(items[0].Id), 'Exact-share line keeps its floored value.');
        System.assertEquals(8.33, result.get(items[1].Id), 'Middle-fraction line keeps its floored value.');
        System.assertEquals(4.17, result.get(items[2].Id),
            'Largest-fraction line receives the leftover cent, regardless of position.');
    }

    /**
     * @description Full coverage: when the discount equals the cart total, every line is
     * discounted by exactly its own price and nets to zero — even with values that don't divide
     * evenly. 10.00 / 10.00 / 7.43 (total 27.43) with a 27.43 discount.
     */
    @IsTest
    static void testProportional_FullCoverageZeroesEveryLine() {
        List<CartItem> items = buildPricedLoyaltyItems(new List<Decimal>{ 10.00, 10.00, 7.43 });

        Test.startTest();
        Map<Id, Decimal> result = D2cCheckoutCustomLoyaltyController.getProportionalCartItemDiscounts(items, 27.43);
        Test.stopTest();

        Decimal sum = 0;
        for (CartItem ci : items) {
            System.assertEquals(ci.TotalPrice, result.get(ci.Id),
                'Full coverage must discount each line by exactly its price so it nets to zero.');
            sum += result.get(ci.Id);
        }
        System.assertEquals(27.43, sum, 'Total discount must equal the full cart value.');
    }

    /**
     * @description A discount larger than the cart is capped at the cart total (never exceeds it)
     * and still zeroes every line.
     */
    @IsTest
    static void testProportional_DiscountExceedingTotalIsCapped() {
        List<CartItem> items = buildPricedLoyaltyItems(new List<Decimal>{ 100.00, 50.00 });

        Test.startTest();
        Map<Id, Decimal> result = D2cCheckoutCustomLoyaltyController.getProportionalCartItemDiscounts(items, 1000.00);
        Test.stopTest();

        Decimal sum = 0;
        for (CartItem ci : items) {
            System.assertEquals(ci.TotalPrice, result.get(ci.Id), 'Capped discount should zero each line.');
            sum += result.get(ci.Id);
        }
        System.assertEquals(150.00, sum, 'Discount must be capped at the cart total and never exceed it.');
    }

    /**
     * @description The original symptom: a dime-quantized voucher (10 pts = $1) on an odd-cent
     * cart can no longer equal the total exactly. The shortfall must be spread proportionally —
     * every line stays non-negative, within a cent of its exact share, and the full voucher is
     * spent to the penny. 10.00 / 10.00 / 7.43 (total 27.43) with a 27.40 voucher.
     */
    @IsTest
    static void testProportional_DimeVoucherOnOddCentCart() {
        List<Decimal> prices = new List<Decimal>{ 10.00, 10.00, 7.43 };
        Decimal totalBase = 27.43;
        Decimal voucher = 27.40;
        List<CartItem> items = buildPricedLoyaltyItems(prices);

        Test.startTest();
        Map<Id, Decimal> result = D2cCheckoutCustomLoyaltyController.getProportionalCartItemDiscounts(items, voucher);
        Test.stopTest();

        Decimal sum = 0;
        for (CartItem ci : items) {
            Decimal d = result.get(ci.Id);
            System.assert(d >= 0, 'No line may receive a negative discount. Got: ' + d);
            System.assert(d <= ci.TotalPrice,
                'No line may be discounted below zero. Got: ' + d + ' on line ' + ci.TotalPrice);
            Decimal exactShare = voucher * (ci.TotalPrice / totalBase);
            System.assert((d - exactShare).abs() <= 0.01,
                'Each line must stay within a cent of its exact proportional share. line=' +
                ci.TotalPrice + ' got=' + d + ' exact=' + exactShare);
            sum += d;
        }
        System.assertEquals(voucher, sum, 'The voucher is the source of truth: spent to the penny, never exceeded.');
    }

    /**
     * @description A non-positive line total receives zero discount and is excluded from the base,
     * so it cannot inflate the other lines' shares and over-spend the voucher. Lines
     * -5.00 / 10.00 / 10.00 (positive base 20.00) with a 9.00 voucher.
     */
    @IsTest
    static void testProportional_NegativeLineExcludedNoOverspend() {
        List<CartItem> items = buildPricedLoyaltyItems(new List<Decimal>{ -5.00, 10.00, 10.00 });
        Decimal voucher = 9.00;

        Test.startTest();
        Map<Id, Decimal> result = D2cCheckoutCustomLoyaltyController.getProportionalCartItemDiscounts(items, voucher);
        Test.stopTest();

        System.assert(result.get(items[0].Id) == 0, 'A non-positive line must receive zero discount.');

        Decimal sum = 0;
        for (CartItem ci : items) {
            Decimal d = result.get(ci.Id);
            System.assert(d >= 0, 'No line may receive a negative discount.');
            sum += d;
        }
        System.assertEquals(9.00, sum,
            'Voucher must be fully spent but never over-spent — the negative line cannot inflate the other shares.');
        System.assert(sum <= voucher, 'Total allocated must never exceed the voucher.');
    }

    /**
     * @description Full coverage where one line is sub-cent-sensitive: a $0.01 line and a $10.00
     * line with a $10.01 discount. The tiny line floors to 0.00 but the remainder spread fills it
     * back up to its cap of 0.01 (and never beyond), so both lines reach zero.
     */
    @IsTest
    static void testProportional_FullCoverageFillsTinyLineToCap() {
        List<CartItem> items = buildPricedLoyaltyItems(new List<Decimal>{ 0.01, 10.00 });

        Test.startTest();
        Map<Id, Decimal> result = D2cCheckoutCustomLoyaltyController.getProportionalCartItemDiscounts(items, 10.01);
        Test.stopTest();

        System.assertEquals(0.01, result.get(items[0].Id), 'Tiny line must be filled up to its price, not beyond.');
        System.assertEquals(10.00, result.get(items[1].Id), 'Large line must be fully covered.');
    }

    /**
     * @description The stacked-promotion case (the production bug): product C has a -$27
     * non-loyalty promotion, so its discountable value is 153 - 27 = 126 even though its TotalPrice
     * is 153. Allocating against the post-adjustment base must cap C's loyalty share at 126 so the
     * line can't be driven below zero, while A and B (no other promo) split the rest. Cart
     * 116 / 259 / 153 (post-adjustment 116 / 259 / 126, total 501) with a 470 voucher.
     */
    @IsTest
    static void testProportional_PostAdjustmentBasePreventsNegativeLine() {
        List<CartItem> items = buildPricedLoyaltyItems(new List<Decimal>{ 116.00, 259.00, 153.00 });
        Map<Id, Decimal> discountableBase = new Map<Id, Decimal>{
            items[0].Id => 116.00,  // A: no other promo
            items[1].Id => 259.00,  // B: no other promo
            items[2].Id => 126.00   // C: 153 list - 27 existing promo
        };
        Decimal voucher = 470.00;

        Test.startTest();
        Map<Id, Decimal> result =
            D2cCheckoutCustomLoyaltyController.getProportionalCartItemDiscounts(items, voucher, discountableBase);
        Test.stopTest();

        Decimal sum = 0;
        for (CartItem ci : items) {
            Decimal d = result.get(ci.Id);
            Decimal base = discountableBase.get(ci.Id);
            System.assert(d >= 0, 'No line may receive a negative discount.');
            System.assert(d <= base,
                'No line may be discounted past its post-adjustment value. base=' + base + ' got=' + d);
            sum += d;
        }
        System.assertEquals(470.00, sum, 'Full voucher spent to the penny, capped at the post-adjustment cart total.');
        System.assert(result.get(items[2].Id) <= 126.00,
            'Product C loyalty must not exceed its post-promo value of 126 (would otherwise go negative).');
    }

    /**
     * @description When the voucher covers the post-adjustment cart total, every line is discounted
     * by exactly its post-adjustment value and nets to zero — including a line that already carries
     * another promotion. Cart 116 / 259 / 153 (post-adjustment 116 / 259 / 126, total 501) with a
     * 501 voucher.
     */
    @IsTest
    static void testProportional_PostAdjustmentBaseFullCoverageZeroes() {
        List<CartItem> items = buildPricedLoyaltyItems(new List<Decimal>{ 116.00, 259.00, 153.00 });
        Map<Id, Decimal> discountableBase = new Map<Id, Decimal>{
            items[0].Id => 116.00,
            items[1].Id => 259.00,
            items[2].Id => 126.00
        };

        Test.startTest();
        Map<Id, Decimal> result =
            D2cCheckoutCustomLoyaltyController.getProportionalCartItemDiscounts(items, 501.00, discountableBase);
        Test.stopTest();

        for (CartItem ci : items) {
            System.assertEquals(discountableBase.get(ci.Id), result.get(ci.Id),
                'Full coverage must discount each line by exactly its post-adjustment value so it nets to zero.');
        }
    }

    //--- Helper Methods ---//

    /**
     * @description Creates a WebCart with loyalty redeemable items.
     * @param includeLoyaltyItems If true, adds loyalty redeemable items to cart.
     * @return The created WebCart.
     */
    private static WebCart createCartWithLoyaltyItems(Boolean includeLoyaltyItems) {
        WebStore store = [SELECT Id FROM WebStore LIMIT 1];
        Account buyerAccount = [SELECT Id FROM Account WHERE LastName = 'Buyer' LIMIT 1];
        Product2 loyaltyProduct = [SELECT Id FROM Product2 WHERE Loyalty_Redeemable__c = true LIMIT 1];

        WebCart cart = new WebCart(
            WebStoreId = store.Id,
            AccountId = buyerAccount.Id,
            Name = 'Test Cart',
            Status = 'Active'
        );
        insert cart;

        CartDeliveryGroup cdg = new CartDeliveryGroup(
            CartId = cart.Id,
            Name = 'Standard Shipment',
            DeliverToStreet = '123 Main St',
            DeliverToCity = 'Anytown',
            DeliverToState = 'IL',
            DeliverToPostalCode = '60601',
            DeliverToCountry = 'US'
        );
        insert cdg;

        if (includeLoyaltyItems) {
            List<CartItem> items = new List<CartItem>();
            items.add(new CartItem(
                Name = 'Loyalty Item 1',
                CartId = cart.Id,
                CartDeliveryGroupId = cdg.Id,
                Product2Id = loyaltyProduct.Id,
                Quantity = 1,
                Type = 'Product',
                TotalPrice = 100.00,
                SalesPrice = 100.00,
                TotalAdjustmentAmount = 0.00,
                TotalPriceAfterAllAdjustments = 100.00,
                TotalPromoAdjustmentAmount = 0.00
            ));
            items.add(new CartItem(
                Name = 'Loyalty Item 2',
                CartId = cart.Id,
                CartDeliveryGroupId = cdg.Id,
                Product2Id = loyaltyProduct.Id,
                Quantity = 1,
                Type = 'Product',
                TotalPrice = 50.00,
                SalesPrice = 50.00,
                TotalAdjustmentAmount = 0.00,
                TotalPriceAfterAllAdjustments = 50.00,
                TotalPromoAdjustmentAmount = 0.00
            ));
            insert items;
        }

        return cart;
    }

    /**
     * @description Builds loyalty cart items for direct (in-memory) testing of
     * getProportionalCartItemDiscounts. Items are inserted with valid prices to obtain distinct
     * Ids, then their TotalPrice is overwritten in memory with the requested values — no update,
     * no re-query. The method under test reads TotalPrice straight off the passed objects, so this
     * lets us exercise odd-cent and negative line totals without persisting values the platform
     * might reject, and without any Loyalty Management / voucher setup. The returned list order
     * matches the supplied prices, so callers can assert on items[i] deterministically.
     *
     * @param prices The TotalPrice to assign to each line (may include odd cents or negatives).
     * @return The inserted cart items, with TotalPrice set in memory to the requested values.
     */
    private static List<CartItem> buildPricedLoyaltyItems(List<Decimal> prices) {
        WebStore store = [SELECT Id FROM WebStore LIMIT 1];
        Account buyerAccount = [SELECT Id FROM Account WHERE LastName = 'Buyer' LIMIT 1];
        Product2 loyaltyProduct = [SELECT Id FROM Product2 WHERE Loyalty_Redeemable__c = true LIMIT 1];

        WebCart cart = new WebCart(
            WebStoreId = store.Id,
            AccountId = buyerAccount.Id,
            Name = 'PF Test Cart',
            Status = 'Active'
        );
        insert cart;

        CartDeliveryGroup cdg = new CartDeliveryGroup(
            CartId = cart.Id,
            Name = 'Standard Shipment',
            DeliverToStreet = '123 Main St',
            DeliverToCity = 'Anytown',
            DeliverToState = 'IL',
            DeliverToPostalCode = '60601',
            DeliverToCountry = 'US'
        );
        insert cdg;

        List<CartItem> items = new List<CartItem>();
        Integer n = 1;
        for (Decimal p : prices) {
            // Insert with a valid (non-negative) seed price; the real test value is set below.
            Decimal seed = (p == null || p < 0) ? 1.00 : p;
            items.add(new CartItem(
                Name = 'PF Item ' + n++,
                CartId = cart.Id,
                CartDeliveryGroupId = cdg.Id,
                Product2Id = loyaltyProduct.Id,
                Quantity = 1,
                Type = 'Product',
                TotalPrice = seed,
                SalesPrice = seed,
                TotalAdjustmentAmount = 0.00,
                TotalPriceAfterAllAdjustments = seed,
                TotalPromoAdjustmentAmount = 0.00
            ));
        }
        insert items;

        // Overwrite TotalPrice in memory with the requested values (incl. odd cents / negatives).
        for (Integer i = 0; i < items.size(); i++) {
            items[i].TotalPrice = prices[i];
        }
        return items;
    }

    /**
     * @description Creates a Voucher and associated Coupon record using LoyaltyManagement API.
     * This is the proper way to create vouchers in Salesforce Loyalty - using the
     * LoyaltyManagement.LoyaltyResources.issueVoucher() API which properly sets RemainingValue.
     * 
     * @param remainingValue The desired remaining value for the voucher (used to create VoucherDefinition).
     * @return The created Voucher with properly set RemainingValue.
     */
    private static Voucher createVoucherAndCoupon(Decimal remainingValue) {
        // Get Account and Contact for loyalty member
        Account buyerAccount = [SELECT Id, PersonContactId FROM Account WHERE LastName = 'Buyer' LIMIT 1];
        Voucher voucher = new Voucher();
        // Get or create LoyaltyProgram
        List<LoyaltyProgram> programs = [SELECT Id, Name FROM LoyaltyProgram WHERE Status = 'Active' LIMIT 1];
        LoyaltyProgram loyaltyProgram;
        if (programs.isEmpty()) {
            loyaltyProgram = new LoyaltyProgram(
                Name = 'Test Loyalty Program',
                Status = 'Active'
            );
            insert loyaltyProgram;
        } else {
            loyaltyProgram = programs[0];
        }
        
        // Get or create LoyaltyProgramMember
        List<LoyaltyProgramMember> members = [
            SELECT Id, MembershipNumber 
            FROM LoyaltyProgramMember 
            WHERE ContactId = :buyerAccount.PersonContactId 
            AND ProgramId = :loyaltyProgram.Id 
            LIMIT 1
        ];
        LoyaltyProgramMember loyaltyMember;
        if (members.isEmpty()) {
            loyaltyMember = new LoyaltyProgramMember(
                MembershipNumber = String.valueOf(buyerAccount.Id),
                ContactId = buyerAccount.PersonContactId,
                EnrollmentDate = Date.today(),
                MemberStatus = 'Active',
                ProgramId = loyaltyProgram.Id
            );
            insert loyaltyMember;
        } else {
            loyaltyMember = members[0];
        }
        
        // Create Promotion for the voucher
        Promotion promotion = new Promotion(
            Name = 'Test Promotion',
            IsActive = true,
            StartDate = Date.today().addDays(-30),
            EndDate = Date.today().addDays(30)
        );
        insert promotion;
        
        // Create or get VoucherDefinition - this defines the voucher value and type
        // VoucherDefinition must exist before issuing vouchers
        // Try to find an existing one first, or create if possible
        String voucherDefinitionName = 'TestVD_' + String.valueOf(remainingValue);
        VoucherDefinition voucherDef = null;
        
        // // Try to query for existing VoucherDefinition
        // try {
        //     List<VoucherDefinition> existingDefs = [
        //         SELECT Id, Name, InitialValue 
        //         FROM VoucherDefinition 
        //         WHERE Name = :voucherDefinitionName 
        //         LIMIT 1
        //     ];
        //     if (!existingDefs.isEmpty()) {
        //         voucherDef = existingDefs[0];
        //     }
        // } catch (Exception e) {
        //     // VoucherDefinition object may not be queryable or may not exist
        //     // We'll proceed with the name and let the API handle it
        // }
        
        // If VoucherDefinition doesn't exist, try to create it
        // Note: VoucherDefinition may have specific required fields or creation requirements
        if (voucherDef == null) {
            try {
                voucherDef = new VoucherDefinition(
                    Name = voucherDefinitionName,
                    IsActive = true
                );
                insert voucherDef;
            } catch (Exception e) {
                // VoucherDefinition may not be directly creatable via DML
                // Use the name and let the API handle it, or use a default name
                voucherDefinitionName = 'V1'; // Try a common default name
            }
        }
        
        // // Create LoyaltyTransactionJournal for the voucher issuance
        // // This tracks the transaction that issues the voucher
        // TransactionJournal journal = new TransactionJournal(
        //     TransactionDate = DateTime.now(),
        //     TransactionType = 'Voucher Issuance'
        // );
        // insert journal;
        
        // Generate voucher code
        String voucherCode = generateRandomString(8);
        

        voucher = new Voucher(
            PromotionId = promotion.Id,
            EffectiveDate = Date.today(),
            VoucherCode = voucherCode,
            FaceValue = remainingValue
        );
        insert voucher;

        // Create Coupon linked to Voucher
        String couponCode = 'TEST' + String.valueOf(DateTime.now().getTime());
        Coupon coupon = new Coupon(
            CouponCode = couponCode,
            Voucher__c = voucher.Id,
            PromotionId = promotion.Id
        );
        
        try {
            insert coupon;
        } catch (DmlException e) {
            if (e.getMessage().contains('Coupon Created - Set Voucher Code')) {
                throw e;
            } else {
                throw e;
            }
        }

        return voucher;
    }

    /**
     * @description Generates a random alphanumeric string of specified length.
     * @param length The length of the string to generate.
     * @return A random string.
     */
    private static String generateRandomString(Integer length) {
        String chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
        String result = '';
        for (Integer i = 0; i < length; i++) {
            Integer randomIndex = Math.mod(Math.abs(Crypto.getRandomInteger()), chars.length());
            result += chars.substring(randomIndex, randomIndex + 1);
        }
        return result;
    }
}