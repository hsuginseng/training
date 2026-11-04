import { LightningElement, api, wire } from 'lwc';
import { fetchCommerceInventoryLevels } from 'c/d2cInventoryUtility';
import { CartItemsAdapter } from 'commerce/cartApi';

export default class Category extends LightningElement {
	@api title = 'Healthy Food';
	@api text = 'Premium American Ginseng Supplements – American Ginseng, Herbal Products and Vitamins';
	@api imageAlt = 'Explore Our Story';
	@api imageUrl = '/public/assets/images/cat-landing.jpg';

	@api actionLabelFilters='Filters';
	@api filterModalActionLabelApplyFilters='Filter';
	@api filterModalActionLabelClearFilters='Clear Filters';
	@api actionLabelSortBy='Sort By';
	@api actionLabelNextPage='Next';
	@api actionLabelPreviousPage='Previous';
	@api cardSubLabelNumOptions='Options';
	@api ctaTextAddToCart;
	@api ctaTextSeeDetails;
	@api ctaTextOutOfStock;
	@api ctaTextNoMoreAvailable;
	@api selectedCategoryId;
	@api totalResults;
	@api resultsPerPage;
	@api currentPageNumber;
	@api isLoading;

	// Stash the raw inventory + base products so we can recompute when cart changes
	_inventoryByProductId = {};
	_baseProducts = [];
	_quantityInCartByProductId = {};

	// Verification flags — fail-closed pattern. Drives hasInventoryData on each product.
	_inventoryVerified = false;
	_cartVerified = false;

	@api set sortRules(data){
		this._sortRules = data;
	}
	get sortRules(){ return this._sortRules; }

	@api set filterResults(data){
		this._filterResults = data.filtersPanel?.categories?.selectedCategory?.items;
		this.selectedCategoryId = data.filtersPanel?.categories?.selectedCategory?.id;
	}
	get filterResults(){ return this._filterResults; }
	_filterResults;

	@api set productCardCollection(data){
		if(data){
			this._productCardCollection = data;
			console.log('product card collection: ');
			console.log(this._productCardCollection);
			// New product set arrived — reset inventory verification
			this._inventoryVerified = false;
			this._inventoryByProductId = {};

			let products = [];
			let loadingInterval = setInterval(() => {
				if(this.ctaTextAddToCart && this.ctaTextSeeDetails){
					this.productCardCollection.forEach((card) => {
						try { products.push(this.createProductFromCard(card)); }
						catch(err){ console.error(err); }
					});
					this.mergeInventoryIntoProducts(products);
					clearInterval(loadingInterval);
				}
			}, 25);
		}
	}
	get productCardCollection(){ return this._productCardCollection; }
	_productCardCollection = [];

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

	connectedCallback(){
		window.addEventListener('load', function(){
			let requestFullWidthPageEvent = new CustomEvent('fullwidthpagerequest', { bubbles: true, composed: true });
			document.dispatchEvent(requestFullWidthPageEvent);
		});

		let requestFullWidthPageEvent = new CustomEvent('fullwidthpagerequest', { bubbles: true, composed: true });
		document.dispatchEvent(requestFullWidthPageEvent);

	}

	createProductFromCard(card){
		let productVariationParentCtaText = this.ctaTextSeeDetails;
		let productSimpleCtaText = this.ctaTextAddToCart;
		const productClassVariationParent = 'VariationParent';
		const productClassVariation = 'Variation';
		const productClassSimple = 'Simple';

		let productVariant = card.productClass;
		let description;
		if(productVariant == productClassVariationParent){
			let numVariants = card.variationInfo.attributesToProductMappings.length;
			description = numVariants + ' ' + this.cardSubLabelNumOptions;
		}

		let brand;
		let hasBrand = card.fields.Brand_Populated__c && card.fields.Brand_Populated__c.value==='true';
		if(hasBrand){ brand = card.fields.Brand__c.value; }

		// `productClassAllowsAddToCart` captures category eligibility (Variation/Simple yes, VariationParent no).
		// `allowAddToCart` keeps its original meaning downstream; the safeguard now lives in CategoryCard via hasInventoryData.
		let output = {
			id: card.id,
			imageUrl: card.image.url,
			imageAlt: card.image.alternativeText,
			label: hasBrand ? brand : '',
			title: card.fields.Name.value,
			desc: description,
			price: card.prices.listingPrice,
			salePrice: card.prices.negotiatedPrice,
			ctaText: productVariant == productClassVariationParent ? productVariationParentCtaText : productSimpleCtaText,
			ctaUrl: card.id,
			productClassAllowsAddToCart: (productVariant == productClassVariation || productVariant == productClassSimple),
			allowAddToCart: (productVariant == productClassVariation || productVariant == productClassSimple)
		};

		return output;
	}

	mergeInventoryIntoProducts(baseProducts) {
		this._baseProducts = baseProducts;

		// Initial render before inventory data arrives — products visible, hasInventoryData false (child will fail-closed)
		this.products = baseProducts.map((p) => ({
			...p,
			availableToOrder: null,
			hasInventoryData: false,
			isOutOfStock: false,
			isMaxInCart: false,
			isTrulyOutOfStock: false
		}));

		const addableIds = baseProducts.filter((p) => p.productClassAllowsAddToCart).map((p) => p.id);
		if (addableIds.length === 0) {
			// Nothing is addable by product class — mark inventory "verified" so non-addable cards work normally
			this._inventoryVerified = true;
			this.recomputeProducts();
			return;
		}

		fetchCommerceInventoryLevels(addableIds)
			.then((inventoryByProductId) => {
				this._inventoryByProductId = inventoryByProductId || {};
				this._inventoryVerified = true;
				this.recomputeProducts();
			})
			.catch((err) => {
				console.error('category fetchCommerceInventoryLevels', err);
				this._inventoryByProductId = {};
				this._inventoryVerified = false; // explicit fail-closed
				this.recomputeProducts();
			});
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
	 *   - isMaxInCart: true ONLY when the cart caused the depletion (warehouse has stock,
	 *     cart holds it all). Drives the "No More Available" label.
	 *   - isTrulyOutOfStock: true when the warehouse itself is empty regardless of cart.
	 *
	 * CTA label resolution:
	 *   - capped by cart → "No More Available" label (if configured)
	 *   - warehouse empty → "Out of Stock" label (if configured)
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

			const inv = this._inventoryByProductId[p.id];
			const hasInvRecord = inv != null;
			const availableToOrder = hasInvRecord ? Number(inv.availableToOrder ?? 0) : null;
			const inCart = Number(this._quantityInCartByProductId[p.id] || 0);
			const remaining = hasInvRecord ? Math.max(0, availableToOrder - inCart) : null;

			const isTrulyOutOfStock = hasInvRecord && availableToOrder <= 0;
			const isCappedByCart = hasInvRecord && !isTrulyOutOfStock && inCart >= availableToOrder;
			const isOutOfStock = isTrulyOutOfStock || isCappedByCart;

			// Only flip true when both wires are verified AND this product has an inv record
			const hasInventoryData = fullyVerified && hasInvRecord;

			let resolvedCtaText = p.ctaText;
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

	@api products;
	filtersOpen = false;

    updateFiltersToggle(event) {
        this.filtersOpen = event.detail.filtersOpen;
    }

	catjsInitialized = false;
	renderedCallback() {
		if (this.catjsInitialized) {
			return;
		}
		this.catjsInitialized = true;
		document.documentElement.style.boxSizing = 'border-box';
		document.body.style.margin = 0;
		document.body.style.padding = 0;
	}
}