import { LightningElement, api, track } from 'lwc';

export default class PdpBannerProduct extends LightningElement {
	@api variationValidityMap = {};
	@api variationTypeLabel = '[Placeholder]';
	@api variationProducts = [];
	@api
	get variationSets(){ return this._variationSets; }
	set variationSets(data){
		if(!data){ return; }
		let tempVariationSets = JSON.parse(JSON.stringify(data));
		tempVariationSets.forEach((variation, index) => {
			let selectedVariantOption = variation.options.find(option => option.selected);
			if(selectedVariantOption){
				selectedVariantOption.class = 'selected';
			}
		});
		
		this._variationSets = tempVariationSets;
	}
	@track _variationSets = [];

	@api ctaLabelAddToCart;
	@api outOfStockLabel;
	@api maxInCartLabel;
	@api productClass;
	@api quantities;
	@api productId;
	@api quantitySelected = 1;
	
	get allowCartActions(){ return this.productClass == 'Simple' || this.productClass == 'Variation'; }

	handleVariantOptionSelection(event) {

		let dataset = event.target.dataset;
		let variantLabel = dataset.variantLabel;
		let variantSetIndex = dataset.variantSetIndex;
		let variantIndex = dataset.variantIndex;
		let selected = dataset.selected=='true';

		if(!selected){
			let variantSet = this.variationSets[variantSetIndex];
			let variantSetOptions = variantSet.options;
			variantSetOptions.forEach(option => { option.selected=false; option.class=null });
			variantSetOptions[variantIndex].selected=true;
			variantSetOptions[variantIndex].class='selected';
		} else {
			//Option Already Selected, Do Nothing
		}

		let allVariantsSelected = this.variationSets.every(variationSet => variationSet.options.some(option => option.selected ));

		if(allVariantsSelected){
			//Utilize a 0-second timeout to await DOM rendering cycle
			setTimeout(() => {
				let selectedVariantButtons = Array.from(this.template.querySelectorAll('button[data-selected=true]'));
				let selectedProductCanonicalKey;
				selectedProductCanonicalKey = selectedVariantButtons.reduce((result, current) => 
					result + (!!result ? '_' : '') + this.variationSets[current.dataset.variantSetIndex].options[current.dataset.variantIndex].label, ''
				);

				this.dispatchEvent(new CustomEvent("productvariantselected", {detail: { value: selectedProductCanonicalKey }}));
			}, 0);
		} else {
			let currentVariantSetValidity = this.variationValidityMap[variantSetIndex];
			let currentVariantValidity = currentVariantSetValidity[variantLabel];

			let varientSetIndexList = Object.keys(currentVariantValidity);
			varientSetIndexList.forEach(currSetIndex => {
				let variantSet = this.variationSets[currSetIndex];

				variantSet.options.forEach(option => {
					option.disabled = !(currentVariantValidity[currSetIndex].includes(option.label));
				});
			});
		}
	}

	handleIncrementQuantity(event) {
		this.quantitySelected = this.quantitySelected + 1;
	}

	handleDecrementQuantity(event) {
		if(this.quantitySelected > 1) {
			this.quantitySelected = this.quantitySelected - 1;
		}
	}
}