import { LightningElement, wire } from 'lwc';
import { getSessionContext } from 'commerce/contextApi';
import { useCheckoutComponent } from "commerce/checkoutApi";
import { CheckoutInformationAdapter } from "commerce/checkoutApi";
import { CartItemsAdapter } from 'commerce/cartApi';
import { CartCouponsAdapter } from "commerce/cartApi";

const CheckoutStage = {
    CHECK_VALIDITY_UPDATE: "CHECK_VALIDITY_UPDATE",
    REPORT_VALIDITY_SAVE: "REPORT_VALIDITY_SAVE",
    BEFORE_PAYMENT: "BEFORE_PAYMENT",
    PAYMENT: "PAYMENT",
    BEFORE_PLACE_ORDER: "BEFORE_PLACE_ORDER",
    PLACE_ORDER: "PLACE_ORDER",
};

export default class D2cCheckoutSentPurchaseDataToGA4 extends useCheckoutComponent(LightningElement){
    static renderMode = "light";
    _isLoggedIn = false;
    _cartItemsData = [];
    _checkoutInformationData = [];
    _purchaseDataToSend;
    _loyaltyCouponApplied = false;
    _couponCode = '';

    stageAction(checkoutStage) {
        switch (checkoutStage) {
        case CheckoutStage.BEFORE_PLACE_ORDER:
            return Promise.resolve(this.setOrderDataForGA4());
        case CheckoutStage.PLACE_ORDER:
            return Promise.resolve(this.checkValidity());
        default:
            return Promise.resolve(true);
        }
    }

    async checkValidity() {
        let purchaseDataSent = false;
        purchaseDataSent = await this.sendPurchaseDatatoGA4(JSON.parse(JSON.stringify(this._purchaseDataToSend)));
        if(this._purchaseDataToSend && purchaseDataSent) {
            return true;
        }else {
            //This covers scenarios where GA4 fails. 
            //We do not want to prevent a order placement due to GA4 logic issues.
            //the checkout mechanism is the simply used to cleanly submit data once.
            return true;
        }
    }

    async connectedCallback() {
        let sessionContext = await getSessionContext();
        this._isLoggedIn = sessionContext.isLoggedIn;
    }

    determineCouponCode(itemType, adjustmentAmount) {
        if(itemType == 'Bonus') {
            return 'BOGO';
        } else if(adjustmentAmount < 0) {
            return 'Promotion';
        } else {
            return '';
        }
    }

    async setOrderDataForGA4() {
        const cartItems = this._cartItemsData.cartItems;
        const cartSummaryData = this._checkoutInformationData.cartSummary;
        const orderReferenceNumber = this._checkoutInformationData.orderReferenceNumber;

        //Build the items portion of the GA4 purchase payload
        const items = cartItems.map((currentCartItem) => ({
            item_id: currentCartItem.cartItem.productDetails.sku,
            item_name: currentCartItem.cartItem.name.replace('"', ''),
            discount: Number(currentCartItem.cartItem.totalAdjustmentAmount) == 0 ? 0.00 : (Number(currentCartItem.cartItem.totalAdjustmentAmount) / Number(currentCartItem.cartItem.quantity))* -1.00,
            price: (Number(currentCartItem.cartItem.totalPrice) / Number(currentCartItem.cartItem.quantity)),
            quantity: Number(currentCartItem.cartItem.quantity),
            coupon: this.determineCouponCode(currentCartItem.cartItem.subType, Number(currentCartItem.cartItem.totalAdjustmentAmount))
        }));

        // Build the GA4 purchase payload
        const purchaseData = {
            currency: cartSummaryData.currencyIsoCode,
            customer_type: this._isLoggedIn ? 'returning' : 'new',
            value: Number(cartSummaryData.totalProductAmountAfterAdjustments),
            transaction_id: `${cartSummaryData.cartId}-${orderReferenceNumber}`,
            shipping: Number(cartSummaryData.totalChargeAmount),
            tax: Number(cartSummaryData.totalTaxAmount),
            coupon: this._loyaltyCouponApplied ?  'Loyalty Points' : this._couponCode,
            items: items,
        };

        this._purchaseDataToSend = purchaseData;
        return true;
    }

    sendPurchaseDatatoGA4(data) {
        //the first push clears the previous ecommerce object.
        if (typeof dataLayer !== 'undefined' && dataLayer) {
            dataLayer.push({ ecommerce: null });
            dataLayer.push({
            event: "purchase",
            ecommerce: data 
            });
        }
        return true;
    }

    @wire(CheckoutInformationAdapter)
        getCheckoutInformation({data, error}) {
            if (data) {
                this._checkoutInformationData = data;
            }
            else if (error) {
                console.warn('GA4-ChIn error: ', error);
            }
        }

    @wire(CartItemsAdapter)
        getCartItems({data, error}) {
            if (data) {
                this._cartItemsData = data;
            }
            else if (error) {
                console.warn('GA4-CaIt err0r: ', error);
            }
        }

    @wire(CartCouponsAdapter)
    getCartCoupons({data, error}) {
        if(data) {
            let loyaltyCouponId = data.cartCoupons?.coupons?.find(c => c.customFields[0].Loyalty_Coupon__c === true)?.cartCouponId;
            let couponCode = data.cartCoupons?.coupons[0]?.couponCode;
            if(loyaltyCouponId) {
                this._loyaltyCouponApplied = true;
            }
            if(couponCode) {
                this._couponCode = couponCode;
            }
        } else if(error) {
            console.warn('GA4-CaCo error: ', error);
        }
    }
}