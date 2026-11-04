import { LightningElement, api, wire } from 'lwc';
import { useCheckoutComponent } from "commerce/checkoutApi";
import { notifyAndPollCheckout } from 'commerce/checkoutApi';
import { getSessionContext } from 'commerce/contextApi';
import { checkoutLoadAsyncPoll } from 'commerce/checkoutCartApi';
import { CheckoutInformationAdapter } from "commerce/checkoutApi";
import { updateShippingAddress } from "commerce/checkoutApi";
import { waitForCheckout } from "commerce/checkoutApi";
import { CartItemsAdapter } from "commerce/cartApi";
import { CartCouponsAdapter } from "commerce/cartApi";
import { getOrFetch } from 'c/dataCache';
import applyLoyaltyVoucher from '@salesforce/apex/D2cCheckoutCustomLoyaltyController.applyLoyaltyVoucher';
import getLoyaltyPointsBalance from '@salesforce/apex/D2cCheckoutCustomLoyaltyController.getLoyaltyPointsBalance';
import deletePromotionDiscountFromCart from '@salesforce/apex/D2cCheckoutCustomLoyaltyController.deletePromotionDiscountFromCart';

const CheckoutStage = {
    CHECK_VALIDITY_UPDATE: "CHECK_VALIDITY_UPDATE",
    REPORT_VALIDITY_SAVE: "REPORT_VALIDITY_SAVE",
    BEFORE_PAYMENT: "BEFORE_PAYMENT",
    PAYMENT: "PAYMENT",
    BEFORE_PLACE_ORDER: "BEFORE_PLACE_ORDER",
    PLACE_ORDER: "PLACE_ORDER",
};

export default class D2cCheckoutCustomLoyalty extends useCheckoutComponent(LightningElement) {
    @api flowApiName = 'Redeem_Loyalty_Points_Screen_Flow';
    @api signUpButtonText = '';
    @api signUpURL = '';
    @api signUpMessage = '';
    @api loyaltyAppliedMessage = '';
    @api deletePromotionTitle = 'Delete Points Title';
    @api deletePromotionLabel = 'Delete Points Label';
    @api pointsToDollarConversion = 10;
    @api freeShippingCategoryNamesString = '';
    isLoggedIn = false;
    showSpinner = false;
    displayFlow = false;
    displayRegisterMessage = false;
    delivery_group_0_selected_delivery_method = '';
    loyaltyVoucherId;
    loyaltyDiscount;
    loyaltyDiscountAppliedToCartItems;
    cartId;
    accountId;
    alreadyCalculating = false;
    _checkoutWireData;
    shipping_deliveryAddress;
    shipping_addressProvided;
    checkoutStatus;
    initialPageLoad = false;
    isNewLoyaltyDiscount = false;
    isLoyaltyCouponApplied = false;
    deliveryGroupCount;
    grandTotalAmount;
    isPlaceOrderSuccess = false;
    showSpinnerDeletePromotion = false;
    showSpinnerApplyPromotion = false;
    showSpinnerRecalcShipping = false;

    get flowInputVariables() {
        return [];
    }

    @api
    get shouldDisableDeletePointButton() {
        return !(this.isLoggedIn && this.loyaltyVoucherId);
    }

    @api
    get shouldShowSpinner() {
        return(this.showSpinner || this.showSpinnerDeletePromotion || this.showSpinnerApplyPromotion || this.showSpinnerRecalcShipping);
    }

    @api
    get shouldShowDeleteButton() {
        return(this.loyaltyVoucherId);
    }

    get freeShippingCategoryList() {
        return (this.freeShippingCategoryNamesString || '')
            .split(',')
            .map(name => name.trim().toLowerCase())
            .filter(Boolean);
    }

    async connectedCallback() {
        this.initialPageLoad = true;
        let sessionContext = await getSessionContext();
        this.isLoggedIn = sessionContext.isLoggedIn;
        this.displayRegisterMessage = !sessionContext.isLoggedIn;
    }

    // NOTE: disconnectedCallback can't await. The framework tears the component down
    // before triggerDeletePromotionFromCart resolves. Best-effort fire-and-forget here.
    disconnectedCallback() {
        if(this.isLoyaltyCouponApplied && !this.isPlaceOrderSuccess){
            this.triggerDeletePromotionFromCart();
        }
    }

    stageAction(checkoutStage) {
        switch (checkoutStage) {
        case CheckoutStage.BEFORE_PAYMENT:
            return Promise.resolve(this.confirmCartTotalNotNegative());
        case CheckoutStage.BEFORE_PLACE_ORDER:
            return Promise.resolve(this.confirmLoyaltyPointsDebit());
        default:
            return Promise.resolve(true);
        }
    }

    confirmCartTotalNotNegative() {
        if (this.grandTotalAmount != null && this.grandTotalAmount < 0) {
            this.dispatchUpdateErrorAsync({
                groupId: "Loyalty",
                type: "/commerce/errors/checkout-failure",
                exception: "Your loyalty redemption exceeds the order total. Please reduce the points redeemed and try again.",
            });
            return false;
        }
        return true;
    }

    async confirmLoyaltyPointsDebit() {
        if(!this.isLoggedIn || !this.loyaltyVoucherId || this.loyaltyDiscount === null || this.loyaltyDiscount === 0.00) {
            return true;
        }
        let availableLoyaltyPoints = await getLoyaltyPointsBalance({ accountId: this.accountId });
        let pointsToDebit = this.loyaltyDiscountAppliedToCartItems * -1 * this.pointsToDollarConversion;
        if(availableLoyaltyPoints < pointsToDebit) {
            this.dispatchUpdateErrorAsync({
                groupId: "Loyalty",
                type: "/commerce/errors/checkout-failure",
                exception: "Loyalty Points could not be redeemed.",
            });

            //a record-triggered flow on WebCart (Looking for a status of pending-closed on the WebCart) will 
            //handle the debiting of points. For the purposes of the checkout process, we merely want to 
            //confirm points availability before the order is placed.

            return false;
        }else {
            this.isPlaceOrderSuccess = true;
            return true;
        }
    }

    async handleDeletePromotionClick(){
        let shouldRecalcShipping = this.delivery_group_0_selected_delivery_method;
        this.showSpinnerDeletePromotion = true;
        this.alreadyCalculating = true;
        await this.triggerDeletePromotionFromCart();
        if (shouldRecalcShipping) {
            this.alreadyCalculating = true;
            await this.triggerShippingRecalculation();
            this.alreadyCalculating = true;
            this.alreadyCalculating = true;
            checkoutLoadAsyncPoll();
        }
        this.alreadyCalculating = false;
        this.showSpinnerDeletePromotion = false;
        window.location.reload();   
    }

    @wire(CartItemsAdapter)
    getCartItems({data, error}) {
        if(data) {
            const totalLoyaltyDiscount = data.cartItems.reduce(
                (sum, { cartItem }) => sum + (Number(cartItem?.customFields?.[0]?.Applied_Loyalty_Discount_Amount__c) || 0),
                0
            );
            this.loyaltyDiscountAppliedToCartItems = totalLoyaltyDiscount;

            // 422 circuit breaker: stop the livelock when checkout is unprocessable
            if (this.checkoutStatus === 422) {
                this.showSpinner = false;
                this.dispatchUpdateErrorAsync({
                    groupId: "Loyalty",
                    type: "/commerce/errors/checkout-failure",
                    exception: "Checkout could not be updated. Please refresh the page and try again.",
                });
                return;
            }

            if (this.checkoutStatus !== 422) {
                this.showSpinner = false;
            }

            // Don't fire while the flow handler is mid-flight; it owns the recalc sequence.
            if (this.deliveryGroupCount >= 1
                && totalLoyaltyDiscount === 0
                && this.loyaltyVoucherId
                && !this.isNewLoyaltyDiscount) {
                this.showSpinner = true;
                this.applyVoucherRecalcShipping();
            }
        } else if (error) {
            console.warn('cart items adapter error: ', error);
        }
    }

    @wire(CartCouponsAdapter)
    getCartCoupons({data, error}) {
        if(data) {
            let loyaltyCouponId = data.cartCoupons?.coupons?.find(c => c.customFields[0].Loyalty_Coupon__c === true)?.cartCouponId;
            if(loyaltyCouponId) {
                this.isLoyaltyCouponApplied = true;
            }
        } else if(error) {
            console.warn('cart coupons adapter error: ', error);
        }
    }

    @wire(CheckoutInformationAdapter)
    getCheckoutInformation({data, error}) {
        if (data && data != this._checkoutWireData) {
            this._checkoutWireData = data;
            this.delivery_group_0_selected_delivery_method = data.deliveryGroups?.items[0]?.selectedDeliveryMethod?.name;
            this.loyaltyVoucherId = data.customFields[0]?.Applied_Loyalty_Voucher_Id__c;
            this.loyaltyDiscount = data.cartSummary?.totalPromotionalAdjustmentAmount;
            this.grandTotalAmount = data.cartSummary?.grandTotalAmount;
            this.cartId = data.cartSummary?.cartId;
            this.accountId = data.cartSummary?.accountId;
            this.shipping_street = data.deliveryGroups?.items[0]?.deliveryAddress?.street;
            this.checkoutStatus = data.checkoutStatus;
            let shipping_city = data.deliveryGroups?.items[0]?.deliveryAddress?.city;
            let shipping_country = data.deliveryGroups?.items[0]?.deliveryAddress?.country;
            let shipping_firstName = data.deliveryGroups?.items[0]?.deliveryAddress?.firstName;
            let shipping_lastName = data.deliveryGroups?.items[0]?.deliveryAddress?.lastName;
            let shipping_name = data.deliveryGroups?.items[0]?.deliveryAddress?.name;
            let shipping_postalCode = data.deliveryGroups?.items[0]?.deliveryAddress?.postalCode;
            let shipping_region = data.deliveryGroups?.items[0]?.deliveryAddress?.region;
            let shipping_shipToPhoneNumber = data.deliveryGroups?.items[0]?.deliveryAddress?.shipToPhoneNumber;
            this.deliveryGroupCount = data.deliveryGroups?.count;

            // Only update shipping_deliveryAddress when we have a real address.
            // Prevents overwriting the user's real address with the tempNullAddress
            // when a mid-recalc poll snapshot is returned.
            if (shipping_city && shipping_postalCode && shipping_region) {
            this.shipping_deliveryAddress = {
                city: shipping_city,
                country: shipping_country,
                firstName: shipping_firstName,
                lastName: shipping_lastName,
                name: shipping_name,
                postalCode: shipping_postalCode,
                region: shipping_region,
                shipToPhoneNumber: shipping_shipToPhoneNumber,
                street: this.shipping_street
            };
            }

            let should_add_discount = false;
            if(this.loyaltyVoucherId) {
                if(this.loyaltyDiscountAppliedToCartItems === 0) {
                    //do nothing
                    should_add_discount = true;
                } else {
                    this.alreadyCalculating = false;
                    this.showSpinner = false;
                }
            }

            // 422 circuit breaker here too: don't kick off recalcs against a dead checkout
            if (this.checkoutStatus === 422) {
                this.showSpinner = false;
                return;
            }

            if(this.isLoggedIn) {
                if(!this.loyaltyVoucherId) {
                    this.displayFlow = true;
                } else {
                    // Skip when the flow handler is actively driving the recalc
                    if(this.deliveryGroupCount > 0
                        && should_add_discount === true
                        && !this.isNewLoyaltyDiscount) {
                        //recalc shipping w/ promotions applied to cart
                        getOrFetch(this.cartId + 'applyLoyaltyVoucher', () => this.applyVoucherRecalcShipping())
                            .then(result => {
                            })
                            .catch(error => {
                                console.warn(error);
                            })
                    }
                }
                //case: cart has loyalty discount, navigates to cart page from checkout. discount deleted.
                //resolution: check delivery method custom field for ship cat name, (bulder prop for list of free ship names)
                //if ship cat in name list, force ship refresh if free shipping on cat name but no free ship option on checkout screen
                //upon reentry.
                let deliveryMethodsList = data.deliveryGroups?.items
                    ?.find(dg => this.freeShippingCategoryList.includes(
                        (dg.customFields?.[0]?.Shipping_Category_Name__c || '').toLowerCase()
                    ))
                    ?.availableDeliveryMethods;
                if(deliveryMethodsList?.length) {
                    let freeDeliveryGroupList = deliveryMethodsList.filter(dm => Number(dm.shippingFee) === 0);
                    if(this.initialPageLoad && freeDeliveryGroupList !== undefined && freeDeliveryGroupList?.length === 0) {
                        this.showSpinnerRecalcShipping = true;
                        this.triggerShippingRecalculation();
                    }
                }
            } else {
                this.displayRegisterMessage = true;
            }
            
            //after all logic considerations, set this.initialPageLoad to false.
            this.initialPageLoad = false;
        } else if (error) {
            console.warn('checkout information error: ', error);
        }
    }

    async applyVoucherRecalcShipping() {
        if (this.alreadyCalculating) {
            return;
        }
            this.alreadyCalculating = true;
        try {
            let returnValue = await this.triggerApplyVoucherToCart();
            await this.notifyCheckoutOfUpdate();
            return returnValue;
        } catch (err) {
            // Surface the real error message (damaged cart, DML failure, etc.) so the user sees it
            const message = err?.body?.message || err?.message || 'Loyalty discount could not be applied.';
            this.dispatchUpdateErrorAsync({
                groupId: "Loyalty",
                type: "/commerce/errors/checkout-failure",
                exception: message,
            });
        } finally {
            // Always reset so we never zombie-out future recovery attempts
            this.alreadyCalculating = false;
        }
    }

    async triggerApplyVoucherToCart() {
        // Let exceptions propagate to applyVoucherRecalcShipping so they're surfaced to the user
        return await applyLoyaltyVoucher({ cartId: this.cartId, voucherId: this.loyaltyVoucherId });
    }

    async triggerDeletePromotionFromCart() {
        try {
            this.showSpinner = true;
            await deletePromotionDiscountFromCart({ cartId: this.cartId });
            checkoutLoadAsyncPoll();
            await this.notifyCheckoutOfUpdate();

        } catch(error) {
            console.error('error: ', error);
        }
    }

    //results in error after removing loyalty coupon from checkout
    async notifyCheckoutOfUpdate() {
        await notifyAndPollCheckout();
    }

    async handleFlowStatusChange(event) {
        if (event.detail.status !== 'FINISHED' && event.detail.status !== 'FINISHED_SCREEN') {
            return;
        }

            this.displayFlow = false;
        // Hold the gate up for the ENTIRE recalc sequence so the wires don't
        // race against us mid-flight.
        this.isNewLoyaltyDiscount = true;

        try {
            if (this.delivery_group_0_selected_delivery_method) {
                this.showSpinnerApplyPromotion = true;
                this.showSpinner = true;
                await this.triggerShippingRecalculation();

                checkoutLoadAsyncPoll();
            }

            await this.notifyCheckoutOfUpdate();
        } catch (err) {
            console.error('handleFlowStatusChange error: ', err);
        } finally {
            this.isNewLoyaltyDiscount = false;
            this.showSpinnerApplyPromotion = false;
        }
    }

    async triggerShippingRecalculation() {
        const shipping_deliveryGroup2 = {
            deliveryAddress: this.shipping_deliveryAddress
        };
        
        const tempNullAddress = {
            city: null,
            country: 'US',
            firstName: 'Temp',
            lastName: 'Name',
            name: 'Temp Name',
            postalCode: null,
            region: null,
            shipToPhoneNumber: null,
            street: '123 null st'
        };

        const null_shipping_deliveryGroup2 = {
            deliveryAddress: tempNullAddress
        };

        try {
            await waitForCheckout();
        await updateShippingAddress(null_shipping_deliveryGroup2);
        await waitForCheckout();
            await updateShippingAddress(shipping_deliveryGroup2);
        } catch (err) {
            console.error('triggerShippingRecalculation error: ', err);
            // Best-effort recovery: never leave DG0 sitting on the temp/null address
            try {
                await waitForCheckout();
        await updateShippingAddress(shipping_deliveryGroup2);
            } catch (restoreErr) {
                console.error('triggerShippingRecalculation address restore failed: ', restoreErr);
            }
        } finally {
            if(this.showSpinnerRecalcShipping === true) {
                await checkoutLoadAsyncPoll();
                this.showSpinnerRecalcShipping = false; 
            }
        }
    }
}