public class OfflinePaymentGateway implements commercepayments.PaymentGatewayAdapter {

    public commercepayments.GatewayResponse processRequest(commercepayments.PaymentGatewayContext context) {
        commercepayments.RequestType requestType = context.getPaymentRequestType();
        System.debug('>>> OfflinePaymentGateway received request type: ' + requestType);

        try {
            if (requestType == commercepayments.RequestType.ReferencedRefund) {
                return processReferencedRefund(context);
            }

            // Anything else — return a typed failure rather than null
            return new commercepayments.GatewayErrorResponse(
                '400',
                'Unsupported request type: ' + requestType
            );
        } catch (Exception e) {
            System.debug('>>> OfflinePaymentGateway exception: ' + e.getMessage() 
                + ' / ' + e.getStackTraceString());
            return new commercepayments.GatewayErrorResponse('500', e.getMessage());
        }
    }

    private commercepayments.GatewayResponse processReferencedRefund(commercepayments.PaymentGatewayContext context) {
        commercepayments.ReferencedRefundRequest req =
            (commercepayments.ReferencedRefundRequest) context.getPaymentRequest();
        return buildRefundResponse(req.amount);
    }

    @TestVisible
    private commercepayments.ReferencedRefundResponse buildRefundResponse(Double amount) {
        commercepayments.ReferencedRefundResponse res = new commercepayments.ReferencedRefundResponse();
        res.setSalesforceResultCodeInfo(
            new commercepayments.SalesforceResultCodeInfo(commercepayments.SalesforceResultCode.Success)
        );
        res.setGatewayResultCode('SUCCESS');
        res.setGatewayResultCodeDescription('Offline refund processed');
        res.setAmount(amount);
        res.setGatewayReferenceNumber('OFFLINE-' + String.valueOf(System.now().getTime()));
        res.setGatewayDate(System.now());
        return res;
    }
}