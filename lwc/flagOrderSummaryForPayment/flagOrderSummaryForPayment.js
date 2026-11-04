import { LightningElement, api } from 'lwc';
import updateLastViewedDateOnOrderSummary from '@salesforce/apex/FlagOrderSummaryForPaymentController.updateLastViewedDateOnOrderSummary';

export default class FlagOrderSummaryForPayment extends LightningElement {
    @api recordId;

    connectedCallback() {
        if (this.recordId) {
            this.updateOrderSummaryWithCurrentTime();
        }
    }

    updateOrderSummaryWithCurrentTime() {
        updateLastViewedDateOnOrderSummary({ orderSummaryId: this.recordId })
            .then(() => {
            })
            .catch(error => {
                console.error('Failed to update last viewed date: ', error);
            });     
    }
}