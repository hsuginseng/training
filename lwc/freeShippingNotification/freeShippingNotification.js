import { LightningElement, wire } from 'lwc';
import { CartSummaryAdapter } from 'commerce/cartApi';

export default class FreeShippingNotification extends LightningElement {
    // cartId;
    message = "";
    standardShippingRemaining = "";
    // expediteShippingRemaining;
    freshGinsengWeightRemaining = "";
    shippingCategoryName = "";    

    @wire(CartSummaryAdapter)
    getCartSummary({ data, error }) {
        if (data) {
            // this.cartId = data.cartId;
            // console.log("cart info: " + JSON.stringify(data));
            this.shippingCategoryName = data.customFields[0]?.Shipping_Category_Name__c;
            this.standardShippingRemaining = data.customFields[0]?.Standard_Shipping_Amount_Remaining__c;
            // this.expediteShippingRemaining = data.customFields[0]?.Expedite_Shipping_Amount_Remaining__c;
            this.freshGinsengWeightRemaining = data.customFields[0]?.Fresh_Ginseng_Weight_Remaining__c;
            this.refreshMessage();
        }
        if (error) {
            console.warn('Shipping Notification Error: ',error + error.message ? error.message : '');
            // this.cartId = undefined;
        }
    }

    refreshMessage() {
        if (this.standardShippingRemaining != "" && this.freshGinsengWeightRemaining != "" && this.shippingCategoryName != "") {
            if (this.shippingCategoryName === 'Standard' || this.shippingCategoryName === 'StandardFree') {
                if (this.standardShippingRemaining <= 0) {
                    // console.log('standard free');
                    this.message = 'Congratulations, your cart qualifies for free shipping!';
                }

                else {
                    // console.log('standard');
                    this.message = 'Add $' + this.standardShippingRemaining + ' to your cart, excluding fresh ginseng products, to qualify for free shipping!';
                }
                    
            }
            else if (this.shippingCategoryName === 'Expedite' || this.shippingCategoryName === 'ExpediteFree') {
                if (this.freshGinsengWeightRemaining <= 0) {
                    // console.log('expedite free');
                    this.message = 'Congratulations, your cart qualifies for free shipping!';
                }
                       
                else {
                    // console.log('expedite');
                    this.message = 'Add ' + this.freshGinsengWeightRemaining + ' pound(s) of fresh ginseng to your cart to qualify for free shipping!';
                }
            }
        }
    }

    get showMessage() {
        this.refreshMessage();
        return '<strong>'+this.message+'</strong>';
    }
}