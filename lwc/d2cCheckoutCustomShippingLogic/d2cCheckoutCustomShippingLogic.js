import { LightningElement, wire, track, api } from 'lwc';
import { useCheckoutComponent } from "commerce/checkoutApi";
import { CheckoutInformationAdapter } from "commerce/checkoutApi";
import { notifyAndPollCheckout } from 'commerce/checkoutApi';
import { waitForCheckout } from "commerce/checkoutApi";
import { checkoutLoadAsyncPoll } from 'commerce/checkoutCartApi';
import Toast from 'lightning/toast';
import removeFreshProductsFromCart from '@salesforce/apex/D2cCheckoutCustomShippingLogicController.removeFreshProductsFromCart';

const CheckoutStage = {
    CHECK_VALIDITY_UPDATE: "CHECK_VALIDITY_UPDATE",
    REPORT_VALIDITY_SAVE: "REPORT_VALIDITY_SAVE",
    BEFORE_PAYMENT: "BEFORE_PAYMENT",
    PAYMENT: "PAYMENT",
    BEFORE_PLACE_ORDER: "BEFORE_PLACE_ORDER",
    PLACE_ORDER: "PLACE_ORDER",
};

export default class D2cCheckoutCustomShippingLogic extends useCheckoutComponent(LightningElement){
    shouldNotifyCustomer = false;
    cartId;
    showSpinner = false;
    wasToastShown = false;
    handlingRequest = false;
    error;
    @track areFreshProductsDeleted = false;
    @track freshGinsengSubtotal;
    @track isDeliveryInLower48;
    @api homePathName;
    @api cartPathName;

    stageAction(checkoutStage) {
        switch (checkoutStage) {
        case CheckoutStage.CHECK_VALIDITY_UPDATE:
            return Promise.resolve(this.checkValidity());
        case CheckoutStage.REPORT_VALIDITY_SAVE:
            return Promise.resolve(this.reportValidity());
        default:
            return Promise.resolve(true);
        }
    }

    checkValidity() {
        if(this.freshGinsengSubtotal > 0 && !this.isDeliveryInLower48) {
            return false;
        }else {
            return true;
        }
    }

    reportValidity() {
        if(this.freshGinsengSubtotal > 0 && !this.isDeliveryInLower48) {
            this.dispatchUpdateErrorAsync({
                groupId: "Shipping",
                type: "/commerce/errors/checkout-failure",
                exception: "Fresh ginseng cannot be shipped to your location.",
            });
            return false;   
        }else {
            return true;
        }
    }

    removeFreshProductsFromCart(cartId) {
        removeFreshProductsFromCart({ cartId: cartId })
            .then(data => {
                Toast.show({
                    label: 'Success',
                    message: 'Fresh products have been removed from your cart.',
                    variant: 'success',
                    mode: 'dismissible'
                }, this);

                const shouldRedirectToHome = data;
                
                //based on return value(true = cart record deleted, false = cart record exists)
                if(shouldRedirectToHome) {
                    this.handleRedirectToHomeWithTimeout();
                } else {
                    this.handleRefreshPageWithTimeout();
                }
            })
            .catch(error => {
                this.handleRedirectToCart();
            });
    }

    //refreshes page after removing fresh products
    handleRefreshPageWithTimeout() {
        setTimeout(async () => {
            this.handleReloadWindow();
        }, 2000);
    }
    
    //refreshes page after splitting fresh products
    async handleRefreshPage() {
        let refreshCheckoutData = await notifyAndPollCheckout();
        this.dispatchUpdateErrorAsync({
            groupId: "Loyalty",
            type: "/commerce/errors/checkout-failure",
            exception: "Loyalty points applying...",
        });
        this.dispatchUpdateErrorAsync({
            groupId: "Loyalty"
        });
    }

    handleRemoveFreshGinseng(){
        this.showSpinner = true;
        this.areFreshProductsDeleted = true;
        this.removeFreshProductsFromCart(this.cartId);
    }

    handleRedirectToHomeWithTimeout() {
        setTimeout(() => {
            let directory = this.homePathName;
            this.handleRedirect(directory);
        }, 2000);
    }

    handleRedirectToCart() {
        let directory = this.cartPathName;
        this.handleRedirect(directory);
    }

    handleRedirect(directory) {
        let origin = window.location.origin;
        let url = origin + directory;
        window.location.href = url;
    }

    handleReloadWindow(){
        window.location.reload();
    }
    
    async handleReloadWindowAsync(){
        await waitForCheckout();
        this.dispatchUpdateErrorAsync({
            groupId: "Loyalty",
            type: "/commerce/errors/checkout-failure",
            exception: "Loyalty points applying...",
        });
        this.dispatchUpdateErrorAsync({
            groupId: "Loyalty"
        });
        // await checkoutLoadAsyncPoll();
        window.location.reload();
    }

    showSecondShipmentToast(){
        Toast.show({
                label: 'Success',
                message: 'Fresh Ginseng Shipment Created',
                variant: 'success',
                mode: 'dismissible'
            }, this);
    }

    @wire(CheckoutInformationAdapter)
    getCheckoutInformation({data, error}) {
        if (data) {
            let productCount = data.cartSummary?.uniqueProductCount;
            let availableDeliveryMethods = data.deliveryGroups?.items[0]?.availableDeliveryMethods;
            let deliveryGroupCount = data.deliveryGroups?.count;
            let errorTypeIsShipping = (data.errors[0]?.type == '/commerce/integrations/shipping') ? true : false;
            let errorDetail = data.errors[0]?.detail;
            let loyaltyCart = data.customFields[0]?.Applied_Loyalty_Voucher_Id__c;
            this.freshGinsengSubtotal = data.customFields[0]?.Expedite_Shipping_Amount__c;
            this.isDeliveryInLower48 = data.customFields[0]?.Is_Destination_State_In_Lower_48__c;
            this.cartId = data.cartSummary?.cartId;

            // 422 short-circuit: don't race the loyalty component fixing a dead checkout
            if (data.checkoutStatus === 422) {
                if(errorDetail == 'Shipment must be split. Please refresh the page.') {
                    this.showSpinner = true;
                    this.handleReloadWindow();
                    return;
                }
                if(!this.isDeliveryInLower48 && this.freshGinsengSubtotal > 0 && !this.areFreshProductsDeleted && (availableDeliveryMethods.length > 0 || errorTypeIsShipping)) {
                    this.shouldNotifyCustomer = true;
                }
                else {
                    this.showSpinner = false;
                    return;
                }
            }

            try {
                // Reload branches are now guarded by !handlingRequest so the wire can't re-fire them
                // while a reload is already in flight.
                if(deliveryGroupCount > 1 && errorTypeIsShipping && this.isDeliveryInLower48 && !loyaltyCart && !this.handlingRequest) {
                    // this.handleRefreshPage();
                    this.showSpinner = true;
                    this.handlingRequest = true;
                    this.handleReloadWindow();
                }

                if(deliveryGroupCount > 1 && errorTypeIsShipping && this.isDeliveryInLower48 && loyaltyCart && !this.handlingRequest) {
                    this.showSpinner = true;
                    this.handlingRequest = true;
                    this.handleReloadWindowAsync();
                }

                if(errorTypeIsShipping && !errorDetail.includes('ginseng') && !this.handlingRequest) {
                    this.handleRefreshPage();
                    this.showSpinner = true;
                }

                if(deliveryGroupCount > 1 && !errorTypeIsShipping && this.isDeliveryInLower48 && availableDeliveryMethods.length == 0 && !this.wasToastShown) {
                    this.showSecondShipmentToast();
                    this.showSpinner = true;
                    this.wasToastShown = true;
                }

                if(deliveryGroupCount > 0 && !errorTypeIsShipping && availableDeliveryMethods.length > 0) {
                    this.showSpinner = false;
                }

                if(!this.areFreshProductsDeleted) {
                    if(productCount == 0) {
                        this.handleRedirectToHomeWithTimeout();
                    }
                    
                    if(!this.isDeliveryInLower48 && this.freshGinsengSubtotal > 0 && !this.areFreshProductsDeleted && (availableDeliveryMethods.length > 0 || errorTypeIsShipping)) {
                        this.shouldNotifyCustomer = true;
                    }
                }
            } catch (error) {
                this.error = this.reduceErrors(error);
                Toast.show({
                        label: 'Error',
                        message: this.error.join(', '),
                        variant: 'error',
                        mode: 'sticky'
                    }, this);
            }
        }
    }

    reduceErrors(errors) {
        if (!Array.isArray(errors)) errors = [errors];
        return errors
            .filter(e => !!e)
            .map(e => {
                if (e.body?.message) return e.body.message;       // AuraHandledException
                if (Array.isArray(e.body)) return e.body.map(x => x.message).join(', '); // page-level errors
                if (e.message) return e.message;                  // JS error
                return 'Unknown error';
            });
    }
}