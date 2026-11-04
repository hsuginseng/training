/**
 * RepriceCartInvocableSynchronous
 *
 * Synchronous reprice for an LWR B2B Commerce cart, exposed as a flow invocable.
 * Uses ConnectApi.CommerceStorePricing.getProductPrice (singular) per line item,
 * which returns in the calling transaction (no BackgroundOperation, no polling).
 *
 * Assumption:
 *   This invocable assumes unit price does NOT vary by quantity. It looks up
 *   the catalog/entitlement-resolved unit price for each product+account, then
 *   multiplies by the cart line's current quantity for the totals. If your
 *   store uses quantity-tier pricing where the per-unit price changes at
 *   quantity breaks, this is the WRONG tool — getProductPrice does not accept
 *   a quantity parameter and will not return tier-adjusted prices.
 *
 * Testability:
 *   The ConnectApi call is wrapped behind the IPricer interface so that tests
 *   can inject a mock without depending on any Salesforce-provided ConnectApi
 *   test hook. See RepriceCartInvocableSynchronousTest for usage.
 */
public with sharing class RepriceCartInvocableSynchronous {

    // -------- Pricing dependency (injectable for testing) --------

    public interface IPricer {
        /**
         * Returns null if no price is available for this product/account.
         * Otherwise returns a PriceInfo with both unitPrice and listPrice populated
         * (listPrice falls back to unitPrice if the source returns null for it).
         */
        PriceInfo getPrice(String webstoreId, String productId, String accountId);
    }

    public class PriceInfo {
        public Decimal unitPrice;
        public Decimal listPrice;
        public String currencyIsoCode;
        public PriceInfo(Decimal unitPrice, Decimal listPrice, String currencyIsoCode) {
            this.unitPrice = unitPrice;
            this.listPrice = listPrice;
            this.currencyIsoCode = currencyIsoCode;
        }
    }

    private class ConnectApiPricer implements IPricer {
        public PriceInfo getPrice(String webstoreId, String productId, String accountId) {
            ConnectApi.ProductPrice pp = ConnectApi.CommerceStorePricing.getProductPrice(
                webstoreId, productId, accountId
            );
            if (pp == null || pp.unitPrice == null) {
                return null;
            }
            Decimal unitVal = Decimal.valueOf(pp.unitPrice);
            Decimal listVal = (pp.listPrice != null) ? Decimal.valueOf(pp.listPrice) : unitVal;
            return new PriceInfo(unitVal, listVal, pp.currencyIsoCode);
        }
    }

    @TestVisible
    private static IPricer pricer = new ConnectApiPricer();

    // -------- Invocable surface --------

    public class Request {
        @InvocableVariable(required=true label='Cart ID')
        public Id cartId;
    }

    public class Result {
        @InvocableVariable(label='Success')
        public Boolean success;
        @InvocableVariable(label='Error Message')
        public String errorMessage;
        @InvocableVariable(label='Items Repriced')
        public Integer itemsRepriced;
    }

    @InvocableMethod(
        label='Reprice Cart (Synchronous)'
        description='Recalculates cart line item prices synchronously via ConnectApi.CommerceStorePricing.getProductPrice. Blocks until complete.'
        category='B2B Commerce'
    )
    public static List<Result> repriceCarts(List<Request> requests) {
        List<Result> results = new List<Result>();
        for (Request req : requests) {
            results.add(repriceOne(req.cartId));
        }
        return results;
    }

    // -------- Core logic --------

    private static Result repriceOne(Id cartId) {
        Result r = new Result();
        r.itemsRepriced = 0;
        try {
            // 1. Cart context
            WebCart cart = [
                SELECT Id, WebStoreId, AccountId, CurrencyIsoCode
                FROM WebCart
                WHERE Id = :cartId
                LIMIT 1
            ];

            // 2. Line items (products only — skip charges/adjustments)
            List<CartItem> items = [
                SELECT Id, Product2Id, Quantity, ListPrice, SalesPrice,
                       TotalPrice, TotalLineAmount, TotalListPrice
                FROM CartItem
                WHERE CartId = :cartId
                  AND Type = 'Product'
            ];

            if (items.isEmpty()) {
                r.success = true;
                return r;
            }

            String webstoreId = String.valueOf(cart.WebStoreId);
            String effectiveAccountId = String.valueOf(cart.AccountId);
            String cartCurrency = cart.CurrencyIsoCode;

            // 3. One pricing call per line — fetch unit price, multiply by qty,
            //    write back. N+1 by design; OBO carts are typically small enough
            //    that this is fine.
            List<CartItem> toUpdate = new List<CartItem>();
            Integer currencyMismatches = 0;
            for (CartItem ci : items) {
                PriceInfo pi = pricer.getPrice(
                    webstoreId,
                    String.valueOf(ci.Product2Id),
                    effectiveAccountId
                );

                if (pi == null) {
                    // No price returned for this product/account; skip the line
                    // rather than zeroing it out.
                    continue;
                }

                // Multi-currency guard: never apply a price that's denominated
                // in a different currency than the cart. cartCurrency may be
                // null in single-currency orgs — in that case, skip the check.
                if (cartCurrency != null
                    && pi.currencyIsoCode != null
                    && pi.currencyIsoCode != cartCurrency) {
                    currencyMismatches++;
                    continue;
                }

                ci.ListPrice       = pi.listPrice;
                ci.SalesPrice      = pi.unitPrice;
                ci.TotalListPrice  = pi.listPrice * ci.Quantity;
                ci.TotalPrice      = pi.unitPrice * ci.Quantity;
                ci.TotalLineAmount = pi.unitPrice * ci.Quantity;

                toUpdate.add(ci);
            }

            if (!toUpdate.isEmpty()) {
                update toUpdate;
            }

            r.success = true;
            r.itemsRepriced = toUpdate.size();
            if (currencyMismatches > 0) {
                r.errorMessage = currencyMismatches + ' line(s) skipped due to currency mismatch with cart (' + cartCurrency + ').';
            }
        } catch (Exception e) {
            r.success = false;
            r.errorMessage = e.getTypeName() + ': ' + e.getMessage();
        }
        return r;
    }
}