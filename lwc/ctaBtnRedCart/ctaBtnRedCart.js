import { LightningElement, api, track, wire } from 'lwc';
import { addItemToCart, CartItemsAdapter } from 'commerce/cartApi';
import { fetchCommerceInventoryLevels } from 'c/d2cInventoryUtility';

export default class CtaBtnRedCart extends LightningElement {
    @api ctaLabelAddToCart;
    @api outOfStockLabel;
    @api maxInCartLabel;
    @api quantitySelected;

    @track _availableToOrder = 0;
    @track _quantityInCart = 0;

    // The productId that each signal was last verified against.
    // Signals are only trusted when they match _productId.
    @track _inventoryVerifiedForId = null;
    @track _cartVerifiedForId = null;

    _productId;

    @api
    get productId() {
        return this._productId;
    }
    set productId(value) {
        if (value === this._productId) return;
        this._productId = value;
        // Invalidate both signals — neither has been verified for the new product
        this._inventoryVerifiedForId = null;
        this._cartVerifiedForId = null;
        this._availableToOrder = 0;
        this._quantityInCart = 0;
        this.refreshInventory();
        // If we already have cached cart data, re-run the check against the new productId
        this._recheckCartForCurrentProduct();
    }

    @wire(CartItemsAdapter)
    wiredCartItems({ data, error }) {
        // Stash the raw payload so we can re-evaluate it when productId changes
        this._lastCartData = data;
        this._lastCartError = error;
        this._recheckCartForCurrentProduct();
    }

    _recheckCartForCurrentProduct() {
        if (this._lastCartError) {
            this._cartVerifiedForId = null;
            this._quantityInCart = 0;
            return;
        }
        if (!this._lastCartData || !this._productId) {
            this._cartVerifiedForId = null;
            this._quantityInCart = 0;
            return;
        }
        this._quantityInCart = this._extractQuantityForProduct(this._lastCartData, this._productId);
        // Mark verified *for this specific productId* — if productId changes before
        // we re-check, this value goes stale and _cartChecked evaluates false.
        this._cartVerifiedForId = this._productId;
    }

    /**
     * Sums the quantity of cart items matching the given productId.
     * Cart payload shape: data.cartItems[].cartItem.{productId, quantity}
     */
    _extractQuantityForProduct(data, productId) {
        const wrappers = Array.isArray(data?.cartItems) ? data.cartItems : [];
        let total = 0;
        for (const wrapper of wrappers) {
            const item = wrapper?.cartItem;
            if (item?.productId === productId) {
                total += Number(item.quantity ?? 0);
            }
        }
        return total;
    }

    refreshInventory() {
        const id = this._productId;
        if (!id) {
            this._inventoryVerifiedForId = null;
            this._availableToOrder = 0;
            return;
        }
        fetchCommerceInventoryLevels([id])
            .then((inventoryByProductId) => {
                // Guard: if productId changed mid-flight, discard this response
                if (this._productId !== id) return;
                const inv = inventoryByProductId[id];
                this._availableToOrder = inv != null ? Number(inv.availableToOrder ?? 0) : 0;
                this._inventoryVerifiedForId = inv != null ? id : null;
            })
            .catch(() => {
                if (this._productId !== id) return;
                this._inventoryVerifiedForId = null;
                this._availableToOrder = 0;
            });
    }

    get _inventoryChecked() {
        return this._inventoryVerifiedForId != null
            && this._inventoryVerifiedForId === this._productId;
    }

    get _cartChecked() {
        return this._cartVerifiedForId != null
            && this._cartVerifiedForId === this._productId;
    }

    get _isFullyVerified() {
        return this._inventoryChecked && this._cartChecked;
    }

    get _remainingAvailable() {
        return Math.max(0, this._availableToOrder - this._quantityInCart);
    }

    get _canAddToCart() {
        if (!this._isFullyVerified) return false;
        const requested = Number(this.quantitySelected ?? 1);
        return this._remainingAvailable >= requested;
    }

    get effectiveCtaLabel() {
        if (this._isFullyVerified && !this._canAddToCart && this._quantityInCart > 0) {
            return this.maxInCartLabel || 'No More Available';
        }
        if (this._isFullyVerified && !this._canAddToCart) {
            return this.outOfStockLabel || 'Out of Stock';
        }
        return this.ctaLabelAddToCart;
    }

    get ctaDisabled() {
        return !this._canAddToCart;
    }

    handleAddToCart() {
        if (this.ctaDisabled) return;
        addItemToCart(this.productId, this.quantitySelected);
    }
}