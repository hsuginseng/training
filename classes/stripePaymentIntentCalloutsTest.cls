@IsTest
private class stripePaymentIntentCalloutsTest {
    private class InitMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            // verify endpoint contains our query params
            System.assert(req.getEndpoint().startsWith('https://api.stripe.com/v1/payment_intents?'));
            
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            // a minimal valid PaymentIntent JSON
            res.setBody('{"id":"pi_12345","object":"payment_intent","status":"requires_payment_method"}');
            return res;
        }
    }
    
    @IsTest
    static void testInitializePaymentIntent() {
        // this exact string is what the method will deserialize
        String piDataString = '{'
            + '"automatic_payment_methods[enabled]" : "false",'
            + '"payment_method_types[0]" : "alipay",'
            + '"payment_method_types[1]" : "wechat_pay",'
            + '"currency" : "usd",'
            + '"amount" : "2000"'
            + '}';

        // Register our mock
        Test.setMock(HttpCalloutMock.class, new InitMock());
        
        Test.startTest();
            // perform the callout
            Object result = stripePaymentIntentCallouts.initializePaymentIntent(piDataString);
        Test.stopTest();
        
        // the method deserializes the JSON into an untyped Map
        Map<String, Object> mapResult = (Map<String, Object>) result;
        System.assertEquals('pi_12345', mapResult.get('id'), 'PaymentIntent Id should match');
        System.assertEquals('payment_intent', mapResult.get('object'), 'Object type should match');
        System.assertEquals('requires_payment_method', mapResult.get('status'), 'Status should match');
    }
}