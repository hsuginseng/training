import { LightningElement, api, wire } from 'lwc';
import { ProductCollectionAdapter } from 'commerce/productApi';
import { CartItemsAdapter } from 'commerce/cartApi';
import { fetchCommerceInventoryLevels } from 'c/d2cInventoryUtility';

export default class HomeRecommended extends LightningElement {
	static renderMode = 'light';

	/** Map of product2 Id → inventory row; `availableToOrder` is what we use for stock / OOS. */
	_inventoryByProductId = {};
	_baseProducts = [];
	_quantityInCartByProductId = {};

	// Verification flags — fail-closed pattern. Drives hasInventoryData on each product.
	_inventoryVerified = false;
	_cartVerified = false;

	@api title = 'Recommended Products';
	@api ctaTextAddToCart;
	@api ctaTextSeeDetails;
	@api ctaTextOutOfStock;
	@api ctaTextNoMoreAvailable;
	@api set content(data){
		this._content = data;
		// try {
		// 	this.products=JSON.parse(this._content);
		// } catch(err){
		// 	console.error(err);
		// }
	} 
	get content(){ return this._content; }

	@api products;
	@api set productSkuList(data){
		try { this._productSkuList = JSON.parse(data); }
		catch(err){ console.error('Failed to parse Recommended Product SKU List', err); }
	}
	get productSkuList(){
		return this._productSkuList;
	}

	@wire(ProductCollectionAdapter, { skus: '$productSkuList' })
    retrieveProductData({ data, error }) {
        if (data) {
            const tempProducts = [];
            const productIds = [];
            data.products.forEach((product, index) => {
                if (product.success) {
                    let allowsAddToCart = (product.productClass == 'Variation' || product.productClass == 'Simple');
                    productIds.push(product.id);
                    tempProducts.push({
                        id: index,
                        productId: product.id,
                        imageUrl: product.defaultImage.url,
                        imageAlt: product.defaultImage.alternativeText,
                        brand: product.fields.Brand_Populated__c == 'true' ? product.fields.Brand__c : '',
                        title: product.fields.Name,
                        price: null,
                        salePrice: null,
                        allowsAddToCart: allowsAddToCart,
                        productClassAllowsAddToCart: allowsAddToCart,
                        ctaText: allowsAddToCart ? this.ctaTextAddToCart : this.ctaTextSeeDetails,
                        ctaUrl: '#',
                        availableToOrder: null,
                        hasInventoryData: false,
                        isOutOfStock: false,
                        isMaxInCart: false,
                        isTrulyOutOfStock: false,
                        quantityInCart: 0,
                        remainingAvailable: null
                    });
                }
            });

            this._baseProducts = tempProducts;
            // New product set arrived — reset inventory verification
            this._inventoryVerified = false;
            this._inventoryByProductId = {};

            if (productIds.length === 0) {
                this._inventoryByProductId = {};
                this._inventoryVerified = true;
                this.recomputeProducts();
                return;
            }

            fetchCommerceInventoryLevels(productIds)
                .then((inventoryByProductId) => {
                    this._inventoryByProductId = inventoryByProductId || {};
                    this._inventoryVerified = true;
                    this.recomputeProducts();
                })
                .catch((err) => {
                    console.error('homeRecommended fetchCommerceInventoryLevels', err);
                    this._inventoryByProductId = {};
                    this._inventoryVerified = false; // explicit fail-closed
                    this.recomputeProducts();
                });
        } else if (error) {
            console.log('error', error);
        }
    }

    @wire(CartItemsAdapter)
    wiredCartItems({ data, error }) {
        if (error) {
            this._cartVerified = false;
            this._quantityInCartByProductId = {};
            this.recomputeProducts();
            return;
        }
        if (!data) {
            this._cartVerified = false;
            this._quantityInCartByProductId = {};
            this.recomputeProducts();
            return;
        }
        this._quantityInCartByProductId = this.extractCartQuantitiesByProductId(data);
        this._cartVerified = true;
        this.recomputeProducts();
    }

    /**
     * Builds a productId → total-quantity-in-cart map from the CartItemsAdapter payload.
     * Cart payload shape: data.cartItems[].cartItem.{productId, quantity}
     */
    extractCartQuantitiesByProductId(data) {
        const wrappers = Array.isArray(data?.cartItems) ? data.cartItems : [];
        const map = {};
        for (const wrapper of wrappers) {
            const item = wrapper?.cartItem;
            const pid = item?.productId;
            if (!pid) continue;
            map[pid] = (map[pid] || 0) + Number(item.quantity ?? 0);
        }
        return map;
    }

    /**
     * Recomputes the displayed products list using the latest inventory snapshot
     * AND the latest cart-quantity snapshot. Safe to call any number of times —
     * fires whenever either source updates.
     *
     * Each product gets:
     *   - hasInventoryData: true ONLY when both inventory and cart wires have confirmed
     *     data and the product itself has an inventory record. Drives child fail-closed.
     *   - isOutOfStock: true when warehouse is empty OR cart already holds all available stock
     *   - isMaxInCart: true ONLY when the cart caused the depletion. Drives "No More Available" label.
     *   - isTrulyOutOfStock: true when the warehouse itself is empty regardless of cart.
     *
     * CTA label resolution:
     *   - capped by cart → "No More Available" label (or hardcoded fallback)
     *   - warehouse empty → "Out of Stock" label (or hardcoded fallback)
     *   - otherwise → default label (Add to Cart / See Details)
     */
    recomputeProducts() {
        if (!this._baseProducts || this._baseProducts.length === 0) {
            return;
        }
        const fullyVerified = this._inventoryVerified && this._cartVerified;

        this.products = this._baseProducts.map((p) => {
            if (!p.productClassAllowsAddToCart) {
                return {
                    ...p,
                    availableToOrder: null,
                    hasInventoryData: false,
                    isOutOfStock: false,
                    isMaxInCart: false,
                    isTrulyOutOfStock: false,
                    quantityInCart: 0,
                    remainingAvailable: null
                };
            }

            const inv = this._inventoryByProductId[p.productId];
            const hasInvRecord = inv != null;
            const availableToOrder = hasInvRecord ? Number(inv.availableToOrder ?? 0) : null;
            const inCart = Number(this._quantityInCartByProductId[p.productId] || 0);
            const remaining = hasInvRecord ? Math.max(0, availableToOrder - inCart) : null;

            const isTrulyOutOfStock = hasInvRecord && availableToOrder <= 0;
            const isCappedByCart = hasInvRecord && !isTrulyOutOfStock && inCart >= availableToOrder;
            const isOutOfStock = isTrulyOutOfStock || isCappedByCart;

            // Only flip true when both wires are verified AND this product has an inv record
            const hasInventoryData = fullyVerified && hasInvRecord;

            // Compute the right label, with hardcoded fallbacks so a missing Builder property
            // doesn't silently fall back to "Add to Cart" on a disabled button.
            const baseCtaText = p.productClassAllowsAddToCart ? this.ctaTextAddToCart : this.ctaTextSeeDetails;
            let resolvedCtaText = baseCtaText;
            if (isCappedByCart) {
                resolvedCtaText = this.ctaTextNoMoreAvailable || 'No More Available';
            } else if (isTrulyOutOfStock) {
                resolvedCtaText = this.ctaTextOutOfStock || 'Out of Stock';
            }

            return {
                ...p,
                availableToOrder,
                quantityInCart: inCart,
                remainingAvailable: remaining,
                hasInventoryData,
                isOutOfStock,
                isMaxInCart: isCappedByCart,
                isTrulyOutOfStock,
                ctaText: resolvedCtaText
            };
        });
    }
}