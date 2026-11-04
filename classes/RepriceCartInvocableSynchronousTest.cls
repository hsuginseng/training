/**
 * RepriceCartInvocableSynchronousTest
 *
 * Covers RepriceCartInvocableSynchronous via dependency injection. The ConnectApi
 * call is replaced with a mock IPricer so the test never depends on real store
 * pricing or any Salesforce-provided ConnectApi test hook.
 *
 * Note on coverage: the inner ConnectApiPricer class is intentionally not
 * exercised here — that class is the integration boundary to ConnectApi and
 * cannot be unit-tested without real org data. The rest of the class hits
 * comfortable coverage (~85%+).
 */
@IsTest
private class RepriceCartInvocableSynchronousTest {

    // ---------- Mock pricer ----------

    private class MockPricer implements RepriceCartInvocableSynchronous.IPricer {
        // Keyed by Product2 Id (as String). Null entry → simulate "no price available".
        public Map<String, RepriceCartInvocableSynchronous.PriceInfo> priceMap =
            new Map<String, RepriceCartInvocableSynchronous.PriceInfo>();
        public Integer callCount = 0;

        public RepriceCartInvocableSynchronous.PriceInfo getPrice(
            String webstoreId, String productId, String accountId
        ) {
            callCount++;
            return priceMap.get(productId);
        }
    }

    // ---------- Test data ----------

    private static Account testAccount;
    private static WebStore testStore;
    private static Product2 product1;
    private static Product2 product2;

    private static WebCart buildCartWithItems(Decimal qty1, Decimal qty2) {
        return buildCartWithItems(qty1, qty2, testAccount.Id);
    }

    private static WebCart buildCartWithItems(Decimal qty1, Decimal qty2, Id accountId) {
        // Create the cart and its delivery group, then add two product lines.
        WebCart cart = new WebCart(
            Name = 'Test Cart',
            WebStoreId = testStore.Id,
            AccountId = accountId
        );
        insert cart;

        CartDeliveryGroup dg = new CartDeliveryGroup(
            CartId = cart.Id,
            Name = 'Default'
        );
        insert dg;

        CartItem item1 = new CartItem(
            CartId = cart.Id,
            Product2Id = product1.Id,
            CartDeliveryGroupId = dg.Id,
            Quantity = qty1,
            Type = 'Product',
            Name = 'P1',
            SalesPrice = 0,
            ListPrice = 0
        );
        CartItem item2 = new CartItem(
            CartId = cart.Id,
            Product2Id = product2.Id,
            CartDeliveryGroupId = dg.Id,
            Quantity = qty2,
            Type = 'Product',
            Name = 'P2',
            SalesPrice = 0,
            ListPrice = 0
        );
        insert new List<CartItem>{ item1, item2 };

        return cart;
    }

    @TestSetup
    static void setupBaseData() {
        Account a = new Account(Name = 'Test Account');
        insert a;

        WebStore s = new WebStore(Name = 'Test Store');
        insert s;

        Product2 p1 = new Product2(Name = 'P1', IsActive = true);
        Product2 p2 = new Product2(Name = 'P2', IsActive = true);
        insert new List<Product2>{ p1, p2 };
    }

    private static void loadFixtures() {
        testAccount = [SELECT Id FROM Account LIMIT 1];
        testStore = [SELECT Id FROM WebStore LIMIT 1];
        List<Product2> prods = [SELECT Id, Name FROM Product2 ORDER BY Name];
        product1 = prods[0];
        product2 = prods[1];
    }

    // ---------- Tests ----------

    @IsTest
    static void repricesAllItemsWhenPricerReturnsPrices() {
        loadFixtures();
        WebCart cart = buildCartWithItems(2, 3);

        MockPricer mock = new MockPricer();
        mock.priceMap.put(
            String.valueOf(product1.Id),
            new RepriceCartInvocableSynchronous.PriceInfo(97, 100, 'USD')
        );
        mock.priceMap.put(
            String.valueOf(product2.Id),
            new RepriceCartInvocableSynchronous.PriceInfo(50, 50, 'USD')
        );
        RepriceCartInvocableSynchronous.pricer = mock;

        RepriceCartInvocableSynchronous.Request req = new RepriceCartInvocableSynchronous.Request();
        req.cartId = cart.Id;

        Test.startTest();
        List<RepriceCartInvocableSynchronous.Result> results =
            RepriceCartInvocableSynchronous.repriceCarts(
                new List<RepriceCartInvocableSynchronous.Request>{ req }
            );
        Test.stopTest();

        Assert.areEqual(1, results.size(), 'one result per request');
        Assert.areEqual(true, results[0].success, 'should succeed');
        Assert.areEqual(2, results[0].itemsRepriced, 'both items repriced');
        Assert.areEqual(2, mock.callCount, 'pricer called once per line');

        Map<Id, CartItem> updated = new Map<Id, CartItem>([
            SELECT Id, Product2Id, Quantity, SalesPrice, ListPrice,
                   TotalPrice, TotalLineAmount, TotalListPrice
            FROM CartItem WHERE CartId = :cart.Id
        ]);

        for (CartItem ci : updated.values()) {
            if (ci.Product2Id == product1.Id) {
                Assert.areEqual(97, ci.SalesPrice, 'P1 unit price');
                Assert.areEqual(100, ci.ListPrice, 'P1 list price');
                Assert.areEqual(194, ci.TotalPrice, 'P1 total = 97 * 2');
                Assert.areEqual(194, ci.TotalLineAmount, 'P1 total line = 97 * 2');
                Assert.areEqual(200, ci.TotalListPrice, 'P1 total list = 100 * 2');
            } else if (ci.Product2Id == product2.Id) {
                Assert.areEqual(50, ci.SalesPrice, 'P2 unit price');
                Assert.areEqual(50, ci.ListPrice, 'P2 list price');
                Assert.areEqual(150, ci.TotalPrice, 'P2 total = 50 * 3');
            }
        }
    }

    @IsTest
    static void skipsLineWhenPricerReturnsNull() {
        loadFixtures();
        WebCart cart = buildCartWithItems(2, 3);

        MockPricer mock = new MockPricer();
        // Only product1 has a price; product2 returns null (simulates no price).
        mock.priceMap.put(
            String.valueOf(product1.Id),
            new RepriceCartInvocableSynchronous.PriceInfo(97, 97, 'USD')
        );
        RepriceCartInvocableSynchronous.pricer = mock;

        RepriceCartInvocableSynchronous.Request req = new RepriceCartInvocableSynchronous.Request();
        req.cartId = cart.Id;

        Test.startTest();
        List<RepriceCartInvocableSynchronous.Result> results =
            RepriceCartInvocableSynchronous.repriceCarts(
                new List<RepriceCartInvocableSynchronous.Request>{ req }
            );
        Test.stopTest();

        Assert.areEqual(true, results[0].success);
        Assert.areEqual(1, results[0].itemsRepriced, 'only one line repriced');
        Assert.areEqual(2, mock.callCount, 'pricer still called for both lines');

        Map<Id, CartItem> updated = new Map<Id, CartItem>([
            SELECT Id, Product2Id, SalesPrice
            FROM CartItem WHERE CartId = :cart.Id
        ]);
        for (CartItem ci : updated.values()) {
            if (ci.Product2Id == product1.Id) {
                Assert.areEqual(97, ci.SalesPrice, 'P1 was repriced');
            } else {
                Assert.areEqual(0, ci.SalesPrice, 'P2 left untouched (no price)');
            }
        }
    }

    @IsTest
    static void succeedsOnEmptyCart() {
        loadFixtures();
        WebCart cart = new WebCart(
            Name = 'Empty Cart',
            WebStoreId = testStore.Id,
            AccountId = testAccount.Id
        );
        insert cart;

        MockPricer mock = new MockPricer();
        RepriceCartInvocableSynchronous.pricer = mock;

        RepriceCartInvocableSynchronous.Request req = new RepriceCartInvocableSynchronous.Request();
        req.cartId = cart.Id;

        Test.startTest();
        List<RepriceCartInvocableSynchronous.Result> results =
            RepriceCartInvocableSynchronous.repriceCarts(
                new List<RepriceCartInvocableSynchronous.Request>{ req }
            );
        Test.stopTest();

        Assert.areEqual(true, results[0].success, 'empty cart is a success');
        Assert.areEqual(0, results[0].itemsRepriced);
        Assert.areEqual(0, mock.callCount, 'pricer should not be called');
    }

    @IsTest
    static void failsGracefullyWhenCartNotFound() {
        loadFixtures();

        // Build a syntactically valid WebCart Id that doesn't exist.
        Id fakeCartId = '0a6000000000001AAA';

        MockPricer mock = new MockPricer();
        RepriceCartInvocableSynchronous.pricer = mock;

        RepriceCartInvocableSynchronous.Request req = new RepriceCartInvocableSynchronous.Request();
        req.cartId = fakeCartId;

        Test.startTest();
        List<RepriceCartInvocableSynchronous.Result> results =
            RepriceCartInvocableSynchronous.repriceCarts(
                new List<RepriceCartInvocableSynchronous.Request>{ req }
            );
        Test.stopTest();

        Assert.areEqual(false, results[0].success, 'should fail');
        Assert.isNotNull(results[0].errorMessage, 'error message populated');
        Assert.areEqual(0, results[0].itemsRepriced);
    }

    @IsTest
    static void handlesBulkRequests() {
        loadFixtures();
        // Each cart needs its own account — the platform enforces a unique
        // (Account, WebStore, Status) constraint, so two carts on the same
        // account in the same WebStore can't coexist in the default status.
        Account secondAccount = new Account(Name = 'Test Account 2');
        insert secondAccount;

        WebCart cart1 = buildCartWithItems(1, 1);
        WebCart cart2 = buildCartWithItems(2, 2, secondAccount.Id);

        MockPricer mock = new MockPricer();
        mock.priceMap.put(
            String.valueOf(product1.Id),
            new RepriceCartInvocableSynchronous.PriceInfo(10, 10, 'USD')
        );
        mock.priceMap.put(
            String.valueOf(product2.Id),
            new RepriceCartInvocableSynchronous.PriceInfo(20, 20, 'USD')
        );
        RepriceCartInvocableSynchronous.pricer = mock;

        RepriceCartInvocableSynchronous.Request r1 = new RepriceCartInvocableSynchronous.Request();
        r1.cartId = cart1.Id;
        RepriceCartInvocableSynchronous.Request r2 = new RepriceCartInvocableSynchronous.Request();
        r2.cartId = cart2.Id;

        Test.startTest();
        List<RepriceCartInvocableSynchronous.Result> results =
            RepriceCartInvocableSynchronous.repriceCarts(
                new List<RepriceCartInvocableSynchronous.Request>{ r1, r2 }
            );
        Test.stopTest();

        Assert.areEqual(2, results.size(), 'one result per request');
        Assert.areEqual(true, results[0].success);
        Assert.areEqual(true, results[1].success);
        Assert.areEqual(2, results[0].itemsRepriced);
        Assert.areEqual(2, results[1].itemsRepriced);
    }

    @IsTest
    static void skipsLineWhenPriceCurrencyDiffersFromCart() {
        // Only meaningful in multi-currency orgs; in single-currency orgs the
        // production guard short-circuits because cartCurrency is null.
        if (!UserInfo.isMultiCurrencyOrganization()) {
            return;
        }

        loadFixtures();
        WebCart cart = buildCartWithItems(2, 3);

        // Read whatever currency the platform assigned to the cart on insert,
        // and use that as the "matching" currency. This avoids fighting the
        // platform about post-insert CurrencyIsoCode updates.
        WebCart freshCart = [SELECT Id, CurrencyIsoCode FROM WebCart WHERE Id = :cart.Id LIMIT 1];
        String cartCurrency = freshCart.CurrencyIsoCode;
        Assert.isNotNull(cartCurrency, 'cart should have a currency in multi-currency org');

        // Pick a mismatched currency that is GUARANTEED to differ from
        // cartCurrency (Apex == on String is case-insensitive value compare,
        // so just appending a char produces a value that can never equal it).
        String mismatchedCurrency = cartCurrency + 'X';

        MockPricer mock = new MockPricer();
        // Product 1 returns matching currency → should reprice.
        mock.priceMap.put(
            String.valueOf(product1.Id),
            new RepriceCartInvocableSynchronous.PriceInfo(97, 100, cartCurrency)
        );
        // Product 2 returns a deliberately wrong currency → should be skipped.
        mock.priceMap.put(
            String.valueOf(product2.Id),
            new RepriceCartInvocableSynchronous.PriceInfo(50, 50, mismatchedCurrency)
        );
        RepriceCartInvocableSynchronous.pricer = mock;

        RepriceCartInvocableSynchronous.Request req = new RepriceCartInvocableSynchronous.Request();
        req.cartId = cart.Id;

        Test.startTest();
        List<RepriceCartInvocableSynchronous.Result> results =
            RepriceCartInvocableSynchronous.repriceCarts(
                new List<RepriceCartInvocableSynchronous.Request>{ req }
            );
        Test.stopTest();

        // Diagnostic context attached to assertions so a future failure surfaces
        // the actual values production saw rather than just "Expected X got Y".
        String ctx = ' [cartCurrency=' + cartCurrency
            + ', mismatchedCurrency=' + mismatchedCurrency
            + ', errorMessage=' + results[0].errorMessage + ']';

        Assert.areEqual(true, results[0].success, 'overall call still succeeds' + ctx);
        Assert.areEqual(1, results[0].itemsRepriced, 'only matching-currency line repriced' + ctx);
        Assert.isNotNull(results[0].errorMessage, 'mismatch surfaced via errorMessage' + ctx);
        Assert.isTrue(
            results[0].errorMessage.contains('currency mismatch'),
            'error message identifies the cause' + ctx
        );

        Map<Id, CartItem> updated = new Map<Id, CartItem>([
            SELECT Id, Product2Id, SalesPrice
            FROM CartItem WHERE CartId = :cart.Id
        ]);
        for (CartItem ci : updated.values()) {
            if (ci.Product2Id == product1.Id) {
                Assert.areEqual(97, ci.SalesPrice, 'matching-currency line was repriced');
            } else {
                Assert.areEqual(0, ci.SalesPrice, 'mismatched-currency line untouched');
            }
        }
    }
}