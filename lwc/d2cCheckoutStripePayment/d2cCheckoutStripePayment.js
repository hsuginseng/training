import { LightningElement, api, wire } from "lwc";
import { CheckoutInformationAdapter } from "commerce/checkoutApi";
import { useCheckoutComponent } from "commerce/checkoutApi";
import { postAuthorizePayment } from "commerce/checkoutApi";

const CheckoutStage = {
    CHECK_VALIDITY_UPDATE: "CHECK_VALIDITY_UPDATE",
    REPORT_VALIDITY_SAVE: "REPORT_VALIDITY_SAVE",
    BEFORE_PAYMENT: "BEFORE_PAYMENT",
    PAYMENT: "PAYMENT",
    BEFORE_PLACE_ORDER: "BEFORE_PLACE_ORDER",
    PLACE_ORDER: "PLACE_ORDER",
};

export default class D2CCheckoutStripePayment extends useCheckoutComponent(LightningElement){
    static renderMode = "light";

    billingAddress = {};

    @api
    invokePaymentConfirmation(){
        let stripePaymentComponent = document.querySelector('c-checkout-stripe-custom-payment');
        return stripePaymentComponent.confirmPayment();
    }

    /**
    * notify the container the child component has modified data to put in the form store
    * the container should start 'dirty form' processing:
    * - optionally stageAction on this and other components
    * - save form store data to the server
    * - report errors
    */
    /* dispatchCommit(): void */

    /**
    * notify the DataProvider to update the form with the supplied changes.
    * the DataProvider catches updateForm errors so components do not need to.
    * unlike most dispatch functions this one is awaitable.
    */
    /* dispatchUpdateAsync(formRequest: CheckoutFormRequest): Promise<void> */

    /**
    * specialized version of dispatchUpdateAsync for setting client side errors.
    * note: this will never reject or throw, so it's safe not to await if circumstances permit
    */
    /* dispatchUpdateErrorAsync(errorRequest: CheckoutException): Promise<void> */

    /**
    * notify the DataProvider to start 'final' processing (the place order button pressed)
    * returns a Promise to facilitate advanced payment integrations.
    */
    /* dispatchFinalizeAsync(): Promise<void> */

    /**
    * notify the DataProvider to call place order API
    * unlike most dispatch fns this one is awaitable.
    */
    /* dispatchPlaceOrderAsync(): Promise<OrderConfirmation> */

    /**
    * ask our container to change our display such as put us in summary mode
    */
    /* dispatchRequestAspect(desiredAspect: CheckoutContainerAspectRequest): void */

    stageAction(checkoutStage /*CheckoutStage*/) {
        switch (checkoutStage) {
            case CheckoutStage.CHECK_VALIDITY_UPDATE:
                return Promise.resolve(this.checkValidity());
            case CheckoutStage.REPORT_VALIDITY_SAVE:
                return Promise.resolve(this.reportValidity());
            case CheckoutStage.BEFORE_PAYMENT:
                //Invoke Payment Gateway
                let paymentConfirmationPromise = new Promise((resolve, reject) => {
                    this.invokePaymentConfirmation().then(async result => {                
                        const paymentsData = {
                            id: result.id,
                            uuid: result.client_secret,
                            paymentGatewayId: '0b0V500000000srIAA', //Custom Gateway Id
                            amount: {
                                value: result.amount,
                                currency: 'USD',
                            }
                        };
                        console.log('this.billingAddress in payment', this.billingAddress);

                        /*
                        const billingAddress = {
                            "name":"Alec Klein",
                            "street":"31 W Devon Ave",
                            "city":"Glendale Heights",
                            "region":"IL",
                            "country":"US",
                            "postalCode":"60139"
                        }
                        */
                
                        let res = await postAuthorizePayment(this.checkoutId, result.payment_method, this.billingAddress, paymentsData);

                        return resolve(res);
                    }).catch(error => {
                        return reject(error);
                    });
                });
                return Promise.resolve(paymentConfirmationPromise);
            default:
                return Promise.resolve(true);
        }
    }

    checkValidity(){ return true; }

    reportValidity(){ return true; }

    @wire(CheckoutInformationAdapter)
    getCheckoutInformation({data, error}) {
        if (data) {
            console.log('CheckoutInformationAdapter data', data);
            this.checkoutId = data.checkoutId;
            try {
                if(data.deliveryGroups.count > 0){
                    let checkoutAddress = data.deliveryGroups.items[0].deliveryAddress;
                    this.billingAddress = checkoutAddress;
                }
                console.log('this.billingAddress in wire', this.billingAddress);
            } catch(err){ console.log('Exception occurred while retrieving Checkout Information', err); }
        } else if (error) {
            console.log('CheckoutInformationAdapter error: ', error);
        }
    }
}