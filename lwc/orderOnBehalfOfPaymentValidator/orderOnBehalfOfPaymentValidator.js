import { LightningElement, api } from 'lwc';
import { subscribe, unsubscribe, onError } from 'lightning/empApi';
import { FlowNavigationNextEvent, FlowAttributeChangeEvent } from 'lightning/flowSupport';

const FAILURE_STATUS = 'Hold';

export default class OrderOnBehalfOfPaymentValidator extends LightningElement {
    @api cartId;
    @api successStatus;
    @api successHeader = 'Payment Validation Successful';
    @api failureHeader = 'Error: Payment Validation Failed';
    @api successMessage = 'The payment authorization was successful. Advancing to the next screen…';
    @api failureMessage = 'The payment card experienced a 3D Secure authentication issue. Please navigate to the order summary to collect funds via a merchant-submitted payment or a cash entry payment.';
    @api statusChannel = '/event/OrderSumStatusChangedEvent';
    @api pendingChannel = '/event/PendingOrdSumProcEvent';
    @api autoAdvanceDelayMs = 2200;
    @api availableActions = [];

    @api paymentResult;
    @api resolvedStatus;
    @api resolvedOrderSummaryId;

    state = 'waiting';
    _statusSubscription = null;
    _pendingSubscription = null;
    _advanceTimer = null;
    _orderSummaryId = null;
    _bufferedStatuses = new Map();

    connectedCallback() {
        this._registerErrorListener();
        this._subscribePending();
        this._subscribeStatus();
    }

    disconnectedCallback() {
        if (this._advanceTimer) {
            clearTimeout(this._advanceTimer);
            this._advanceTimer = null;
        }
        this._unsubscribeAll();
    }

    _subscribePending() {
        const callback = (response) => {
            const payload = response?.data?.payload;
            if (!payload || this._orderSummaryId || !this.cartId) return;

            const externalRef = payload.ExternalReferenceIdentifier;
            if (!externalRef || !String(externalRef).includes(this.cartId)) return;

            const orderSummaryId = payload.OrderSummaryId;
            if (!orderSummaryId) return;

            this._orderSummaryId = orderSummaryId;
            this.resolvedOrderSummaryId = orderSummaryId;
            this.dispatchEvent(new FlowAttributeChangeEvent('resolvedOrderSummaryId', orderSummaryId));

            const buffered = this._bufferedStatuses.get(this._normalizeId(orderSummaryId));
            if (buffered) {
                this._bufferedStatuses.clear();
                this._evaluate(buffered);
            }
        };

        subscribe(this.pendingChannel, -1, callback)
            .then((response) => {
                this._pendingSubscription = response;
            })
            .catch((error) => {
                console.error('orderOnBehalfOfPaymentValidator: pending subscribe failed', error);
            });
    }

    _subscribeStatus() {
        const callback = (response) => {
            const payload = response?.data?.payload;
            if (!payload || this.state !== 'waiting') return;

            const eventOrderId = payload.OrderSummaryId;
            if (!eventOrderId) return;

            if (!this._orderSummaryId) {
                this._bufferedStatuses.set(this._normalizeId(eventOrderId), payload.NewStatus);
                return;
            }

            if (this._normalizeId(eventOrderId) !== this._normalizeId(this._orderSummaryId)) return;

            this._evaluate(payload.NewStatus);
        };

        subscribe(this.statusChannel, -1, callback)
            .then((response) => {
                this._statusSubscription = response;
            })
            .catch((error) => {
                console.error('orderOnBehalfOfPaymentValidator: status subscribe failed', error);
            });
    }

    _unsubscribeAll() {
        if (this._statusSubscription?.id) {
            unsubscribe(this._statusSubscription, () => {});
            this._statusSubscription = null;
        }
        if (this._pendingSubscription?.id) {
            unsubscribe(this._pendingSubscription, () => {});
            this._pendingSubscription = null;
        }
    }

    _registerErrorListener() {
        onError((error) => {
            console.error('orderOnBehalfOfPaymentValidator: empApi error', JSON.stringify(error));
        });
    }

    _evaluate(newStatus) {
        if (!newStatus) return;

        const trimmed = String(newStatus).trim();
        const lower = trimmed.toLowerCase();
        const successTarget = String(this.successStatus || '').trim().toLowerCase();

        if (successTarget && lower === successTarget) {
            this.resolvedStatus = trimmed;
            this.dispatchEvent(new FlowAttributeChangeEvent('resolvedStatus', trimmed));
            this.state = 'success';
            this.paymentResult = 'Success';
            this.dispatchEvent(new FlowAttributeChangeEvent('paymentResult', 'Success'));
            this._scheduleAdvance();
            return;
        }

        if (lower === FAILURE_STATUS.toLowerCase()) {
            this.resolvedStatus = trimmed;
            this.dispatchEvent(new FlowAttributeChangeEvent('resolvedStatus', trimmed));
            this.state = 'failure';
            this.paymentResult = 'Failure';
            this.dispatchEvent(new FlowAttributeChangeEvent('paymentResult', 'Failure'));
        }
    }

    _scheduleAdvance() {
        const delay = Number.isFinite(this.autoAdvanceDelayMs) ? this.autoAdvanceDelayMs : 2200;
        this._advanceTimer = setTimeout(() => {
            if (this.availableActions?.includes('NEXT')) {
                this.dispatchEvent(new FlowNavigationNextEvent());
            }
        }, delay);
    }

    _normalizeId(id) {
        return id ? String(id).substring(0, 15) : id;
    }

    get isWaiting() { return this.state === 'waiting'; }
    get isSuccess() { return this.state === 'success'; }
    get isFailure() { return this.state === 'failure'; }
}