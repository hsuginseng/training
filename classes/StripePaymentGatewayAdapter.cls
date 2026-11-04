global class StripePaymentGatewayAdapter implements commercepayments.PaymentGatewayAdapter {

    class StripeValidationException extends Exception {}

    private static final commercepayments.SalesforceResultCodeInfo RC_SUCCESS = toCodeInfo(commercepayments.SalesforceResultCode.Success);
    private static final commercepayments.SalesforceResultCodeInfo RC_DECLINE = toCodeInfo(commercepayments.SalesforceResultCode.Decline);
    private static final List<String> DECLINE_CODES = new List<String>{'card_declined', 'incorrect_cvc', 'expired_card',
     'authentication_required', 'card_not_supported', 'currency_not_supported', 'incorrect_number', 'incorrect_zip'};

    global StripePaymentGatewayAdapter() {}

    global commercepayments.GatewayResponse processRequest(commercepayments.paymentGatewayContext gatewayContext) {
        commercepayments.RequestType requestType = gatewayContext.getPaymentRequestType();
        commercepayments.PaymentGatewayRequest paymentRequest = gatewayContext.getPaymentRequest();
        commercepayments.GatewayResponse response;
        
        try {
            if (requestType == commercepayments.RequestType.PostAuth) {
                response = createPostAuthResponse((commercepayments.PostAuthorizationRequest) paymentRequest);
            } else if (requestType == commercepayments.RequestType.Capture) {
                response =  createCaptureResponse((commercepayments.CaptureRequest) paymentRequest);
            } else if (requestType == commercepayments.RequestType.Tokenize) {
                response = createTokenizeResponse((commercepayments.PaymentMethodTokenizationRequest) paymentRequest);
            }
            return response;
        } catch (StripeValidationException e) {
             return new commercepayments.GatewayErrorResponse('400', e.getMessage());
        }
    }

    public commercepayments.GatewayResponse createTokenizeResponse(commercepayments.PaymentMethodTokenizationRequest tokenizeRequest) {
        // API: https://stripe.com/docs/api/tokens    
            
        commercepayments.CardPaymentMethodRequest cardPaymentMethod = tokenizeRequest.cardPaymentMethod;
        
        Map<String, String> params = new Map<String, String>();
        params.put('card[name]', urlEncode(cardPaymentMethod.cardHolderName));
        params.put('card[number]', cardPaymentMethod.cardNumber);
        params.put('card[exp_month]', String.valueOf(cardPaymentMethod.expiryMonth));
        params.put('card[exp_year]', String.valueOf(cardPaymentMethod.expiryYear));
        params.put('card[cvc]', cardPaymentMethod.cvv);
        
        commercepayments.AddressRequest billingAddress = tokenizeRequest.address;

		if (billingAddress != null) {
			params.put('card[address_line1]', billingAddress.street);
			params.put('card[address_city]', billingAddress.city);
			params.put('card[address_state]', billingAddress.state);
			params.put('card[address_zip]', billingAddress.postalCode);
			params.put('card[address_country]', billingAddress.country);
		}

        HttpResponse response = doPost('tokens', params);
        String body = response.getBody();
        Map<String, Object> results = (Map<String, Object>) JSON.deserializeUntyped(body);
        Integer sc = response.getStatusCode();
		commercepayments.PaymentMethodTokenizationResponse tokenizeResponse = new commercepayments.PaymentMethodTokenizationResponse();
		
		tokenizeResponse.setGatewayDate(system.now());
		
        if (sc >= 200 && sc < 300) {
        	tokenizeResponse.setGatewayToken((String) results.get('id'));
        	tokenizeResponse.setGatewayResultCode('success');
        	tokenizeResponse.setSalesforceResultCodeInfo(RC_SUCCESS);
        }
        else {
			// TODO: lots of error mapping/handling
            Map<String, Object> error = (Map<String, Object>) results.get('error');
            String errorType = (String) error.get('type');
            String errorCode = (String) error.get('code');
            
            if (errorType.equals('card_error') && DECLINE_CODES.contains(errorCode) ) {
                tokenizeResponse.setGatewayResultCode(errorCode);
                tokenizeResponse.setGatewayResultCodeDescription((String) error.get('decline_code'));
                tokenizeResponse.setGatewayMessage((String) error.get('message'));
                tokenizeResponse.setSalesforceResultCodeInfo(RC_DECLINE);
            } else {
                return new commercepayments.GatewayErrorResponse(String.valueOf(sc), 'ERROR: ' + body);
            }
        }
        
        // TODO: more failure cases?
		
        return tokenizeResponse;
    }

    public commercepayments.GatewayResponse createPostAuthResponse(commercepayments.PostAuthorizationRequest captureRequest){
        commercepayments.PostAuthorizationRequest postAuthRequest = captureRequest;

        Map<String, String> paymentIntentParams = new Map<String, String>{ 'id' =>  postAuthRequest.additionalData.get('id')};
        HttpResponse paymentIntentResponse = doGet('payment_intents/', paymentIntentParams);
        String paymentIntentResponseBody = paymentIntentResponse.getBody();
        Integer paymentIntentStatusCode = paymentIntentResponse.getStatusCode();
        Map<String, Object> paymentIntentResult = (Map<String, Object>) JSON.deserializeUntyped(paymentIntentResponseBody);

        Map<String, String> paymentCaptureParams = new Map<String, String>{ 'id' =>  (String) paymentIntentResult.get('latest_charge')};
        HttpResponse paymentCaptureResponse = doGet('charges/', paymentCaptureParams);
        String paymentCaptureResponseBody = paymentCaptureResponse.getBody();
        Integer paymentCaptureStatusCode = paymentCaptureResponse.getStatusCode();
        Map<String, Object> paymentCaptureResult = (Map<String, Object>) JSON.deserializeUntyped(paymentCaptureResponseBody);

        commercepayments.PostAuthorizationResponse postAuthResponse = new commercepayments.PostAuthorizationResponse();
        postAuthResponse.setGatewayDate(system.now());
        
        // map: https://stripe.com/docs/api/errors
        // to: https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_enum_commercepayments_SalesforceResultCode.htm
        
        if (paymentCaptureStatusCode >= 200 && paymentCaptureStatusCode < 300) {
            postAuthResponse.setGatewayResultCode((String) paymentCaptureResult.get('status'));
            postAuthResponse.setGatewayResultCodeDescription((String) paymentCaptureResult.get('status'));
            postAuthResponse.setGatewayAuthCode((String) paymentCaptureResult.get('id')); // "ch_..."
            postAuthResponse.setSalesforceResultCodeInfo(RC_SUCCESS);
            postAuthResponse.setAmount(double.valueOf(((Long) paymentCaptureResult.get('amount'))/100.00)); // TODO: use reverse of toStripeCurrencyUnits
        } else {
            Map<String, Object> error = (Map<String, Object>) paymentCaptureResult.get('error');
            String errorType = (String) error.get('type');
            String errorCode = (String) error.get('code');

            if (errorType.equals('card_error') && DECLINE_CODES.contains(errorCode) ) {
                postAuthResponse.setGatewayResultCode(errorCode);
                postAuthResponse.setGatewayResultCodeDescription((String) error.get('decline_code'));
                postAuthResponse.setGatewayMessage((String) error.get('message'));
                postAuthResponse.setSalesforceResultCodeInfo(RC_DECLINE);
            } else {
                return new commercepayments.GatewayErrorResponse(String.valueOf(paymentCaptureStatusCode), 'ERROR: ' + paymentCaptureResponseBody);
            }
        }

        return postAuthResponse;
    }
    
    public commercepayments.GatewayResponse createCaptureResponse(commercepayments.CaptureRequest captureRequest) {
        // API: https://stripe.com/docs/api/charges/capture
                
        // get the GatewayAuthCode
        PaymentAuthorization paymentAuthorization = [SELECT Id, GatewayAuthCode FROM PaymentAuthorization WHERE Id=:captureRequest.paymentAuthorizationId LIMIT 1];
        String authCode = paymentAuthorization.GatewayAuthCode;
        
        String currencyIsoCodeLC = 'usd'; // TODO: we need to get this from previous uath
        Long amount = toStripeCurrencyUnits(currencyIsoCodeLC, captureRequest.amount);
        
        Map<String, String> params = new Map<String, String>();
        params.put('amount', String.valueOf(amount));
        
        HttpResponse response = doPost('charges/' + authCode + '/capture', params);
        
        String body = response.getBody();
        if (response.getStatusCode() != 200) {
            return new commercepayments.GatewayErrorResponse('500', 'ERROR: ' + response + ': ' + body);
        }
        Map<String, Object> results = (Map<String, Object>) JSON.deserializeUntyped(body);
    
        commercepayments.CaptureResponse captureResponse = new commercepayments.CaptureResponse();
        captureResponse.setAmount(double.valueOf(((Long) results.get('amount'))/100.00)); // TODO: use reverse of toStripeCurrencyUnits
        captureResponse.setGatewayDate(system.now());
        captureResponse.setGatewayResultCode((String) results.get('balance_transaction'));
        captureResponse.setGatewayResultCodeDescription((String) results.get('receipt_url'));
        captureResponse.setSalesforceResultCodeInfo(RC_SUCCESS);
        return captureResponse;
    }

    private static HttpResponse doPost(String path, Map<String, String> params) {
        commercepayments.PaymentsHttp http = new commercepayments.PaymentsHttp();
        HttpRequest request = new HttpRequest();
        request.setEndpoint('/v1/' + path);

        Blob headerValue = Blob.valueOf('{!$Credential.Username}');
        String authorizationHeader = 'Basic ' + EncodingUtil.base64Encode(headerValue);
        request.setHeader('Authorization', authorizationHeader);
        
        request.setMethod('POST');
        request.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        request.setBody(urlEncodedParams(params));
        
        return http.send(request);
    }

    private static HttpResponse doGet(String path, Map<String, String> params) {
        commercepayments.PaymentsHttp http = new commercepayments.PaymentsHttp();
        HttpRequest request = new HttpRequest();
        request.setEndpoint('/v1/' + path + urlEncodedParams(params));

        Blob headerValue = Blob.valueOf('{!$Credential.Username}');
        String authorizationHeader = 'Basic ' + EncodingUtil.base64Encode(headerValue);
        request.setHeader('Authorization', authorizationHeader);
        
        request.setMethod('POST');
        request.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        
        return http.send(request);
    }
    
    private static String urlEncodedParams(Map<String, String> params) {
        String body = params.containsKey('id') ? params.get('id') : '';
        Boolean first = true;
        for (String key: params.keySet()) {
            if (first) {
                first = false;
            } else {
                body += '&';
            }
            // NOTE: do not encode values to allow PaymentsNamedConnection to replace the secure fields
            // values that need to be encoded should be encoded by this method's caller
            if(key != 'id'){ body += urlEncode(key) + '=' + params.get(key); }
        }
        return body;
    }
    
    private static String urlEncode(String str) {
        return EncodingUtil.urlEncode(str, 'UTF-8');
    }
    
    private static Long toStripeCurrencyUnits(String currencyIsoCodeLC, Double amount) {
        // see https://stripe.com/docs/currencies#zero-decimal
        if (currencyIsoCodeLC.equals('usd')) {
            return Math.roundToLong(amount * 100); // TODO: make sure there are no rounding/precission issues
        }
        throw new StripeValidationException('toStripeCurrencyUnits: TODO: ' + currencyIsoCodeLC);  
    }
    
    private static commercepayments.SalesforceResultCodeInfo toCodeInfo(commercepayments.SalesforceResultCode code) {
        return new commercepayments.SalesforceResultCodeInfo(code);
    }
}