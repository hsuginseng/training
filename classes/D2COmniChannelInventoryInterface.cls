// This must implement the sfdc_checkout.CartInventoryValidation interface
// in order to be processed by the checkout flow and used for your Check Inventory integration.
global without sharing class D2COmniChannelInventoryInterface implements sfdc_checkout.CartInventoryValidation {
    /** When non-null in a test context, bypasses OCI and returns these quantities per SKU (omit a key to simulate not found). */
    @TestVisible
    private static Map<String, Decimal> testInventoryBySku;

    global sfdc_checkout.IntegrationStatus startCartProcessAsync(sfdc_checkout.IntegrationInfo jobInfo, ID cartId) {
        sfdc_checkout.IntegrationStatus integStatus = new sfdc_checkout.IntegrationStatus();
        Messages msgs = new Messages(jobInfo != null ? jobInfo.siteLanguage : null);

        try {
            // Source the SKU from Product2.StockKeepingUnit rather than the denormalized
            // CartItem.Sku — the latter isn't always populated (varies by add-to-cart path,
            // variation parents, bundles) and was triggering false "SKU required" errors
            // when two lines shared a Product2 but disagreed on Sku.
            // Multiple cart items can share a SKU, so aggregate quantity per SKU and keep
            // every cart item Id so each line gets its own error marker.
            Map<String, Decimal> quantitiesFromSalesforce = new Map<String, Decimal>();
            Map<String, List<Id>> skuToCartItemIds = new Map<String, List<Id>>();

            for (CartItem cartItem : [
                SELECT Id, Product2.StockKeepingUnit, Quantity
                FROM CartItem WHERE CartId = :cartId AND Type = 'Product'
            ]) {
                String sku = cartItem.Product2 != null ? cartItem.Product2.StockKeepingUnit : null;
                if (String.isBlank(sku)) {
                    return integrationStatusFailedWithCartValidationOutputError(
                        integStatus,
                        msgs.skuRequired(),
                        jobInfo,
                        cartId
                    );
                }
                Decimal running = quantitiesFromSalesforce.get(sku);
                quantitiesFromSalesforce.put(sku, (running == null ? 0 : running) + cartItem.Quantity);

                List<Id> ids = skuToCartItemIds.get(sku);
                if (ids == null) {
                    ids = new List<Id>();
                    skuToCartItemIds.put(sku, ids);
                }
                ids.add(cartItem.Id);
            }

            if (quantitiesFromSalesforce.isEmpty()) {
                return integrationStatusFailedWithCartValidationOutputError(
                    integStatus,
                    msgs.cartEmpty(),
                    jobInfo,
                    cartId
                );
            }

            Id webStoreId = [SELECT WebStoreId FROM WebCart WHERE Id = :cartId LIMIT 1].WebStoreId;
            Map<String, Decimal> quantitiesFromExternalService = getQuantitiesFromExternalService(
                quantitiesFromSalesforce.keySet(),
                webStoreId
            );

            // Collect per-item errors so each renders next to its corresponding cart line.
            List<CartItemError> itemErrors = new List<CartItemError>();

            for (String sku : quantitiesFromSalesforce.keySet()) {
                Decimal qtyRequested = quantitiesFromSalesforce.get(sku);
                Decimal qtyAvailable = quantitiesFromExternalService.get(sku);

                if (qtyAvailable == null) {
                    for (Id cartItemId : skuToCartItemIds.get(sku)) {
                        itemErrors.add(new CartItemError(cartItemId, msgs.productNotAvailable(sku)));
                    }
                } else if (qtyAvailable < qtyRequested) {
                    String message = msgs.notEnoughInventory(qtyAvailable.intValue());
                    for (Id cartItemId : skuToCartItemIds.get(sku)) {
                        itemErrors.add(new CartItemError(cartItemId, message));
                    }
                }
            }

            if (itemErrors.isEmpty()) {
                integStatus.status = sfdc_checkout.IntegrationStatus.Status.SUCCESS;
            } else {
                return integrationStatusFailedWithPerItemCartValidationOutputErrors(
                    integStatus,
                    itemErrors,
                    jobInfo,
                    cartId,
                    msgs
                );
            }
        } catch (Exception e) {
            return integrationStatusFailedWithCartValidationOutputError(
                integStatus,
                msgs.exception(e.getTypeName(), e.getMessage()),
                jobInfo,
                cartId
            );
        }
        return integStatus;
    }

    private Map<String, Decimal> getQuantitiesFromExternalService(Set<String> skus, Id webStoreId) {
        if (Test.isRunningTest() && testInventoryBySku != null) {
            Map<String, Decimal> simulated = new Map<String, Decimal>();
            for (String sku : skus) {
                if (testInventoryBySku.containsKey(sku)) {
                    simulated.put(sku, testInventoryBySku.get(sku));
                }
            }
            return simulated;
        }

        // Resolve SKUs → Product2 IDs (the inventory/levels endpoint takes Product2 IDs)
        Map<String, Id> skuToProductId = new Map<String, Id>();
        Map<Id, String> productIdToSku = new Map<Id, String>();
        for (Product2 p : [SELECT Id, StockKeepingUnit FROM Product2 WHERE StockKeepingUnit IN :skus]) {
            skuToProductId.put(p.StockKeepingUnit, p.Id);
            productIdToSku.put(p.Id, p.StockKeepingUnit);
        }
        if (skuToProductId.isEmpty()) {
            return new Map<String, Decimal>();
        }

        // Resolve location source for this webstore
        WebStoreInventorySource storeInventorySource = [
            SELECT LocationSourceId
            FROM WebStoreInventorySource
            WHERE WebStoreId = :webStoreId
            LIMIT 1
        ];

        // Environment-aware host + path (sandbox vs prod)
        Boolean isSandbox = URL.getOrgDomainUrl().toExternalForm().contains('.sandbox.');
        String siteHost = isSandbox
            ? 'hsusginseng--uat.sandbox.my.site.com'
            : 'www.hsuginseng.com';
        String webRuntimeBase = isSandbox ? '/d2c/webruntime' : '/webruntime';

        String productsCsv = String.join(new List<Id>(skuToProductId.values()), ',');
        String locationParam = String.valueOf(storeInventorySource.LocationSourceId);
        String scopeParam = EncodingUtil.urlEncode('webStoreId eq ' + webStoreId, 'UTF-8');

        String endpoint =
            'https://' + siteHost +
            webRuntimeBase + '/api/services/data/v66.0/commerce/inventory/levels' +
            '?products=' + productsCsv +
            '&locations=' + locationParam +
            '&scope=' + scopeParam +
            '&language=en-US' +
            '&asGuest=' + (UserInfo.getUserType() == 'Guest' ? 'true' : 'false') +
            '&includeRelatedProducts=false' +
            '&htmlEncode=false';

        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('GET');
        req.setHeader('Accept', 'application/json');

        HttpResponse res = new Http().send(req);

        if (res.getStatusCode() != 200) {
            throw new CalloutException(
                'inventory/levels call failed: HTTP ' + res.getStatusCode() + ' - ' + res.getBody()
            );
        }

        Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        List<Object> records = (List<Object>) parsed.get('totalInventory');

        Map<String, Decimal> response = new Map<String, Decimal>();
        if (records != null) {
            for (Object recObj : records) {
                Map<String, Object> rec = (Map<String, Object>) recObj;
                Id productId = (Id) rec.get('product2Id');
                String sku = productIdToSku.get(productId);
                if (sku != null) {
                    Object atoVal = rec.get('availableToOrder');
                    response.put(sku, atoVal == null ? 0 : (Decimal) atoVal);
                }
            }
        }

        return response;
    }

    /** Lightweight wrapper to keep cart item ID and message bundled as we build the per-item error list. */
    private class CartItemError {
        Id cartItemId;
        String message;
        CartItemError(Id cartItemId, String message) {
            this.cartItemId = cartItemId;
            this.message = message;
        }
    }

    /** Locale-aware shopper-facing message resolver. Defaults to English for any unrecognized site language. */
    private class Messages {
        private String lang;

        Messages(String siteLanguage) {
            // Normalize: anything that isn't zh_CN or zh_TW falls back to en
            if (siteLanguage == 'zh_CN' || siteLanguage == 'zh_TW') {
                this.lang = siteLanguage;
            } else {
                this.lang = 'en_US';
            }
        }

        String skuRequired() {
            if (lang == 'zh_CN') return '购物车中所有商品的 SKU 必须定义。';
            if (lang == 'zh_TW') return '購物車中所有商品的 SKU 必須定義。';
            return 'The SKUs for all products in your cart must be defined.';
        }

        String cartEmpty() {
            if (lang == 'zh_CN') return '您的购物车是空的。';
            if (lang == 'zh_TW') return '您的購物車是空的。';
            return 'Looks like your cart is empty.';
        }

        String productNotAvailable(String sku) {
            if (lang == 'zh_CN') return '商品 ' + sku + ' 暂不可用。';
            if (lang == 'zh_TW') return '商品 ' + sku + ' 暫不可用。';
            return 'Product ' + sku + ' is not available.';
        }

        String notEnoughInventory(Integer available) {
            if (lang == 'zh_CN') return '仅剩 ' + available + ' 件库存。';
            if (lang == 'zh_TW') return '僅剩 ' + available + ' 件庫存。';
            return 'Only ' + available + ' in stock.';
        }

        String summary(Integer issueCount) {
            if (lang == 'zh_CN') {
                if (issueCount == 1) return '购物车中有一件商品超出库存数量。';
                return '购物车中有 ' + issueCount + ' 件商品超出库存数量。';
            }
            if (lang == 'zh_TW') {
                if (issueCount == 1) return '購物車中有一件商品超出庫存數量。';
                return '購物車中有 ' + issueCount + ' 件商品超出庫存數量。';
            }
            if (issueCount == 1) return 'One item in your cart exceeds available stock.';
            return issueCount + ' items in your cart exceed available stock.';
        }

        String exception(String typeName, String message) {
            if (lang == 'zh_CN') return '发生 ' + typeName + ' 类型的异常：' + message;
            if (lang == 'zh_TW') return '發生 ' + typeName + ' 類型的例外:' + message;
            return 'An exception of type ' + typeName + ' has occurred: ' + message;
        }
    }

    private sfdc_checkout.IntegrationStatus integrationStatusFailedWithPerItemCartValidationOutputErrors(
        sfdc_checkout.IntegrationStatus integrationStatus,
        List<CartItemError> itemErrors,
        sfdc_checkout.IntegrationInfo jobInfo,
        Id cartId,
        Messages msgs
    ) {
        integrationStatus.status = sfdc_checkout.IntegrationStatus.Status.FAILED;

        Id backgroundOpId = jobInfo != null ? jobInfo.jobId : null;
        List<CartValidationOutput> errorsToInsert = new List<CartValidationOutput>();

        // Cart-level summary banner — renders at top of cart
        String summaryName = jobInfo != null
            ? (String) cartId + ':' + jobInfo.jobId + ':summary'
            : String.valueOf(cartId) + ':inventory:summary';
        errorsToInsert.add(new CartValidationOutput(
            BackgroundOperationId = backgroundOpId,
            CartId = cartId,
            Level = 'Error',
            Message = msgs.summary(itemErrors.size()).left(255),
            Name = summaryName.left(255),
            RelatedEntityId = cartId,
            Type = 'Inventory'
        ));

        // Per-item errors — render next to each affected line
        Integer idx = 0;
        for (CartItemError err : itemErrors) {
            idx++;
            String validationName = jobInfo != null
                ? (String) cartId + ':' + jobInfo.jobId + ':' + idx
                : String.valueOf(cartId) + ':inventory:' + idx;

            Id relatedEntityId = err.cartItemId != null ? err.cartItemId : cartId;

            errorsToInsert.add(new CartValidationOutput(
                BackgroundOperationId = backgroundOpId,
                CartId = cartId,
                Level = 'Error',
                Message = err.message.left(255),
                Name = validationName.left(255),
                RelatedEntityId = relatedEntityId,
                Type = 'Inventory'
            ));
        }

        insert errorsToInsert;
        return integrationStatus;
    }

    private sfdc_checkout.IntegrationStatus integrationStatusFailedWithCartValidationOutputError(
        sfdc_checkout.IntegrationStatus integrationStatus, String errorMessage, sfdc_checkout.IntegrationInfo jobInfo, Id cartId) {
            integrationStatus.status = sfdc_checkout.IntegrationStatus.Status.FAILED;
            Id backgroundOpId = jobInfo != null ? jobInfo.jobId : null;
            String validationName = jobInfo != null
                ? (String) cartId + ':' + jobInfo.jobId
                : String.valueOf(cartId) + ':inventory';
            CartValidationOutput cartValidationError = new CartValidationOutput(
                BackgroundOperationId = backgroundOpId,
                CartId = cartId,
                Level = 'Error',
                Message = errorMessage.left(255),
                Name = validationName.left(255),
                RelatedEntityId = cartId,
                Type = 'Inventory'
            );
            insert(cartValidationError);
            return integrationStatus;
    }
}