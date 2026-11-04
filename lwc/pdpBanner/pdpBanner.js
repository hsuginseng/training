import { LightningElement, api, track, wire } from 'lwc';
import { NavigationMixin } from "lightning/navigation";
import NAME_FIELD from "@salesforce/schema/Product2.Name";
import { getObjectInfos } from 'lightning/uiObjectInfoApi';
import PRODUCT2_OBJECT from '@salesforce/schema/Product2';

export default class PdpBanner extends NavigationMixin(LightningElement) {
	
	productFieldTranslationMap;
    @wire(getObjectInfos, { objectApiNames: [ PRODUCT2_OBJECT ]})
	getProductSchemaInfo({ data, error }){
		if (data && data.results) {
			let objectInfo = data.results.reduce((map, obj) => (map[obj.result.apiName] = obj, map), {});
			let objectFieldMap = {};
			for (const field in objectInfo['Product2'].result.fields) {
				objectFieldMap[field] = objectInfo['Product2'].result.fields[field].label;
			}

			this.productFieldTranslationMap = objectFieldMap;

			// if(!this.pageDetailsGenerated && this.productFields){
			// 	let tempBenefits = this.generateBenefitsList(this.productFields);
			// 	this.benefits = tempBenefits;
		
			// 	let tempAccordions = this.generateAccordionList(this.productFields);
			// 	this.accordions = tempAccordions;
	
			// 	this.pageDetailsGenerated = true;
			// }
	
		}else if(error){
			//handleError
		}
	}

	set productFields(data){
		this._productFields = data;

		//Interval re-checks every 25 ms if the Field Translation Map is available from the @wire to circumvent race conditions
		let interval = setInterval(() => {
			if(this.productFieldTranslationMap){
				let tempBenefits = this.generateBenefitsList(this.productFields);
				this.benefits = tempBenefits;
		
				let tempAccordions = this.generateAccordionList(this.productFields);
				this.accordions = tempAccordions;
				
				clearInterval(interval);
			}
		}, 25);
	}
	get productFields(){ return this._productFields; }
	@track _productFields;

	@api
	set productDetail(data){
		//Page load incomplete, data not available - return
		if(!data){ return; }

		try {
			this._productDetail = JSON.parse(JSON.stringify(data));

			this.productFields = data.fields;
			this.productClass = data.productClass;

			let attributeSetInfo = data.attributeSetInfo;
			let variationAttributeSet = data.variationAttributeSet;
			let selectedVariationAttributes = variationAttributeSet.attributes;
			this.variationDisplayLabel = variationAttributeSet.developerName;
			this.variationProducts = data.variationInfo.attributesToProductMappings;
			let variationAttributeInfo = this.productDetail.variationInfo.variationAttributeInfo;

			let sizePimlyApiName = 'prop4d59d8ad33184545b83879cef6af1bef__c';
			let sizeVariantSequence;
			if(variationAttributeInfo[sizePimlyApiName]){ sizeVariantSequence = variationAttributeInfo[sizePimlyApiName].sequence; }

			if(this.variationProducts){
				let tempVariationProducts = JSON.parse(JSON.stringify(this.variationProducts));

				let canonicalKeyProductMap = tempVariationProducts.reduce(function(output, mapping){ output[mapping.canonicalKey] = mapping.productId; return output; }, {});
				this.canonicalKeyProductMap = canonicalKeyProductMap;

				let sequencedValidVariantCombinations = [];
				tempVariationProducts.forEach(variant => {
					variant.selectedAttributes.forEach(attribute => {
						if(!sequencedValidVariantCombinations[attribute.sequence]){ sequencedValidVariantCombinations[attribute.sequence] = {}; }
						let currentValidVariantCombinations = sequencedValidVariantCombinations[attribute.sequence];

						currentValidVariantCombinations[attribute.value] = currentValidVariantCombinations[attribute.value] || {};
						variant.selectedAttributes.forEach(attribute2 => {
							if(attribute2.sequence != attribute.sequence){
								currentValidVariantCombinations[attribute.value][attribute2.sequence] = currentValidVariantCombinations[attribute.value][attribute2.sequence] || [];
								currentValidVariantCombinations[attribute.value][attribute2.sequence].push(attribute2.value);
							}
						});
					});
				});
				
				this.sequencedVariantComboValidityMap = sequencedValidVariantCombinations;
			}

			let attributeSetKeys = Object.keys(attributeSetInfo);
			let attributeSetKey = attributeSetKeys[0];

			let attributeInfo = attributeSetInfo[attributeSetKey].attributeInfo;
			let attributeInfoKeys = Object.keys(attributeInfo);
			
			let variantDefinitions = {};
			let sequencedSelectedPropertyList = []
			attributeInfoKeys.forEach(key => {
				let definition = attributeInfo[key];
				let values = JSON.parse(JSON.stringify(definition.availableValues));
				values.sort();
				variantDefinitions[definition.sequence] = { label: definition.label, options: values };
				sequencedSelectedPropertyList[definition.sequence] = definition.apiName;
			});


			/* Generate complete set of variant option definition structures */
			/* initializes all options as enabled - cannot mark options as disabled until all have been generated */
			let variationList = [];
			let variantDefinitionKeys = Object.keys(variantDefinitions);
			variantDefinitionKeys.forEach(key => {
				let selectedVariantOptionProperty = sequencedSelectedPropertyList[key];
				let definition = variantDefinitions[key];

				definition.options = definition.options.map((value, index) => {
					return {'label': value, 'selected': value==selectedVariationAttributes[selectedVariantOptionProperty], 'index': index, 'disabled': false };
				});
				 
				variationList.push(definition);
			});
			/* Generate complete set of variant option definition structures */

			/* Mark incompatible options as disabled during initialization */
			variantDefinitionKeys.forEach(key => {
				let selectedVariantOption = variationList[key].options.find(option => option.selected );
				if(selectedVariantOption){
					let selectedOptionLabel = selectedVariantOption.label;
					let currentVariantSetValidity = this.sequencedVariantComboValidityMap[key][selectedOptionLabel];
					let varientSetIndexList = Object.keys(currentVariantSetValidity);
					varientSetIndexList.forEach(currSetIndex => {
						let variantSet = variationList[currSetIndex];
						variantSet.options.forEach(option => {
							option.disabled = !(currentVariantSetValidity[currSetIndex].includes(option.label));
						});
					});
				}
			});
			/* Mark incompatible options as disabled during initialization */

			this.variations = variationList;
		} catch(err){
			console.error(err);
		}
	}
	get productDetail(){ return this._productDetail || {}; }

	//productFields;
	productClass;
	
	@api ctaLabelAddToCart;
	@api outOfStockLabel;
	@api maxInCartLabel;
	@api title;
	@api price;
	@api discountedPrice;
	@api productId;
	@api variationDisplayLabel;
	@api variationProducts;
	@api variations;
	@api mediaGroups;
	@api accordions = [];
	@api benefits = [];
	canonicalKeyProductMap = {};
	sequencedVariantComboValidityMap = {};
	
	pageDetailsGenerated=false;

	generateAccordionItem(title, content){
		let accordionItem = { id: title, toggle: title, text: content };
		return accordionItem;
	}

	generateBenefitsList(productFields){
		let tempBenefits = [];

		if(productFields.Name){ tempBenefits.push({ id: 'basic-10', text: this.productFieldTranslationMap.Name + ': ' + productFields.Name }); }
		if(productFields.Brand__c){ tempBenefits.push({ id: 'basic-20', text: this.productFieldTranslationMap.Brand__c + ': ' + productFields.Brand__c }); }
		if(productFields.Origin__c){ tempBenefits.push({ id: 'basic-30', text: this.productFieldTranslationMap.Origin__c + ': ' + productFields.Origin__c }); }
		if(productFields.Root_Style__c){ tempBenefits.push({ id: 'basic-40', text: this.productFieldTranslationMap.Root_Style__c + ': ' + productFields.Root_Style__c }); }
		//if(Tea Style	[Missing]'){ tempBenefits.push({ id: 'basic-50', text: 'Tea Style	[Missing]' }); }
		if(productFields.Type){ tempBenefits.push({ id: 'basic-50', text: this.productFieldTranslationMap.Type + ': ' + productFields.Type }); }
		if(productFields.Flavor__c){ tempBenefits.push({ id: 'basic-60', text: this.productFieldTranslationMap.Flavor__c + ': ' + productFields.Flavor__c }); }
		if(productFields.Color__c){ tempBenefits.push({ id: 'basic-70', text: this.productFieldTranslationMap.Color__c + ': ' + productFields.Color__c }); }
		if(productFields.Material__c){ tempBenefits.push({ id: 'basic-80', text: this.productFieldTranslationMap.Material__c + ': ' + productFields.Material__c }); }
		if(productFields.Hair_Color__c){ tempBenefits.push({ id: 'basic-90', text: this.productFieldTranslationMap.Hair_Color__c + ': ' + productFields.Hair_Color__c }); }
		if(productFields.Grade__c){ tempBenefits.push({ id: 'basic-100', text: this.productFieldTranslationMap.Grade__c + ': ' + productFields.Grade__c }); }
		if(productFields.Age__c){ tempBenefits.push({ id: 'basic-110', text: this.productFieldTranslationMap.Age__c + ': ' + productFields.Age__c }); }
		if(productFields.Size__c){ tempBenefits.push({ id: 'basic-120', text: this.productFieldTranslationMap.Size__c + ': ' + productFields.Size__c }); }
		if(productFields.Net_Weight__c){ tempBenefits.push({ id: 'basic-130', text: this.productFieldTranslationMap.Net_Weight__c + ': ' + productFields.Net_Weight__c }); }
		if(productFields.Package_Type__c){ tempBenefits.push({ id: 'basic-140', text: this.productFieldTranslationMap.Package_Type__c + ': ' + productFields.Package_Type__c }); }
		if(productFields.Pack_Size__c){ tempBenefits.push({ id: 'basic-150', text: this.productFieldTranslationMap.Pack_Size__c + ': ' + productFields.Pack_Size__c }); }
		if(productFields.Count__c){ tempBenefits.push({ id: 'basic-160', text: this.productFieldTranslationMap.Count__c + ': ' + productFields.Count__c }); }
		if(productFields.Quantity__c){ tempBenefits.push({ id: 'basic-170', text: this.productFieldTranslationMap.Quantity__c + ': ' + productFields.Quantity__c }); }
		if(productFields.Capacity__c){ tempBenefits.push({ id: 'basic-10', text: this.productFieldTranslationMap.Capacity__c + ': ' + productFields.Capacity__c }); }
		if(productFields.Model_No__c){ tempBenefits.push({ id: 'basic-190', text: this.productFieldTranslationMap.Model_No__c + ': ' + productFields.Model_No__c }); }
		if(productFields.Watts__c){ tempBenefits.push({ id: 'basic-200', text: this.productFieldTranslationMap.Watts__c + ': ' + productFields.Watts__c }); }
		if(productFields.Shipping_Weight_Oz__c){ tempBenefits.push({ id: 'shipping-10', text: this.productFieldTranslationMap.Shipping_Weight_Oz__c + ': ' + productFields.Shipping_Weight_Oz__c }); }
		if(productFields.Dimensions__c){ tempBenefits.push({ id: 'shipping-20', text: this.productFieldTranslationMap.Dimensions__c + ': ' + productFields.Dimensions__c }); }
		if(productFields.Root_Id__c){ tempBenefits.push({ id: 'basic-210', text: this.productFieldTranslationMap.Root_Id__c + ': ' + productFields.Root_Id__c }); }
		if(productFields.StockKeepingUnit){ tempBenefits.push({ id: 'basic-220', text: this.productFieldTranslationMap.StockKeepingUnit + ': ' + productFields.StockKeepingUnit }); }

		return tempBenefits;
	}

	generateAccordionList(productFields){
		let tempAccordions = [];

		if(productFields.Description){ tempAccordions.push(this.generateAccordionItem(this.productFieldTranslationMap.Description, productFields.Description)); }
		if(productFields.Product_Benefits__c){ tempAccordions.push(this.generateAccordionItem(this.productFieldTranslationMap.Product_Benefits__c, productFields.Product_Benefits__c)); }
		if(productFields.Use_Instructions__c){ tempAccordions.push(this.generateAccordionItem(this.productFieldTranslationMap.Use_Instructions__c, productFields.Use_Instructions__c)); }
		if(productFields.Storage_Instructions__c){ tempAccordions.push(this.generateAccordionItem(this.productFieldTranslationMap.Storage_Instructions__c, productFields.Storage_Instructions__c)); }
		if(productFields.Category__c){ tempAccordions.push(this.generateAccordionItem(this.productFieldTranslationMap.Category__c, productFields.Category__c)); }
		if(productFields.Product_Features__c){ tempAccordions.push(this.generateAccordionItem(this.productFieldTranslationMap.Product_Features__c, productFields.Product_Features__c)); }	
		if(productFields.What_s_Included__c){ tempAccordions.push(this.generateAccordionItem(this.productFieldTranslationMap.What_s_Included__c, productFields.What_s_Included__c)); }	
		if(productFields.Ingredients__c){ tempAccordions.push(this.generateAccordionItem(this.productFieldTranslationMap.Ingredients__c, productFields.Ingredients__c)); }
		if(productFields.Recipe__c){ tempAccordions.push(this.generateAccordionItem(this.productFieldTranslationMap.Recipe__c, productFields.Recipe__c)); }
		if(productFields.Warnings__c){ tempAccordions.push(this.generateAccordionItem(this.productFieldTranslationMap.Warnings__c, productFields.Warnings__c)); }
		if(productFields.Disclaimer__c){ tempAccordions.push(this.generateAccordionItem(this.productFieldTranslationMap.Disclaimer__c, productFields.Disclaimer__c)); }

		return tempAccordions;
	}

	handleProductVariantSelected(event){
		let selectedProductId = this.canonicalKeyProductMap[event.detail.value];
		if(selectedProductId){
			this[NavigationMixin.Navigate]({
				type: 'standard__recordPage',
				attributes: { recordId: selectedProductId, objectApiName: 'Product2', actionName: 'view' }
			});
		}
	}
}