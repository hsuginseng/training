import { LightningElement, api, track, wire } from 'lwc';
import CURRENT_LANGUAGE from "@salesforce/i18n/lang";
import initializePaymentIntent from "@salesforce/apex/stripePaymentIntentCallouts.initializePaymentIntent";
import { CartSummaryAdapter } from "commerce/cartApi";
import { CheckoutInformationAdapter, CheckoutAddressAdapter } from 'commerce/checkoutApi';
  
const stripeElementsDefaultStyle = {
    base: { 
        color: '#32325d', fontFamily: '"Helvetica Neue", Helvetica, sans-serif',
        fontSmoothing: 'antialiased', fontSize: '16px', '::placeholder': { color: '#aab7c4' }
    },
    invalid: { color: '#fa755a', iconColor: '#fa755a' }
};

export default class CheckoutStripeCustomPayment extends LightningElement {
    stripe;
    elements;
    card;
    payment;
    isLoaded = false;
    initialPIJSON;
    cartGrandTotal;
    kwargs;
    clientSecret;
    paymentMethodSet;
    selectedPaymentMethod;

    checkoutId;

    @api
    confirmPayment(){
        return this.handlePayNow();
    }

    // not sure if needed, currently does nothing, but looking to find a way to create a PI once, then update
    // the PI on subsequent user selections/changes

    // Please note: if one payment option is selected and pay button is clicked, the PI must get updated or it will
    // error. This is becuase pay button modifies the PI to specify the exact payment method.
    initialPIValueSet = false;

    get currentStripeLocaleCode(){
        if(CURRENT_LANGUAGE=='en-US'){ return 'en'; }
        else if(CURRENT_LANGUAGE=='zh-CN'){ return 'zh'; }
        else if(CURRENT_LANGUAGE=='zh-TW'){ return 'zh-TW'; }

        return CURRENT_LANGUAGE;
    }

    handleLoadStripe(){
        if (this.clientSecret != null) {
            if(!this.isLoaded && this.template.querySelector('.stripe-card-container')){
                this.initializeStripe();
                this.isLoaded = true;
            }
        }
    }

    handleInitializePaymentIntent() {
        // Create a Map
        let piDataMap = {
            "automatic_payment_methods[enabled]" : "false",
            "payment_method_types[0]" : "alipay",
            "payment_method_types[1]" : "wechat_pay",
            "currency" : "usd",
            "amount" : Math.round(this.cartGrandTotal.toString())
        };

        this.kwargs = JSON.stringify(piDataMap);
    }

    @wire(initializePaymentIntent, { piDataString : "$kwargs" })
    createInitialPaymentIntent({data, error}) {
        if(data) {
            this.initialPIJSON = data;
            this.clientSecret = this.initialPIJSON.client_secret;
            this.paymentMethodSet = this.initialPIJSON.payment_method_types;
            //fire handleLoadStripe once ClientSecret is populated
            this.handleLoadStripe();
        } else if(error) {
            console.error('error initializing PI: ',error);
        }
    }

    async initializeStripe() {
        const script = document.createElement('script');
        script.src = 'https://js.stripe.com/v3/';
        script.async = true;
        script.onload = () => {
            this.stripe = Stripe('pk_test_51R2CYzLFNpFZrnxLsfYbndjOPkP5Z013IMqMfCAwDgt4nB5jr77vbmz981vg8aAaDSb9peAC1cww78rSEqCT5HWq00SBv2Y6cd', {
                locale: this.currentStripeLocaleCode
            });
            this.elements = this.stripe.elements({clientSecret: this.clientSecret});
            this.payment = this.elements.create('payment', {
                layout: {
                    type: 'accordion',
                    // Set a different default, or set to 0 to disable the
                    // "More" button and render all available Payment Methods
                    visibleAccordionItemsCount: 2
                }, style: stripeElementsDefaultStyle, paymentMethodOrder: this.paymentMethodSet
            });
            this.payment.mount(this.template.querySelector('.stripe-card-container'));

            this.payment.on('change', (event) => {
                if(event.complete) {
                    this.selectedPaymentMethod = event.value.type;
                }
            });
        };

        document.body.appendChild(script);
    }

    async verifyPaymentIntentStatus() {
        if (!this.stripe || !this.clientSecret) {
            throw new Error('Stripe or clientSecret is not initialized.');
        }

        const result = await this.stripe.retrievePaymentIntent(this.clientSecret);
        if (result.error) {
            console.error('Stripe retrievePaymentIntent error', result.error);
            throw result.error;
        }

        const paymentIntent = result.paymentIntent || result;
        console.log('Stripe retrieved PaymentIntent', paymentIntent);
        return paymentIntent;
    }
/*
    async verifyPaymentIntentStatusWithRetries(attempts = 10, delayMs = 1000) {
        for (let i = 0; i < attempts; i += 1) {
            const paymentIntent = await this.verifyPaymentIntentStatus();
            if (paymentIntent?.status === 'succeeded') {
                return paymentIntent;
            }
            if (paymentIntent?.status === 'requires_action' || paymentIntent?.status === 'processing') {
                await new Promise(resolve => setTimeout(resolve, delayMs));
                continue;
            }
            throw new Error('Stripe payment failed or returned unexpected status: ' + paymentIntent?.status);
        }
        throw new Error('Stripe payment did not reach succeeded status after ' + attempts + ' retries.');
    }

    handlePayNow() {
        let returnURL = window.location.href.substring(0, window.location.href.lastIndexOf('/')) + '/payment-landing';
        if(this.selectedPaymentMethod === "alipay") {
            return new Promise((resolve, reject) => {
                let confirmAliPayPaymentPromise = this.stripe.confirmAlipayPayment(
                    this.clientSecret, { return_url: returnURL }, { handleActions: false }
                );

                confirmAliPayPaymentPromise.then(async ({error, paymentIntent}) => {
                    if (error) {
                        console.error('Stripe Alipay confirm error', error);
                        return reject(error);
                    }

                    console.log('Stripe Alipay confirm result', paymentIntent);
                    if (paymentIntent.status === 'succeeded') {
                        return resolve(paymentIntent);
                    }

                    if (paymentIntent.status === 'requires_action') {
                        let stripePopupWindow = window.open(paymentIntent.next_action.alipay_handle_redirect.url,
                            'Authorize AliPay Payment', 'resizable=1,scrollbars=1,width=600px,height=800px');

                        let interval = setInterval(async () => {
                            try {
                                let queryString = stripePopupWindow.location.search;
                                let queryStringMap = new URLSearchParams(queryString);
                                let redirectStatus = queryStringMap.get('redirect_status');

                                if (redirectStatus) {
                                    clearInterval(interval);
                                    if (redirectStatus === 'succeeded') {
                                        setTimeout(() => { stripePopupWindow.close(); }, 3000);
                                        try {
                                            const verifiedIntent = await this.verifyPaymentIntentStatusWithRetries();
                                            return resolve(verifiedIntent);
                                        } catch (verifyError) {
                                            console.error('Stripe Alipay verification failed', verifyError);
                                            return reject(verifyError);
                                        }
                                    }
                                    stripePopupWindow.close();
                                    return reject(new Error('Alipay redirect failed: ' + redirectStatus));
                                }
                            } catch(err) {
                                console.warn('(Expected Exception) Could not access window.location, waiting for redirect', err);
                            }
                        }, 1000);
                        return;
                    }

                    return reject(new Error('Stripe Alipay payment returned unexpected status: ' + paymentIntent.status));
                }).catch(error => {
                    console.error('Stripe Alipay confirm promise error', error);
                    reject(error);
                });
            })
        } else if(this.selectedPaymentMethod === "wechat_pay") {
            return new Promise((resolve, reject) => {
                this.stripe.confirmWechatPayPayment(
                    this.clientSecret, {
                        payment_method_options: {
                            wechat_pay: {
                                // need to consider mobile as well. currently wechat is set up for desktop use
                                client: 'web',
                            }
                        },
                        return_url: returnURL
                    }
                ).then(async ({error, paymentIntent}) => {
                    if (error) {
                        console.error('Stripe WeChat confirm error', error);
                        return reject(error);
                    }

                    console.log('Stripe WeChat confirm result', paymentIntent);
                    if (paymentIntent.status === 'succeeded') {
                        return resolve(paymentIntent);
                    }

                    if (paymentIntent.status === 'requires_action' || paymentIntent.status === 'processing') {
                        try {
                            const verifiedIntent = await this.verifyPaymentIntentStatusWithRetries();
                            return resolve(verifiedIntent);
                        } catch (verifyError) {
                            console.error('Stripe WeChat verification failed', verifyError);
                            return reject(verifyError);
                        }
                    }

                    return reject(new Error('Stripe WeChat payment failed or returned unexpected status: ' + paymentIntent.status));
                }).catch(error => {
                    console.error('Stripe WeChat confirm promise error', error);
                    reject(error);
                });
            })
        }

        return Promise.reject(new Error('No supported Stripe payment method selected.'));
    }*/

    async verifyPaymentIntentStatusWithRetries(attempts = 10, delayMs = 1000) { 
    for (let i = 0; i < attempts; i += 1) { 
        const paymentIntent = await this.verifyPaymentIntentStatus(); 
        
        // FIX: Accept BOTH 'succeeded' and manual capture's 'requires_capture' as valid success states
        if (paymentIntent?.status === 'succeeded' || paymentIntent?.status === 'requires_capture') { 
            return paymentIntent; 
        } 
        
        // Keep looping if the payment is still undergoing authentication checks
        if (paymentIntent?.status === 'requires_action' || paymentIntent?.status === 'processing') { 
            await new Promise(resolve => setTimeout(resolve, delayMs)); 
            continue; 
        } 
        
        throw new Error('Stripe payment failed or returned unexpected status: ' + paymentIntent?.status); 
    } 
    
    throw new Error('Stripe payment did not reach a valid completion status after ' + attempts + ' retries.'); 
}

handlePayNow() { 
    let returnURL = window.location.href.substring(0, window.location.href.lastIndexOf('/')) + '/payment-landing'; 

    if(this.selectedPaymentMethod === "alipay") { 
        return new Promise((resolve, reject) => { 
            let confirmAliPayPaymentPromise = this.stripe.confirmAlipayPayment( 
                this.clientSecret, 
                { return_url: returnURL }, 
                { handleActions: false } 
            ); 
            confirmAliPayPaymentPromise.then(async ({error, paymentIntent}) => { 
                if (error) { 
                    console.error('Stripe Alipay confirm error', error); 
                    return reject(error); 
                } 
                console.log('Stripe Alipay confirm result', paymentIntent); 
                if (paymentIntent.status === 'succeeded') { 
                    return resolve(paymentIntent); 
                } 
                if (paymentIntent.status === 'requires_action') { 
                    let stripePopupWindow = window.open(paymentIntent.next_action.alipay_handle_redirect.url, 'Authorize AliPay Payment', 'resizable=1,scrollbars=1,width=600px,height=800px'); 
                    let interval = setInterval(async () => { 
                        try { 
                            let queryString = stripePopupWindow.location.search; 
                            let queryStringMap = new URLSearchParams(queryString); 
                            let redirectStatus = queryStringMap.get('redirect_status'); 
                            if (redirectStatus) { 
                                clearInterval(interval); 
                                if (redirectStatus === 'succeeded') { 
                                    setTimeout(() => { 
                                        stripePopupWindow.close(); 
                                    }, 3000); 
                                    try { 
                                        const verifiedIntent = await this.verifyPaymentIntentStatusWithRetries(); 
                                        return resolve(verifiedIntent); 
                                    } catch (verifyError) { 
                                        console.error('Stripe Alipay verification failed', verifyError); 
                                        return reject(verifyError); 
                                    } 
                                } 
                                stripePopupWindow.close(); 
                                return reject(new Error('Alipay redirect failed: ' + redirectStatus)); 
                            } 
                        } catch(err) { 
                            console.warn('(Expected Exception) Could not access window.location, waiting for redirect', err); 
                        } 
                    }, 1000); 
                    return; 
                } 
                return reject(new Error('Stripe Alipay payment returned unexpected status: ' + paymentIntent.status)); 
            }).catch(error => { 
                console.error('Stripe Alipay confirm promise error', error); 
                reject(error); 
            }); 
        }) 
    } 
    else if(this.selectedPaymentMethod === "wechat_pay") { 
        return new Promise((resolve, reject) => { 
            this.stripe.confirmWechatPayPayment( 
                this.clientSecret, 
                { 
                    payment_method_options: { 
                        wechat_pay: { 
                            client: 'web', 
                        } 
                    }, 
                    return_url: returnURL 
                } 
            ).then(async ({error, paymentIntent}) => { 
                if (error) { 
                    console.error('Stripe WeChat confirm error', error); 
                    return reject(error); 
                } 
                console.log('Stripe WeChat confirm result', paymentIntent); 
                if (paymentIntent.status === 'succeeded') { 
                    return resolve(paymentIntent); 
                } 
                if (paymentIntent.status === 'requires_action' || paymentIntent.status === 'processing') { 
                    try { 
                        const verifiedIntent = await this.verifyPaymentIntentStatusWithRetries(); 
                        return resolve(verifiedIntent); 
                    } catch (verifyError) { 
                        console.error('Stripe WeChat verification failed', verifyError); 
                        return reject(verifyError); 
                    } 
                } 
                return reject(new Error('Stripe WeChat payment failed or returned unexpected status: ' + paymentIntent.status)); 
            }).catch(error => { 
                console.error('Stripe WeChat confirm promise error', error); 
                reject(error); 
            }); 
        }) 
    } 
    // ==========================================
    // FIX: ADDED CARD PAYMENT INTEGRATION HANDLER
    // ==========================================
    else if(this.selectedPaymentMethod === "card") { 
        return new Promise((resolve, reject) => { 
            // confirmPayment uses the Payment Element configurations natively
            this.stripe.confirmPayment({ 
                elements: this.elements, 
                confirmParams: { 
                    return_url: returnURL, 
                }, 
                redirect: "if_required" // Prevents unnecessary page reloads if 3D Secure modal can run inline
            }).then(async ({error, paymentIntent}) => { 
                if (error) { 
                    console.error('Stripe Card confirm error', error); 
                    return reject(error); 
                } 
                
                // If it passes immediately or already holds authorized funds
                if (paymentIntent.status === 'succeeded' || paymentIntent.status === 'requires_capture') { 
                    return resolve(paymentIntent); 
                } 
                
                // If the user must pass a 3D Secure security screen challenge
                if (paymentIntent.status === 'requires_action' || paymentIntent.status === 'processing') { 
                    try { 
                        const verifiedIntent = await this.verifyPaymentIntentStatusWithRetries(); 
                        return resolve(verifiedIntent); 
                    } catch (verifyError) { 
                        console.error('Stripe Card verification failed', verifyError); 
                        return reject(verifyError); 
                    } 
                } 
                return reject(new Error('Stripe Card payment returned unexpected status: ' + paymentIntent.status)); 
            }).catch(error => { 
                console.error('Stripe Card promise execution error', error); 
                reject(error); 
            }); 
        }); 
    } 

    return Promise.reject(new Error('No supported Stripe payment method selected.')); 
}


    @wire(CartSummaryAdapter)
    getCartSummary({data, error}) {
        if (data) {
            this.cartGrandTotal = data.grandTotalAmount * 100;
            this.handleInitializePaymentIntent();
        } else if (error) {
            console.error('CartSummaryAdapter error: ', error);
        }
    }

    @wire(CheckoutInformationAdapter)
    getCheckoutInformation({data, error}) {
        if (data) {
            this.checkoutId = data.checkoutId;
        } else if (error) {
            console.error('CheckoutInformationAdapter error: ', error);
        }
    }
}