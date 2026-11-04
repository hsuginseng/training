@isTest
public class OfflinePaymentGatewayTest {

    @isTest
    static void testBuildRefundResponse() {
        OfflinePaymentGateway adapter = new OfflinePaymentGateway();

        Test.startTest();
        commercepayments.ReferencedRefundResponse response = adapter.buildRefundResponse(100);
        Test.stopTest();

        System.assertNotEquals(null, response, 'Refund response should not be null');
    }

    @isTest
    static void testUnsupportedRequestTypeReturnsError() {
        OfflinePaymentGateway adapter = new OfflinePaymentGateway();

        commercepayments.PostAuthorizationRequest postAuthRequest = new commercepayments.PostAuthorizationRequest(50);
        commercepayments.PaymentGatewayContext ctx =
            new commercepayments.PaymentGatewayContext(postAuthRequest, commercepayments.RequestType.PostAuth);

        Test.startTest();
        commercepayments.GatewayResponse response = adapter.processRequest(ctx);
        Test.stopTest();

        System.assertNotEquals(null, response, 'Response should not be null');
        System.assert(response instanceof commercepayments.GatewayErrorResponse,
            'Expected a GatewayErrorResponse for an unsupported request type');
    }

    @isTest
    static void testReferencedRefundCastExceptionReturnsError() {
        OfflinePaymentGateway adapter = new OfflinePaymentGateway();

        commercepayments.PostAuthorizationRequest dummyRequest = new commercepayments.PostAuthorizationRequest(100);
        commercepayments.PaymentGatewayContext ctx =
            new commercepayments.PaymentGatewayContext(dummyRequest, commercepayments.RequestType.ReferencedRefund);

        Test.startTest();
        commercepayments.GatewayResponse response = adapter.processRequest(ctx);
        Test.stopTest();

        System.assertNotEquals(null, response, 'Response should not be null');
        System.assert(response instanceof commercepayments.GatewayErrorResponse,
            'Cast exception should be caught and converted to GatewayErrorResponse');
    }
}