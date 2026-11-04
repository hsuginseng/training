public class StripeCalloutFailureMock implements HttpCalloutMock {
    public HTTPResponse respond(HTTPRequest req) {
        System.assertEquals('POST', req.getMethod());
        
        // Create a fake response
        HttpResponse res = new HttpResponse();
        res.setStatusCode(400);
        List<String> jsonResponse;
        res.setHeader('Content-Type', 'application/json');
        if(req.getEndpoint().contains('tokens')){
            jsonResponse = new List<String> {
              '"correlation_id": "124.9765877252790"',
                '"status": "failed"',
                '"error": {"type": "card_error", "code": "card_declined", "message": "The credit card number check failed"}',
                '"type": "FDToken"'
            };
        }
        else{
          jsonResponse = new List<String> {
                '"transaction_status": "Not Processed"',
                '"validation_status": "failed"',
                '"transaction_type": "authorize"',
                '"method": "credit_card"',
                '"amount": "1299"',
                '"currency": "USD"',
                '"correlation_id": "228.6136675492894"',
                '"error": {"type": "card_error", "code": "card_declined", "message": "The credit card number check failed"}'
          };
        }
        res.setBody('{' + String.join(jsonResponse, ',') + '}');
        return res;
    }
}