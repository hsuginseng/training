import { LightningElement, api } from 'lwc';

/**
 * @slot SalesforcePaymentsRegion
 * @slot CustomPaymentRegion
 */
export default class d2cCheckoutPaymentRegion extends LightningElement {
    selectedPaymentType='CARD_WALLET';

    @api buttonLabelCardsAndWallets;
    @api buttonLabelMobilePayments;

    /* GET/SET */
    get paymentTypeIsCardWallet(){ return this.selectedPaymentType=='CARD_WALLET'; }
    get paymentTypeIsMobile(){ return this.selectedPaymentType=='MOBILE'; }
    get showSalesforcePaymentsRegionContent(){ return this.paymentTypeIsCardWallet || this.isInSitePreview(); }
    get showCustomPaymentRegionContent(){ return this.paymentTypeIsMobile || this.isInSitePreview(); }
    get cardsAndWalletButtonVariant(){ return this.paymentTypeIsCardWallet ? 'brand' : 'neutral'; }
    get mobileButtonVariant(){ return this.paymentTypeIsMobile ? 'brand' : 'neutral'; }
    /* GET/SET */
    
    /* EVENT HANDLERS */
    handleCardsAndWalletsSelected(){ this.selectedPaymentType = 'CARD_WALLET'; }
    handleMobilePaymentsSelected(){ this.selectedPaymentType = 'MOBILE'; }
    /* EVENT HANDLERS */

    /* HELPER METHODS */
    isInSitePreview() {
        let url = document.URL;
        return (url.indexOf('sitepreview') > 0 || url.indexOf('livepreview') > 0 || url.indexOf('live-preview') > 0 
            || url.indexOf('live.') > 0 || url.indexOf('.builder.') > 0);
    }
    /* HELPER METHODS */
}