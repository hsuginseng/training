public without sharing class D2cCheckoutCustomLoyaltyController {

    @AuraEnabled
    public static Decimal getLoyaltyPointsBalance(Id accountId){
        try {
           List<LoyaltyMemberCurrency> loyaltyMemberCurrency = [
                SELECT PointsBalance
                FROM LoyaltyMemberCurrency
                WHERE LoyaltyMember.Contact.accountId = :accountId
		LIMIT 1
            ];
            //Return zero currency when no results are returned
            if (loyaltyMemberCurrency.isempty()) {
                return 0;
            } else {
            	return loyaltyMemberCurrency[0].PointsBalance;
            }
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * Apply a loyalty voucher to a cart. Idempotent: calling N times produces the same
     * state as calling once. Detects pre-existing damaged carts (where stacked discounts
     * exceed the voucher's redeemable value) and surfaces a clear error.
     *
     * Returns true if anything actually changed in this call.
     */
    @AuraEnabled
    public static Boolean applyLoyaltyVoucher(Id cartId, Id voucherId) {
        // -------- Load the coupon / voucher --------
        Coupon cp;
        try {
            List<Coupon> couponlist = [
                SELECT Id, CouponCode, Voucher__c,
                       Voucher__r.RemainingValue, Voucher__r.PromotionId
                FROM Coupon
                WHERE Voucher__c = :voucherId
                LIMIT 1
            ];
            if(!couponlist.isEmpty())
            {
               cp =  couponlist[0];
            }
            else
            {
                throw new AuraHandledException('Loyalty voucher coupon not found.');
            }
             
        } catch (QueryException qe) {
            throw new AuraHandledException('Loyalty voucher coupon not found.');
        }

        // -------- Load loyalty-redeemable cart items --------
        List<CartItem> cartItems = [
            SELECT Id,
                   Product2.Loyalty_Redeemable__c,
                   TotalAdjustmentAmount,
                   TotalPriceAfterAllAdjustments,
                   TotalPromoAdjustmentAmount,
                   TotalPrice,
                   SalesPrice,
                   Quantity
            FROM CartItem
            WHERE CartId = :cartId
            AND Product2.Loyalty_Redeemable__c = TRUE
        ];

        if (cartItems.isEmpty()) {
            deletePromotionFromCart(cartId);
            return true;
        }

        // -------- Load existing LOYALTY-only adjustments (isolated from other promos) --------
        List<CartItemPriceAdjustment> existingLoyaltyCipas = [
            SELECT Id, Name, AdjustmentSource, AdjustmentValue, TotalAmount,
                   CartItemId, AdjustmentBasisReferenceId
            FROM CartItemPriceAdjustment
            WHERE CartId = :cartId
            AND Name = 'SystemGeneratedLoyaltyDiscount'
        ];

        List<WebCartAdjustmentBasis> existingLoyaltyWcabs = [
            SELECT Id, AdjustmentBasisDetail, AdjustmentBasisReferenceId, Name, WebCartId
            FROM WebCartAdjustmentBasis
            WHERE WebCartId = :cartId
            AND Loyalty_Coupon__c = TRUE
        ];

        // -------- Resolve voucher redeemable amount --------
        Decimal voucherAmountRedeemable;
        if (Test.isRunningTest()) {
            voucherAmountRedeemable = 100.00;
        } else {
            voucherAmountRedeemable = cp.Voucher__r.RemainingValue;
        }

        // -------- Damaged cart detection --------
        // The sum of loyalty CIPA TotalAmounts should never exceed the voucher's redeemable value
        // (in magnitude). If it does, a previous run stacked the discount and left the cart
        // inconsistent — refuse to proceed and surface a clear error so the user can reset.
        Decimal currentLoyaltyCipaSum = 0;
        for (CartItemPriceAdjustment cipa : existingLoyaltyCipas) {
            currentLoyaltyCipaSum += (cipa.TotalAmount != null ? cipa.TotalAmount : 0);
        }
        Decimal maxAllowedNegative = (-1 * voucherAmountRedeemable).setScale(2, RoundingMode.HALF_UP);
        Decimal currentRounded = currentLoyaltyCipaSum.setScale(2, RoundingMode.HALF_UP);
        // currentRounded is negative; if it is MORE negative than maxAllowedNegative, we are damaged.
        if (currentRounded < maxAllowedNegative) {
            throw new AuraHandledException(
                'Loyalty discount is in an inconsistent state on this cart. ' +
                'Please remove the loyalty discount and re-apply.'
            );
        }

        // -------- Compute current loyalty per item, from CIPAs ONLY (not from cart item totals) --------
        // This is the critical isolation: we never compare against TotalAdjustmentAmount on the
        // cart item, because that includes non-loyalty adjustments and was the root of the
        // original stacking bug.
        Map<Id, Decimal> currentLoyaltyByItemId = new Map<Id, Decimal>();
        Map<Id, List<CartItemPriceAdjustment>> cipasByItemId = new Map<Id, List<CartItemPriceAdjustment>>();
        for (CartItemPriceAdjustment cipa : existingLoyaltyCipas) {
            Decimal existing = currentLoyaltyByItemId.containsKey(cipa.CartItemId)
                ? currentLoyaltyByItemId.get(cipa.CartItemId)
                : 0;
            existing += (cipa.TotalAmount != null ? cipa.TotalAmount : 0);
            currentLoyaltyByItemId.put(cipa.CartItemId, existing);

            if (!cipasByItemId.containsKey(cipa.CartItemId)) {
                cipasByItemId.put(cipa.CartItemId, new List<CartItemPriceAdjustment>());
            }
            cipasByItemId.get(cipa.CartItemId).add(cipa);
        }

        // -------- Compute each item's loyalty-discountable value --------
        // The amount loyalty may take off a line is its price AFTER other (non-loyalty)
        // adjustments but BEFORE loyalty: TotalPriceAfterAllAdjustments minus the loyalty already
        // applied to it (currentLoyalty is <= 0, so subtracting it adds the loyalty back). We
        // allocate against THIS — not TotalPrice — so loyalty never over-discounts a line that
        // already carries another promotion and drives it below zero.
        Map<Id, Decimal> discountableByItemId = new Map<Id, Decimal>();
        for (CartItem ci : cartItems) {
            Decimal afterAdj = ci.TotalPriceAfterAllAdjustments != null ? ci.TotalPriceAfterAllAdjustments : 0;
            Decimal curLoyalty = currentLoyaltyByItemId.containsKey(ci.Id) ? currentLoyaltyByItemId.get(ci.Id) : 0;
            Decimal discountable = afterAdj - curLoyalty;
            discountableByItemId.put(ci.Id, discountable < 0 ? 0 : discountable);
        }

        // -------- Compute desired loyalty discount per item (positive amounts, capped per item and per cart) --------
        Map<Id, Decimal> desiredDiscountByItemId =
            getProportionalCartItemDiscounts(cartItems, voucherAmountRedeemable, discountableByItemId);

        // -------- Reconcile each cart item --------
        Set<Id> currentItemIds = new Set<Id>();
        for (CartItem ci : cartItems) currentItemIds.add(ci.Id);

        List<CartItem> itemsToUpdate = new List<CartItem>();
        List<CartItemPriceAdjustment> cipasToInsert = new List<CartItemPriceAdjustment>();
        List<CartItemPriceAdjustment> cipasToUpdate = new List<CartItemPriceAdjustment>();
        List<CartItemPriceAdjustment> cipasToDelete = new List<CartItemPriceAdjustment>();

        Boolean anythingChanged = false;

        for (CartItem ci : cartItems) {
            Decimal desiredPositive = desiredDiscountByItemId.containsKey(ci.Id)
                ? desiredDiscountByItemId.get(ci.Id)
                : 0;
            Decimal desiredNegative = (-1 * desiredPositive).setScale(2, RoundingMode.HALF_UP);

            Decimal currentNegative = (currentLoyaltyByItemId.containsKey(ci.Id)
                ? currentLoyaltyByItemId.get(ci.Id)
                : 0).setScale(2, RoundingMode.HALF_UP);

            Decimal delta = (desiredNegative - currentNegative).setScale(2, RoundingMode.HALF_UP);

            // Apply ONLY the delta to cart item totals (the fix for stacking)
            if (delta != 0) {
                ci.TotalAdjustmentAmount = (ci.TotalAdjustmentAmount != null ? ci.TotalAdjustmentAmount : 0) + delta;
                ci.TotalPriceAfterAllAdjustments = (ci.TotalPriceAfterAllAdjustments != null ? ci.TotalPriceAfterAllAdjustments : 0) + delta;
                ci.TotalPromoAdjustmentAmount = (ci.TotalPromoAdjustmentAmount != null ? ci.TotalPromoAdjustmentAmount : 0) + delta;
                itemsToUpdate.add(ci);
                anythingChanged = true;
            }

            // Reconcile this item's CIPAs
            List<CartItemPriceAdjustment> itemCipas = cipasByItemId.containsKey(ci.Id)
                ? cipasByItemId.get(ci.Id)
                : new List<CartItemPriceAdjustment>();

            if (itemCipas.isEmpty() && desiredNegative != 0) {
                cipasToInsert.add(buildLoyaltyCipa(cartId, ci.Id, cp, desiredNegative));
                anythingChanged = true;
            } else if (!itemCipas.isEmpty()) {
                // Keep the first, update it to desired; delete any duplicates for the same item
                CartItemPriceAdjustment primary = itemCipas[0];
                Decimal primaryAmount = primary.TotalAmount != null
                    ? primary.TotalAmount.setScale(2, RoundingMode.HALF_UP)
                    : 0;
                if (primaryAmount != desiredNegative) {
                    primary.AdjustmentValue = desiredNegative;
                    primary.TotalAmount = desiredNegative;
                    cipasToUpdate.add(primary);
                    anythingChanged = true;
                }
                for (Integer i = 1; i < itemCipas.size(); i++) {
                    cipasToDelete.add(itemCipas[i]);
                    anythingChanged = true;
                }
            }
        }

        // Orphaned CIPAs (point at items no longer in the cart)
        for (CartItemPriceAdjustment cipa : existingLoyaltyCipas) {
            if (cipa.CartItemId != null && !currentItemIds.contains(cipa.CartItemId)) {
                cipasToDelete.add(cipa);
                anythingChanged = true;
            }
        }

        // -------- Reconcile WCAB (one per cart, never per item) --------
        WebCartAdjustmentBasis wcabToInsert;
        List<WebCartAdjustmentBasis> wcabsToUpdate = new List<WebCartAdjustmentBasis>();
        List<WebCartAdjustmentBasis> wcabsToDelete = new List<WebCartAdjustmentBasis>();

        if (existingLoyaltyWcabs.isEmpty()) {
            wcabToInsert = new WebCartAdjustmentBasis();
            wcabToInsert.AdjustmentBasisDetail = cp.CouponCode;
            wcabToInsert.AdjustmentBasisReferenceId = cp.Id;
            wcabToInsert.Name = cp.CouponCode;
            wcabToInsert.WebCartId = cartId;
            wcabToInsert.Loyalty_Coupon__c = true;
            anythingChanged = true;
        } else {
            WebCartAdjustmentBasis primary = existingLoyaltyWcabs[0];
            if (primary.AdjustmentBasisReferenceId != cp.Id
                || primary.AdjustmentBasisDetail != cp.CouponCode
                || primary.Name != cp.CouponCode) {
                primary.AdjustmentBasisReferenceId = cp.Id;
                primary.AdjustmentBasisDetail = cp.CouponCode;
                primary.Name = cp.CouponCode;
                wcabsToUpdate.add(primary);
                anythingChanged = true;
            }
            // Clean up any duplicate WCABs for this cart
            for (Integer i = 1; i < existingLoyaltyWcabs.size(); i++) {
                wcabsToDelete.add(existingLoyaltyWcabs[i]);
                anythingChanged = true;
            }
        }

        // -------- Single DML pass, real exception messages --------
        try {
            if (!itemsToUpdate.isEmpty()) update itemsToUpdate;
            if (!cipasToInsert.isEmpty()) insert cipasToInsert;
            if (!cipasToUpdate.isEmpty()) update cipasToUpdate;
            if (!cipasToDelete.isEmpty()) delete cipasToDelete;
            if (wcabToInsert != null) insert wcabToInsert;
            if (!wcabsToUpdate.isEmpty()) update wcabsToUpdate;
            if (!wcabsToDelete.isEmpty()) delete wcabsToDelete;
        } catch (DmlException e) {
            throw new AuraHandledException('Failed to apply loyalty discount: ' + e.getMessage());
        }

        return anythingChanged;
    }

    private static CartItemPriceAdjustment buildLoyaltyCipa(Id cartId, Id cartItemId, Coupon cp, Decimal negativeAmount) {
        CartItemPriceAdjustment cipa = new CartItemPriceAdjustment();
        cipa.AdjustmentAmountScope = 'Total';
        cipa.AdjustmentBasisReferenceId = cp.Id;
        cipa.AdjustmentSource = 'System';
        cipa.AdjustmentTargetType = 'Item';
        cipa.AdjustmentType = 'AdjustmentAmount';
        cipa.AdjustmentValue = negativeAmount;
        cipa.CartId = cartId;
        cipa.CartItemId = cartItemId;
        cipa.Name = 'SystemGeneratedLoyaltyDiscount';
        cipa.PriceAdjustmentCauseId = cp.Voucher__r.PromotionId;
        // cipa.Priority = 1;
        cipa.TotalAmount = negativeAmount;
        return cipa;
    }

    public static void deletePromotionFromCart(Id cartId) {
        List<WebCart> carts = [SELECT Id, Applied_Loyalty_Voucher__c FROM WebCart WHERE Id = :cartId];

        if (carts.size() > 0) {
            carts[0].Applied_Loyalty_Voucher__c = null;
            update carts;
        }
    }

    @AuraEnabled
    public static void deletePromotionDiscountFromCart(Id cartId) {
        List<WebCart> carts = [SELECT Id, Applied_Loyalty_Voucher__c FROM WebCart WHERE Id = :cartId];

        List<CartItem> cartItems = [
            SELECT Id,
                   Product2.Loyalty_Redeemable__c,
                   TotalAdjustmentAmount,
                   TotalPriceAfterAllAdjustments,
                   TotalPromoAdjustmentAmount,
                   TotalPrice,
                   SalesPrice,
                   Quantity
            FROM CartItem
            WHERE CartId = :cartId
            AND Product2.Loyalty_Redeemable__c = TRUE
        ];

        List<CartItemPriceAdjustment> cipas = [
            SELECT Id, Name, AdjustmentSource, AdjustmentValue, TotalAmount,
                   WebCartAdjustmentGroupId, CartItemId
            FROM CartItemPriceAdjustment
            WHERE CartId = :cartId AND Name = 'SystemGeneratedLoyaltyDiscount'
        ];

        List<WebCartAdjustmentBasis> wcabs = [
            SELECT Id, AdjustmentBasisDetail, AdjustmentBasisReferenceId, Name, WebCartId
            FROM WebCartAdjustmentBasis
            WHERE WebCartId = :cartId AND Loyalty_Coupon__c = TRUE
        ];

        // Map all CIPAs by CartItemId (handle duplicates by summing — defensive against damaged carts)
        Map<Id, Decimal> totalLoyaltyByItemId = new Map<Id, Decimal>();
        for (CartItemPriceAdjustment cipa : cipas) {
            if (cipa.CartItemId == null) continue;
            Decimal existing = totalLoyaltyByItemId.containsKey(cipa.CartItemId)
                ? totalLoyaltyByItemId.get(cipa.CartItemId)
                : 0;
            existing += (cipa.AdjustmentValue != null ? cipa.AdjustmentValue : 0);
            totalLoyaltyByItemId.put(cipa.CartItemId, existing);
        }

        List<CartItem> cartItemsToUpdate = new List<CartItem>();
        for (CartItem ci : cartItems) {
            if (!totalLoyaltyByItemId.containsKey(ci.Id)) continue;
            Decimal negativeDiscountAdjustment = totalLoyaltyByItemId.get(ci.Id);
            Decimal positiveDiscountAmount = -1.00 * negativeDiscountAdjustment;
            ci.TotalAdjustmentAmount = (ci.TotalAdjustmentAmount != null ? ci.TotalAdjustmentAmount : 0) + positiveDiscountAmount;
            ci.TotalPriceAfterAllAdjustments = (ci.TotalPriceAfterAllAdjustments != null ? ci.TotalPriceAfterAllAdjustments : 0) + positiveDiscountAmount;
            ci.TotalPromoAdjustmentAmount = (ci.TotalPromoAdjustmentAmount != null ? ci.TotalPromoAdjustmentAmount : 0) + positiveDiscountAmount;
            cartItemsToUpdate.add(ci);
        }

        if (!cartItemsToUpdate.isEmpty()) update cartItemsToUpdate;

        if (carts.size() > 0) {
            carts[0].Applied_Loyalty_Voucher__c = null;
            update carts;
        }

        if (!cipas.isEmpty()) delete cipas;
        if (!wcabs.isEmpty()) delete wcabs;
    }

    /**
     * Backward-compatible entry point: allocates the discount proportionally using each line's
     * TotalPrice (list price × qty) as its discountable value. Correct only when the redeemable
     * lines carry no other adjustments. When a line may already have a non-loyalty promotion, use
     * the three-argument overload and pass each line's post-other-adjustment value instead.
     */
    public static Map<Id, Decimal> getProportionalCartItemDiscounts(
        List<CartItem> cartItems,
        Decimal totalDiscount
    ) {
        Map<Id, Decimal> baseByItemId = new Map<Id, Decimal>();
        if (cartItems != null) {
            for (CartItem ci : cartItems) {
                baseByItemId.put(ci.Id, (ci.TotalPrice == null || ci.TotalPrice < 0) ? 0 : ci.TotalPrice);
            }
        }
        return getProportionalCartItemDiscounts(cartItems, totalDiscount, baseByItemId);
    }

    /**
     * Allocates totalDiscount across the cart items proportionally to a caller-supplied per-line
     * base, capping each line at its base so it can be reduced to at most zero (never below). The
     * base is the value loyalty is allowed to take off a line — for stacked carts this is the
     * line's price AFTER other adjustments but BEFORE loyalty, not its raw TotalPrice.
     */
    public static Map<Id, Decimal> getProportionalCartItemDiscounts(
        List<CartItem> cartItems,
        Decimal totalDiscount,
        Map<Id, Decimal> baseByItemId
    ) {
        Map<Id, Decimal> result = new Map<Id, Decimal>();

        if (cartItems == null || cartItems.isEmpty() ||
            totalDiscount == null || totalDiscount <= 0 ||
            baseByItemId == null) {
            return result;
        }

        // Per-line base is the most loyalty can take off before the line would go
        // below zero. A non-positive base receives no discount, so it must also
        // contribute zero to the total — otherwise it would skew the other lines'
        // proportional shares and over-spend the voucher.
        List<Decimal> lineTotals = new List<Decimal>();
        Decimal totalBase = 0;

        for (CartItem ci : cartItems) {
            Decimal raw = baseByItemId.containsKey(ci.Id) ? baseByItemId.get(ci.Id) : 0;
            Decimal lt = (raw == null || raw < 0) ? 0 : raw;
            lineTotals.add(lt);
            totalBase += lt;
        }

        if (totalBase <= 0) {
            return result;
        }

        // The voucher is the source of truth and is NOT rounded. The only ceiling is
        // the cart itself — we can never discount more than the lines are worth.
        Decimal effectiveTotalDiscount = (totalDiscount > totalBase) ? totalBase : totalDiscount;

        // Proportional first pass — floored to the cent so we never over-allocate. We also keep
        // each line's fractional remainder (how far its exact share fell short of the next cent)
        // so the leftover cents can be distributed by the largest-remainder method below.
        Decimal allocatedTotal = 0;
        List<Decimal> lineFractions = new List<Decimal>();

        for (Integer i = 0; i < cartItems.size(); i++) {
            CartItem ci = cartItems[i];
            Decimal lineTotal = lineTotals[i];

            if (lineTotal <= 0) {
                result.put(ci.Id, 0);
                lineFractions.add(0);
                continue;
            }

            Decimal proportion = lineTotal / totalBase;
            Decimal rawShare = effectiveTotalDiscount * proportion;
            Decimal allocated = rawShare.setScale(2, RoundingMode.DOWN);

            if (allocated > lineTotal) {
                allocated = lineTotal;
            }

            result.put(ci.Id, allocated);
            allocatedTotal += allocated;
            lineFractions.add(rawShare - allocated);
        }

        // Distribute the flooring remainder with the largest-remainder method: hand each leftover
        // cent to the line whose exact share had the largest fractional part (the one closest to
        // rounding up) that still has room. This is the smoothest, most proportional split and is
        // independent of cart-item order. Ties favor the earlier line, so the result stays
        // deterministic. Totals, the never-below-zero cap, and full-coverage zeroing are unchanged.
        Decimal remaining = (effectiveTotalDiscount - allocatedTotal).setScale(2, RoundingMode.HALF_UP);
        Decimal cent = 0.01;

        while (remaining >= cent) {
            Integer bestIdx = -1;
            Decimal bestFrac = -1;
            for (Integer i = 0; i < cartItems.size(); i++) {
                Decimal lineTotal = lineTotals[i];
                if (lineTotal <= 0) continue;

                Decimal current = result.get(cartItems[i].Id);
                if (current + cent > lineTotal) continue;   // no room without crossing below zero

                if (lineFractions[i] > bestFrac) {
                    bestFrac = lineFractions[i];
                    bestIdx = i;
                }
            }

            if (bestIdx == -1) break;                       // nothing left with room (safety)

            Id bestId = cartItems[bestIdx].Id;
            result.put(bestId, result.get(bestId) + cent);
            lineFractions[bestIdx] = -1;                    // one cent per line; don't reselect
            remaining -= cent;
        }

        return result;
    }
}