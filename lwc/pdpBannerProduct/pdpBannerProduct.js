import { LightningElement, api } from 'lwc';

export default class PdpBannerProduct extends LightningElement {
	@api title;
	@api price;
	@api discountedPrice;
	@api benefits;
	@api productClass;

	get hasOriginalPrice(){ return this.price != null; }
	get hasDiscountedPrice(){ return this.discountedPrice != null; }
	get isVariationParent(){ return this.productClass == 'VariationParent'; }
	get showPricing(){ return !this.isVariationParent; }
}