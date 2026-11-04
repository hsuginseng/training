import { LightningElement, api } from 'lwc';
import { NavigationMixin } from "lightning/navigation";
import { addItemToCart } from 'commerce/cartApi';

export default class CategoryCard extends NavigationMixin(LightningElement){
	@api imageUrl;
	@api imageAlt;
	@api label;
	@api title;
	@api desc;
	@api price;
	@api salePrice;
	@api ctaText;
	@api ctaUrl;
	@api allowAddToCart;
	@api isOutOfStock;
	@api hasInventoryData;
	productId;

	get showPricing(){ return this.allowAddToCart; }

	/**
	 * Disable the CTA when:
	 *   - the product is addable AND
	 *   - either we don't have inventory data yet (fail-closed) OR it's out of stock / max-in-cart
	 *
	 * Non-addable products (e.g. VariationParent) keep the original behavior: button enabled,
	 * click navigates to the product page.
	 */
	get ctaDisabled() {
		if (this.allowAddToCart !== true) {
			return false;
		}
		if (this.hasInventoryData !== true) return true;
		if (this.isOutOfStock === true) return true;
		return false;
	}

	connectedCallback(){
		this.generateProductCardUrl(this.ctaUrl);
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
			return;
		}
		if(this.allowAddToCart){
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