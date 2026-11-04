import { LightningElement, api, wire } from "lwc";
import { ProductPricingAdapter } from 'commerce/productApi';
import { NavigationMixin } from "lightning/navigation";
import { addItemToCart } from 'commerce/cartApi';	

export default class HomeRecommendedCarouselSlide extends NavigationMixin(LightningElement) {
	@api productId;
	@api imageUrl;
	@api imageAlt;
	@api brand;
	@api title;
	@api price;
	@api salePrice;
	@api allowsAddToCart;
	@api isOutOfStock;
	@api hasInventoryData;
	@api ctaText;
	@api ctaUrl;

	/**
	 * Disable the CTA when:
	 *   - the product is addable AND
	 *   - either we don't have inventory data yet (fail-closed) OR it's out of stock / max-in-cart
	 *
	 * Non-addable products keep the original behavior: button enabled, click navigates to PDP.
	 */
	get ctaDisabled() {
		if (this.allowsAddToCart !== true) {
			return false;
		}
		if (this.hasInventoryData !== true) return true;
		if (this.isOutOfStock === true || this.isOutOfStock === 'true') return true;
		return false;
	}

	get addToCartBlockedByInventory() {
		return this.ctaDisabled;
	}

	get hasOriginalPriceData(){ return this.price != null; }
	get hasSalePriceData(){ return this.salePrice != null; }
	get showPricing(){ return this.allowsAddToCart; }

	@wire(ProductPricingAdapter, { productId: '$productId' })
	retrieveProductData({data, error}){
		if(data){
			this.price = data.listPrice;
			this.salePrice = data.negotiatedPrice;
		} else if(error){

		}
	}

	connectedCallback(){
		this.generateProductCardUrl(this.productId);
	}

	generateProductCardUrl(productId){
		this.productId = productId;
		this[NavigationMixin.GenerateUrl]({
			type: 'standard__recordPage',
			attributes: {
				recordId: productId,
				objectApiName: 'Product2',
				actionName: 'view'
			}
		}).then((url) => {
			this.ctaUrl = url;
		});
	}

	handleClickCtaButton(event){
		if (this.ctaDisabled) {
			event.preventDefault();
			event.stopPropagation();
			return;
		}
		if(this.allowsAddToCart){
			addItemToCart(this.productId, 1);
		} else {
			this[NavigationMixin.Navigate]({
				type: 'standard__recordPage',
				attributes: {
					recordId: this.productId,
					objectApiName: 'Product2',
					actionName: 'view'
				}
			})
		}
	}
}