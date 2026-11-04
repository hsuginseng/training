/**
 * Cart setup mirrors Salesforce's B2CCheckInventorySampleTest. Inventory comparison paths use
 * D2COmniChannelInventoryInterface.testInventoryBySku so tests do not depend on live OCI.
 *
 * @see https://github.com/forcedotcom/commerce-on-lightning/blob/main/examples/b2c/checkout/integrations/classes/B2CCheckInventorySampleTest.cls
 */
@isTest
public with sharing class D2COmniChannelInventoryTest {
    @TestSetup
    static void setup() {
        Account account = new Account(Name = 'TestAccount');
        insert account;
        WebStore webStore = new WebStore(
            Name = 'TestWebStore',
            SupportedLanguages = 'en_US',
            DefaultLanguage = 'en_US'
        );
        insert webStore;
        WebCart cart = new WebCart(
            Name = 'Cart',
            WebStoreId = webStore.Id,
            AccountId = account.Id,
            Status = 'Active'
        );
        insert cart;
        CartDeliveryGroup cartDeliveryGroup = new CartDeliveryGroup(CartId = cart.Id, Name = 'Default Delivery');
        insert cartDeliveryGroup;

        // Production code reads SKU from Product2.StockKeepingUnit via the cart item
        // relationship, so cart items in tests must point to a real Product2.
        insert new Product2(Name = 'TestProduct1', StockKeepingUnit = 'SKU_Test1', IsActive = true);

        insertCartItem(cart.Id, cartDeliveryGroup.Id);
    }

    private static void clearInventoryStub() {
        D2COmniChannelInventoryInterface.testInventoryBySku = null;
    }

    private static sfdc_checkout.IntegrationInfo makeJobInfo(String siteLanguage) {
        sfdc_checkout.IntegrationInfo info = new sfdc_checkout.IntegrationInfo();
        info.jobId = null;
        info.siteLanguage = siteLanguage;
        return info;
    }

    // --------------------------------------------------------------------
    // Happy path
    // --------------------------------------------------------------------

    @isTest
    static void testWhenExternalServiceQuantityIsLargerThanTheCartItemQuantityASuccessStatusIsReturned() {
        WebCart webCart = [SELECT Id FROM WebCart WHERE Name = 'Cart' LIMIT 1];
        D2COmniChannelInventoryInterface.testInventoryBySku = new Map<String, Decimal>{ 'SKU_Test1' => 10 };

        Test.startTest();
        D2COmniChannelInventoryInterface apexSample = new D2COmniChannelInventoryInterface();
        sfdc_checkout.IntegrationStatus integrationResult = apexSample.startCartProcessAsync(null, webCart.Id);
        Test.stopTest();

        clearInventoryStub();
        System.assertEquals(sfdc_checkout.IntegrationStatus.Status.SUCCESS, integrationResult.status);
    }

    @isTest
    static void testSuccess_NoValidationOutputsCreated() {
        WebCart webCart = [SELECT Id FROM WebCart WHERE Name = 'Cart' LIMIT 1];
        D2COmniChannelInventoryInterface.testInventoryBySku = new Map<String, Decimal>{ 'SKU_Test1' => 50 };

        Test.startTest();
        D2COmniChannelInventoryInterface apexSample = new D2COmniChannelInventoryInterface();
        sfdc_checkout.IntegrationStatus integrationResult = apexSample.startCartProcessAsync(makeJobInfo(null), webCart.Id);
        Test.stopTest();

        clearInventoryStub();
        System.assertEquals(sfdc_checkout.IntegrationStatus.Status.SUCCESS, integrationResult.status);
        List<CartValidationOutput> outs = [SELECT Id FROM CartValidationOutput WHERE CartId = :webCart.Id];
        System.assertEquals(0, outs.size(), 'No validation outputs should be created on success');
    }

    // --------------------------------------------------------------------
    // SKU not found in inventory system
    // --------------------------------------------------------------------

    @isTest
    static void testStubSkuNotFound_ReturnsFailed() {
        clearInventoryStub();
        WebCart webCart = [SELECT Id FROM WebCart WHERE Name = 'Cart' LIMIT 1];
        D2COmniChannelInventoryInterface.testInventoryBySku = new Map<String, Decimal>();

        Test.startTest();
        D2COmniChannelInventoryInterface apexSample = new D2COmniChannelInventoryInterface();
        sfdc_checkout.IntegrationStatus integrationResult = apexSample.startCartProcessAsync(makeJobInfo(null), webCart.Id);
        Test.stopTest();

        clearInventoryStub();
        System.assertEquals(sfdc_checkout.IntegrationStatus.Status.FAILED, integrationResult.status);
        List<CartValidationOutput> outs = [
            SELECT Message, RelatedEntityId FROM CartValidationOutput WHERE CartId = :webCart.Id
        ];
        // Expect: 1 summary banner (RelatedEntityId = cartId) + 1 per-item error (RelatedEntityId = cartItemId)
        System.assertEquals(2, outs.size());
        Boolean foundPerItem = false;
        for (CartValidationOutput o : outs) {
            if (o.Message.contains('is not available')) foundPerItem = true;
        }
        System.assert(foundPerItem, 'Expected a per-item "is not available" error');
    }

    // --------------------------------------------------------------------
    // Insufficient quantity
    // --------------------------------------------------------------------

    @isTest
    static void testStubInsufficientQuantity_ReturnsFailed() {
        clearInventoryStub();
        WebCart webCart = [SELECT Id FROM WebCart WHERE Name = 'Cart' LIMIT 1];
        D2COmniChannelInventoryInterface.testInventoryBySku = new Map<String, Decimal>{ 'SKU_Test1' => 1 };

        Test.startTest();
        D2COmniChannelInventoryInterface apexSample = new D2COmniChannelInventoryInterface();
        sfdc_checkout.IntegrationStatus integrationResult = apexSample.startCartProcessAsync(makeJobInfo(null), webCart.Id);
        Test.stopTest();

        clearInventoryStub();
        System.assertEquals(sfdc_checkout.IntegrationStatus.Status.FAILED, integrationResult.status);
        List<CartValidationOutput> outs = [
            SELECT Message FROM CartValidationOutput WHERE CartId = :webCart.Id
        ];
        Boolean foundPerItem = false;
        for (CartValidationOutput o : outs) {
            if (o.Message.contains('Only') && o.Message.contains('in stock.')) foundPerItem = true;
        }
        System.assert(foundPerItem, 'Expected "Only N in stock." per-item error');
    }

    @isTest
    static void testInsufficientQuantity_IntegerFormattingNoDecimal() {
        clearInventoryStub();
        WebCart webCart = [SELECT Id FROM WebCart WHERE Name = 'Cart' LIMIT 1];
        D2COmniChannelInventoryInterface.testInventoryBySku = new Map<String, Decimal>{ 'SKU_Test1' => 2.0 };

        Test.startTest();
        D2COmniChannelInventoryInterface apexSample = new D2COmniChannelInventoryInterface();
        apexSample.startCartProcessAsync(makeJobInfo(null), webCart.Id);
        Test.stopTest();

        clearInventoryStub();
        List<CartValidationOutput> outs = [
            SELECT Message FROM CartValidationOutput WHERE CartId = :webCart.Id
        ];
        Boolean hasCleanInteger = false;
        for (CartValidationOutput o : outs) {
            if (o.Message.contains('Only 2 in stock.')) hasCleanInteger = true;
            System.assert(!o.Message.contains('2.0'), 'Quantity should not contain decimal');
        }
        System.assert(hasCleanInteger, 'Expected "Only 2 in stock." with clean integer');
    }

    // --------------------------------------------------------------------
    // Per-item + summary banner behavior
    // --------------------------------------------------------------------

    @isTest
    static void testMultipleErrors_EachCartItemGetsOwnOutputPlusSummary() {
        clearInventoryStub();
        WebCart webCart = [SELECT Id FROM WebCart WHERE Name = 'Cart' LIMIT 1];
        List<CartDeliveryGroup> groups = [SELECT Id FROM CartDeliveryGroup WHERE CartId = :webCart.Id LIMIT 1];

        Product2 p2 = new Product2(Name = 'TestProduct2', StockKeepingUnit = 'SKU_Test2', IsActive = true);
        insert p2;

        CartItem secondItem = new CartItem(
            CartId = webCart.Id,
            Product2Id = p2.Id,
            Quantity = 5.0,
            Type = 'Product',
            Name = 'TestProduct2',
            CartDeliveryGroupId = groups[0].Id
        );
        insert secondItem;

        D2COmniChannelInventoryInterface.testInventoryBySku = new Map<String, Decimal>{
            'SKU_Test1' => 1,
            'SKU_Test2' => 2
        };

        Test.startTest();
        D2COmniChannelInventoryInterface apexSample = new D2COmniChannelInventoryInterface();
        sfdc_checkout.IntegrationStatus integrationResult = apexSample.startCartProcessAsync(makeJobInfo(null), webCart.Id);
        Test.stopTest();

        clearInventoryStub();

        System.assertEquals(sfdc_checkout.IntegrationStatus.Status.FAILED, integrationResult.status);

        List<CartValidationOutput> outs = [
            SELECT Id, Message, RelatedEntityId FROM CartValidationOutput WHERE CartId = :webCart.Id
        ];
        System.assertEquals(3, outs.size(), 'Expected 1 summary + 2 per-item CVOs');

        Integer summaryCount = 0;
        Integer perItemCount = 0;
        Boolean summaryHasCount = false;
        for (CartValidationOutput o : outs) {
            if (o.RelatedEntityId == webCart.Id) {
                summaryCount++;
                if (o.Message.contains('2 items') && o.Message.contains('exceed available stock')) {
                    summaryHasCount = true;
                }
            } else {
                perItemCount++;
            }
        }
        System.assertEquals(1, summaryCount, 'Exactly one summary banner');
        System.assertEquals(2, perItemCount, 'Exactly two per-item errors');
        System.assert(summaryHasCount, 'Summary should include count of issues');

        // Cleanup after assertions — avoids cascade-deleting the CVOs we want to verify
        delete secondItem;
    }

    @isTest
    static void testSingleError_SummaryUsesSingularPhrasing() {
        clearInventoryStub();
        WebCart webCart = [SELECT Id FROM WebCart WHERE Name = 'Cart' LIMIT 1];
        D2COmniChannelInventoryInterface.testInventoryBySku = new Map<String, Decimal>{ 'SKU_Test1' => 1 };

        Test.startTest();
        D2COmniChannelInventoryInterface apexSample = new D2COmniChannelInventoryInterface();
        apexSample.startCartProcessAsync(makeJobInfo(null), webCart.Id);
        Test.stopTest();

        clearInventoryStub();
        List<CartValidationOutput> outs = [
            SELECT Message, RelatedEntityId FROM CartValidationOutput WHERE CartId = :webCart.Id
        ];
        Boolean singularFound = false;
        for (CartValidationOutput o : outs) {
            if (o.RelatedEntityId == webCart.Id && o.Message.contains('One item') && o.Message.contains('exceeds available stock')) {
                singularFound = true;
            }
        }
        System.assert(singularFound, 'Summary should use singular phrasing when 1 item has issues');
    }

    @isTest
    static void testPerItemError_RelatedEntityIdPointsToCartItem() {
        clearInventoryStub();
        WebCart webCart = [SELECT Id FROM WebCart WHERE Name = 'Cart' LIMIT 1];
        CartItem theItem = [SELECT Id FROM CartItem WHERE CartId = :webCart.Id AND Product2.StockKeepingUnit = 'SKU_Test1' LIMIT 1];
        D2COmniChannelInventoryInterface.testInventoryBySku = new Map<String, Decimal>{ 'SKU_Test1' => 1 };

        Test.startTest();
        D2COmniChannelInventoryInterface apexSample = new D2COmniChannelInventoryInterface();
        apexSample.startCartProcessAsync(makeJobInfo(null), webCart.Id);
        Test.stopTest();

        clearInventoryStub();
        List<CartValidationOutput> outs = [
            SELECT Message, RelatedEntityId FROM CartValidationOutput
            WHERE CartId = :webCart.Id AND RelatedEntityId = :theItem.Id
        ];
        System.assertEquals(1, outs.size(), 'Per-item error should point at the cart item by ID');
        System.assert(outs[0].Message.contains('Only'), 'Per-item error should be the "Only N in stock" message');
    }

    // --------------------------------------------------------------------
    // Empty cart / blank SKU (fatal paths)
    // --------------------------------------------------------------------

    @isTest
    static void testEmptyCartHasError() {
        clearInventoryStub();
        deleteCartItem();
        Test.startTest();

        D2COmniChannelInventoryInterface apexSample = new D2COmniChannelInventoryInterface();
        WebCart webCart = [SELECT Id FROM WebCart WHERE Name = 'Cart' LIMIT 1];
        sfdc_checkout.IntegrationStatus integrationResult = apexSample.startCartProcessAsync(makeJobInfo(null), webCart.Id);

        System.assertEquals(sfdc_checkout.IntegrationStatus.Status.FAILED, integrationResult.status);
        List<CartValidationOutput> cartValidationOutputs = [
            SELECT Id, Message
            FROM CartValidationOutput
            WHERE CartId = :webCart.Id
        ];
        System.assertEquals(1, cartValidationOutputs.size());
        System.assertEquals('Looks like your cart is empty.', cartValidationOutputs[0].Message);
        Test.stopTest();

        insertCartItem(webCart.Id);
    }

    @isTest
    static void testProductsWithNoSkuHasError() {
        clearInventoryStub();
        Test.startTest();

        WebCart webCart = [SELECT Id FROM WebCart WHERE Name = 'Cart' LIMIT 1];
        List<CartDeliveryGroup> cartDeliveryGroups = [SELECT Id FROM CartDeliveryGroup WHERE CartId = :webCart.Id LIMIT 1];

        CartItem cartItemWithNoSku = new CartItem(
            CartId = webCart.Id,
            Quantity = 1.0,
            Type = 'Product',
            Name = 'TestProductNoSku',
            CartDeliveryGroupId = cartDeliveryGroups[0].Id
        );
        insert cartItemWithNoSku;

        D2COmniChannelInventoryInterface apexSample = new D2COmniChannelInventoryInterface();
        sfdc_checkout.IntegrationStatus integrationResult = apexSample.startCartProcessAsync(makeJobInfo(null), webCart.Id);

        System.assertEquals(sfdc_checkout.IntegrationStatus.Status.FAILED, integrationResult.status);
        List<CartValidationOutput> cartValidationOutputs = [
            SELECT Id, Message
            FROM CartValidationOutput
            WHERE CartId = :webCart.Id
        ];
        System.assertEquals(1, cartValidationOutputs.size());
        System.assertEquals(
            'The SKUs for all products in your cart must be defined.',
            cartValidationOutputs[0].Message
        );
        Test.stopTest();

        delete cartItemWithNoSku;
    }

    // --------------------------------------------------------------------
    // Localization — zh_CN and zh_TW
    // --------------------------------------------------------------------

    @isTest
    static void testLocalization_SimplifiedChinese_CartEmpty() {
        clearInventoryStub();
        deleteCartItem();

        Test.startTest();
        D2COmniChannelInventoryInterface apexSample = new D2COmniChannelInventoryInterface();
        WebCart webCart = [SELECT Id FROM WebCart WHERE Name = 'Cart' LIMIT 1];
        apexSample.startCartProcessAsync(makeJobInfo('zh_CN'), webCart.Id);
        Test.stopTest();

        List<CartValidationOutput> outs = [
            SELECT Message FROM CartValidationOutput WHERE CartId = :webCart.Id
        ];
        System.assertEquals('您的购物车是空的。', outs[0].Message);

        insertCartItem(webCart.Id);
    }

    @isTest
    static void testLocalization_TraditionalChinese_CartEmpty() {
        clearInventoryStub();
        deleteCartItem();

        Test.startTest();
        D2COmniChannelInventoryInterface apexSample = new D2COmniChannelInventoryInterface();
        WebCart webCart = [SELECT Id FROM WebCart WHERE Name = 'Cart' LIMIT 1];
        apexSample.startCartProcessAsync(makeJobInfo('zh_TW'), webCart.Id);
        Test.stopTest();

        List<CartValidationOutput> outs = [
            SELECT Message FROM CartValidationOutput WHERE CartId = :webCart.Id
        ];
        System.assertEquals('您的購物車是空的。', outs[0].Message);

        insertCartItem(webCart.Id);
    }

    @isTest
    static void testLocalization_SimplifiedChinese_InsufficientQuantity() {
        clearInventoryStub();
        WebCart webCart = [SELECT Id FROM WebCart WHERE Name = 'Cart' LIMIT 1];
        D2COmniChannelInventoryInterface.testInventoryBySku = new Map<String, Decimal>{ 'SKU_Test1' => 2 };

        Test.startTest();
        D2COmniChannelInventoryInterface apexSample = new D2COmniChannelInventoryInterface();
        apexSample.startCartProcessAsync(makeJobInfo('zh_CN'), webCart.Id);
        Test.stopTest();

        clearInventoryStub();
        List<CartValidationOutput> outs = [
            SELECT Message, RelatedEntityId FROM CartValidationOutput WHERE CartId = :webCart.Id
        ];
        Boolean foundPerItem = false;
        Boolean foundSummary = false;
        for (CartValidationOutput o : outs) {
            if (o.Message.contains('仅剩') && o.Message.contains('件库存')) foundPerItem = true;
            if (o.Message.contains('超出库存数量')) foundSummary = true;
        }
        System.assert(foundPerItem, 'Expected zh_CN per-item message');
        System.assert(foundSummary, 'Expected zh_CN summary message');
    }

    @isTest
    static void testLocalization_TraditionalChinese_InsufficientQuantity() {
        clearInventoryStub();
        WebCart webCart = [SELECT Id FROM WebCart WHERE Name = 'Cart' LIMIT 1];
        D2COmniChannelInventoryInterface.testInventoryBySku = new Map<String, Decimal>{ 'SKU_Test1' => 2 };

        Test.startTest();
        D2COmniChannelInventoryInterface apexSample = new D2COmniChannelInventoryInterface();
        apexSample.startCartProcessAsync(makeJobInfo('zh_TW'), webCart.Id);
        Test.stopTest();

        clearInventoryStub();
        List<CartValidationOutput> outs = [
            SELECT Message, RelatedEntityId FROM CartValidationOutput WHERE CartId = :webCart.Id
        ];
        Boolean foundPerItem = false;
        Boolean foundSummary = false;
        for (CartValidationOutput o : outs) {
            if (o.Message.contains('僅剩') && o.Message.contains('件庫存')) foundPerItem = true;
            if (o.Message.contains('超出庫存數量')) foundSummary = true;
        }
        System.assert(foundPerItem, 'Expected zh_TW per-item message');
        System.assert(foundSummary, 'Expected zh_TW summary message');
    }

    @isTest
    static void testLocalization_UnknownLanguageFallsBackToEnglish() {
        clearInventoryStub();
        deleteCartItem();

        Test.startTest();
        D2COmniChannelInventoryInterface apexSample = new D2COmniChannelInventoryInterface();
        WebCart webCart = [SELECT Id FROM WebCart WHERE Name = 'Cart' LIMIT 1];
        apexSample.startCartProcessAsync(makeJobInfo('fr_FR'), webCart.Id);
        Test.stopTest();

        List<CartValidationOutput> outs = [
            SELECT Message FROM CartValidationOutput WHERE CartId = :webCart.Id
        ];
        System.assertEquals('Looks like your cart is empty.', outs[0].Message);

        insertCartItem(webCart.Id);
    }

    @isTest
    static void testLocalization_SimplifiedChinese_ProductNotAvailable() {
        clearInventoryStub();
        WebCart webCart = [SELECT Id FROM WebCart WHERE Name = 'Cart' LIMIT 1];
        D2COmniChannelInventoryInterface.testInventoryBySku = new Map<String, Decimal>();

        Test.startTest();
        D2COmniChannelInventoryInterface apexSample = new D2COmniChannelInventoryInterface();
        apexSample.startCartProcessAsync(makeJobInfo('zh_CN'), webCart.Id);
        Test.stopTest();

        clearInventoryStub();
        List<CartValidationOutput> outs = [
            SELECT Message FROM CartValidationOutput WHERE CartId = :webCart.Id
        ];
        Boolean foundPerItem = false;
        for (CartValidationOutput o : outs) {
            if (o.Message.contains('暂不可用')) foundPerItem = true;
        }
        System.assert(foundPerItem, 'Expected zh_CN "not available" message');
    }

    // --------------------------------------------------------------------
    // Exception path — exercises the real getQuantitiesFromExternalService code
    // --------------------------------------------------------------------

    @isTest
    static void testExceptionPath_NoWebStoreInventorySource_HitsCatchBranch() {
        clearInventoryStub();
        WebCart webCart = [SELECT Id FROM WebCart WHERE Name = 'Cart' LIMIT 1];

        // No WebStoreInventorySource exists → SOQL throws → outer catch fires

        Test.startTest();
        D2COmniChannelInventoryInterface apexSample = new D2COmniChannelInventoryInterface();
        sfdc_checkout.IntegrationStatus integrationResult = apexSample.startCartProcessAsync(makeJobInfo(null), webCart.Id);
        Test.stopTest();

        System.assertEquals(sfdc_checkout.IntegrationStatus.Status.FAILED, integrationResult.status);
        List<CartValidationOutput> outs = [
            SELECT Message FROM CartValidationOutput WHERE CartId = :webCart.Id
        ];
        System.assertEquals(1, outs.size(), 'Exception path creates a single error CVO');
        System.assert(
            outs[0].Message.contains('exception'),
            'Expected exception-formatted message, got: ' + outs[0].Message
        );
    }

    @isTest
    static void testExceptionPath_LocalizedSimplifiedChinese() {
        clearInventoryStub();
        WebCart webCart = [SELECT Id FROM WebCart WHERE Name = 'Cart' LIMIT 1];

        Test.startTest();
        D2COmniChannelInventoryInterface apexSample = new D2COmniChannelInventoryInterface();
        apexSample.startCartProcessAsync(makeJobInfo('zh_CN'), webCart.Id);
        Test.stopTest();

        List<CartValidationOutput> outs = [
            SELECT Message FROM CartValidationOutput WHERE CartId = :webCart.Id
        ];
        Boolean localized = false;
        for (CartValidationOutput o : outs) {
            if (o.Message.startsWith('发生') && o.Message.contains('类型的异常')) localized = true;
        }
        System.assert(localized, 'Expected zh_CN exception message, got: ' + outs[0].Message);
    }

    @isTest
    static void testExceptionPath_LocalizedTraditionalChinese() {
        clearInventoryStub();
        WebCart webCart = [SELECT Id FROM WebCart WHERE Name = 'Cart' LIMIT 1];

        Test.startTest();
        D2COmniChannelInventoryInterface apexSample = new D2COmniChannelInventoryInterface();
        apexSample.startCartProcessAsync(makeJobInfo('zh_TW'), webCart.Id);
        Test.stopTest();

        List<CartValidationOutput> outs = [
            SELECT Message FROM CartValidationOutput WHERE CartId = :webCart.Id
        ];
        Boolean localized = false;
        for (CartValidationOutput o : outs) {
            if (o.Message.startsWith('發生') && o.Message.contains('類型的例外')) localized = true;
        }
        System.assert(localized, 'Expected zh_TW exception message, got: ' + outs[0].Message);
    }

    // --------------------------------------------------------------------
    // Helpers
    // --------------------------------------------------------------------

    static void insertCartItem(String cartId) {
        List<CartDeliveryGroup> cartDeliveryGroups = [SELECT Id FROM CartDeliveryGroup WHERE CartId = :cartId LIMIT 1];
        insertCartItem(cartId, cartDeliveryGroups[0].Id);
    }

    static void insertCartItem(String cartId, String cartDeliveryGroupId) {
        Product2 p = [SELECT Id FROM Product2 WHERE StockKeepingUnit = 'SKU_Test1' LIMIT 1];
        CartItem cartItem = new CartItem(
            CartId = cartId,
            Product2Id = p.Id,
            Quantity = 3.0,
            Type = 'Product',
            Name = 'TestProduct',
            CartDeliveryGroupId = cartDeliveryGroupId
        );
        insert cartItem;
    }

    static void deleteCartItem() {
        CartItem cartItem = [SELECT Id FROM CartItem WHERE Name = 'TestProduct' LIMIT 1];
        delete cartItem;
    }
}