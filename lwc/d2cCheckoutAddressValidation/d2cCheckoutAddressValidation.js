import { LightningElement, wire } from 'lwc';
import { CheckoutInformationAdapter, CheckoutAddressAdapter, updateShippingAddress, createCheckoutAddressesUpdateAction } from 'commerce/checkoutApi';
import validateDeliveryAddress from "@salesforce/apex/ShippingAddressValidator.validateDeliveryAddress";
import { dispatchAction } from 'commerce/actionApi';

export default class d2cCheckoutAddressValidation extends LightningElement {

    checkoutId;
    selectedAddressData;

    @wire(CheckoutInformationAdapter)
    getCheckoutInformation({data, error}) {
        if (data) {
            this.checkoutId = data.checkoutId;
            console.log('getCheckoutInformation data', data);

            try {
                let deliveryAddress = data.deliveryGroups.items[0].deliveryAddress;

                if(this.selectedAddressData != JSON.stringify(deliveryAddress)){
                    console.log('this.selectedAddressData', this.selectedAddressData);
                    console.log('deliveryAddress', deliveryAddress);
                    console.log('comparison', this.selectedAddressData != deliveryAddress);
                    console.log('Validating selected address');
                    let deliveryMethod = data.deliveryGroups.items[0].selectedDeliveryMethod.classOfService;
                    let deliveryCarrier = deliveryMethod.split(' ')[0];
                    let addressMapping = {
                        "company": deliveryAddress.companyName,
                        "name": deliveryAddress.name,
                        "phone": deliveryAddress.shipToPhoneNumber,
                        "street": deliveryAddress.street,
                        "city": deliveryAddress.city,
                        "postalCode": deliveryAddress.postalCode,
                        "stateCode": deliveryAddress.region,
                        "countryCode": deliveryAddress.country
                    };
    
                    this.selectedAddressData = JSON.stringify(deliveryAddress);

                    validateDeliveryAddress({
                        address: addressMapping,
                        shippingPreferenceKeyword: deliveryCarrier
                    }).then(result => {
                        console.log('Validation Result', result);
                        if(!result.isValid){
                            let validatedAddress = {
                                name: deliveryAddress.name,
                                firstName: deliveryAddress.firstName,
                                lastName: deliveryAddress.lastName,
                                region: result.state,
                                country: result.country,
                                city: result.city,
                                street: result.streetLine1,
                                postalCode: result.postalCode,
                                addressType: 'Shipping'
                            };
                            dispatchAction(this, createCheckoutAddressesUpdateAction({ address: validatedAddress }))
                        }
                    }).catch(error => {
    
                    })
    
                }
            } catch(err){

            }         
        } else if (error) {
            console.log('CheckoutInformationAdapter error: ', error);
        }
    }

    @wire(CheckoutAddressAdapter, { checkoutId: '$checkoutId', addressType: 'Shipping' })
    retrieveCheckoutAddressData({ data, error }){
        if(data){
            console.log('data', data);
        } else if (error){
            console.error('CheckoutAddressAdapter error', error);
        }
    }

}