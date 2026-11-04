import { LightningElement, api } from 'lwc';
import getOrderSummaryNumber from "@salesforce/apex/UserUtility.getOrderSummaryNumberFromReference";

export default class d2cOrderConfirmationDetails extends LightningElement {
    @api
    set order(data){
        this._order = data;

        let interval = setInterval(() => {
            if(data && data.Details){
                getOrderSummaryNumber({ orderReferenceNumber: data.Details.orderNumber }).then(value => {
                    this.orderNumber=value;
                    if(this.orderNumber){
                        clearInterval(interval);
                    }
                }).catch(err => {
                    console.error('Could not retrieve Order Summary Details', err)
                    this.hasError=true;
                    clearInterval(interval);
                })
            }
        }, 5000)
    }
    get order(){ return this._order; }

    orderNumber;
    hasError=false;
}