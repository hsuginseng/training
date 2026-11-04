@isTest
public class StripePaymentGatewayAdapterTest {

    @isTest
    public static void testCreatePostAuthResponseSuccess(){
        Test.setMock(HttpCalloutMock.class, new StripePaymentCalloutMock());
        
        Test.startTest();
        StripePaymentGatewayAdapter adapter = new StripePaymentGatewayAdapter();
        commercepayments.PostAuthorizationRequest postAuthRequest = new commercepayments.PostAuthorizationRequest(2000);
        postAuthRequest.currencyIsoCode = 'USD';
        postAuthRequest.additionalData = new Map <String, String>{ 'token' => 'testToken' };
        commercepayments.paymentGatewayContext gatewayContext = new commercepayments.paymentGatewayContext(postAuthRequest, commercepayments.RequestType.PostAuth);
    
        commercepayments.GatewayResponse response = adapter.processRequest(gatewayContext);
        Test.stopTest();
    }


    @isTest
    public static void testCreatePostAuthResponseFailure(){
        Test.setMock(HttpCalloutMock.class, new StripeCalloutFailureMock());
        
        Test.startTest();
        StripePaymentGatewayAdapter adapter = new StripePaymentGatewayAdapter();
        commercepayments.PostAuthorizationRequest postAuthRequest = new commercepayments.PostAuthorizationRequest(2000);
        postAuthRequest.currencyIsoCode = 'USD';
        postAuthRequest.additionalData = new Map <String, String>{ 'token' => 'testToken' };
        commercepayments.paymentGatewayContext gatewayContext = new commercepayments.paymentGatewayContext(postAuthRequest, commercepayments.RequestType.PostAuth);
    
        commercepayments.GatewayResponse response = adapter.processRequest(gatewayContext);
        Test.stopTest();
    }
    
    @isTest
    public static void testCreateTokenizeResponseFailure() {
        Test.setMock(HttpCalloutMock.class, new StripeCalloutFailureMock());
    
        Test.startTest();
        StripePaymentGatewayAdapter adapter = new StripePaymentGatewayAdapter();
        commercepayments.PaymentMethodTokenizationRequest paymentRequest = new commercepayments.PaymentMethodTokenizationRequest('paymentGatewayId');
        commercepayments.CardPaymentMethodRequest cardPaymentMethodRequest = new commercepayments.CardPaymentMethodRequest(commercepayments.CardCategory.CreditCard);
        paymentRequest.address = new commercepayments.AddressRequest('street', 'city', 'state', 'country', 'postalCode');
        paymentRequest.cardPaymentMethod = cardPaymentMethodRequest;
        paymentRequest.cardPaymentMethod.cardHolderName = 'TEST CARDHOLDER NAME';
        commercepayments.paymentGatewayContext gatewayContext = new commercepayments.paymentGatewayContext(paymentRequest, commercepayments.RequestType.Tokenize);
    
        commercepayments.GatewayResponse response = adapter.processRequest(gatewayContext);
        Test.stopTest();
    }

    @isTest
    public static void testCreateTokenizeResponseSuccess() {
        Test.setMock(HttpCalloutMock.class, new StripePaymentCalloutMock());
    
        Test.startTest();
        StripePaymentGatewayAdapter adapter = new StripePaymentGatewayAdapter();
        commercepayments.PaymentMethodTokenizationRequest paymentRequest = new commercepayments.PaymentMethodTokenizationRequest('paymentGatewayId');
        commercepayments.CardPaymentMethodRequest cardPaymentMethodRequest = new commercepayments.CardPaymentMethodRequest(commercepayments.CardCategory.CreditCard);
        paymentRequest.address = new commercepayments.AddressRequest('street', 'city', 'state', 'country', 'postalCode');
        paymentRequest.cardPaymentMethod = cardPaymentMethodRequest;
        paymentRequest.cardPaymentMethod.cardHolderName = 'TEST CARDHOLDER NAME';
        commercepayments.paymentGatewayContext gatewayContext = new commercepayments.paymentGatewayContext(paymentRequest, commercepayments.RequestType.Tokenize);
    
        commercepayments.GatewayResponse response = adapter.processRequest(gatewayContext);
        Test.stopTest();
    }
    
    private static PaymentAuthorization initializeAuthObject()
    {
        PaymentAuthorization auth = new PaymentAuthorization();
        auth.amount = 1500;
        auth.Status = 'Processed';
        auth.ProcessingMode = 'External';
        auth.GatewayRefNumber = 'testreferencenumber';
        auth.GatewayRefDetails = '{"method":"credit_card","transaction_id":"ET119982"}';
        return auth;
    
    }
    
    private static Payment initializePaymentObject()
    {
        Payment pmt = new Payment();
        pmt.amount = 1500;
        pmt.Status = 'Processed';
        pmt.ProcessingMode = 'External';
        pmt.GatewayRefNumber = 'testreferencenumber';
        pmt.Type = 'Capture';
        pmt.GatewayRefDetails = '{"method":"credit_card","transaction_id":"ET119982"}';
        return pmt;    
    }
    
    private static commercepayments.AuthApiPaymentMethodRequest createAuthPaymentMethodRequest()
    {
        //Create a PaymentMethod instance
        commercepayments.AuthApiPaymentMethodRequest paymentMethod = new commercepayments.AuthApiPaymentMethodRequest(getCardPaymentMethod());
        return paymentMethod;
    }
    
    private static commercepayments.SaleApiPaymentMethodRequest createSalePaymentMethodRequest()
    {
        //Create a PaymentMethod instance
        commercepayments.SaleApiPaymentMethodRequest paymentMethod = new commercepayments.SaleApiPaymentMethodRequest(getCardPaymentMethod());
        return paymentMethod;
    }
    
    private static commercepayments.CardPaymentMethodRequest getCardPaymentMethod(){
        commercepayments.CardPaymentMethodRequest cardPaymentMethod = new commercepayments.CardPaymentMethodRequest(commercepayments.CardCategory.CreditCard);
        cardPaymentMethod.cardType = commercepayments.CardType.Visa;
        cardPaymentMethod.cardHolderFirstName = 'Test';
        cardPaymentMethod.cardHolderLastName = 'Test';
        cardPaymentMethod.cardHolderName = 'Test Test';
        cardPaymentMethod.cardNumber = '4443434343284111';
        cardPaymentMethod.cvv = '123';
        cardPaymentMethod.email = 'h@test.com';
        cardPaymentMethod.expiryMonth = 2;
        cardPaymentMethod.expiryYear = 1111;
        cardPaymentMethod.startMonth = 2;
        cardPaymentMethod.startYear = 1333;
        return cardPaymentMethod;
    }
}