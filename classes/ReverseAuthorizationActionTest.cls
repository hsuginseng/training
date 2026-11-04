@isTest
private class ReverseAuthorizationActionTest {

    // ---- Mock IReverser ----

    private class MockReverser implements ReverseAuthorizationAction.IReverser {
        ConnectApi.AuthorizationReversalResponse toReturn;
        Exception toThrow;
        ConnectApi.AuthorizationReversalRequest capturedInput;
        String capturedAuthId;
        Integer callCount = 0;

        public ConnectApi.AuthorizationReversalResponse reverse(
            ConnectApi.AuthorizationReversalRequest input,
            String authorizationId
        ) {
            callCount++;
            capturedInput = input;
            capturedAuthId = authorizationId;
            if (toThrow != null) {
                throw toThrow;
            }
            return toReturn;
        }
    }

    private class ApiTestException extends Exception {}

    // ---- Helpers ----

    private static ReverseAuthorizationAction.Request buildRequest() {
        ReverseAuthorizationAction.Request req = new ReverseAuthorizationAction.Request();
        req.paymentAuthorizationId = 'fakePaymentAuthId';
        req.amount = 25.00;
        req.comments = 'unit test';
        req.effectiveDate = Datetime.now();
        req.accountId = 'fakeAccountId';
        return req;
    }

    // ---- Tests ----

    @isTest
    static void successResponse_returnsSuccessTrue_andMapsInputs() {
        MockReverser mock = new MockReverser();
        ConnectApi.AuthorizationReversalResponse resp = new ConnectApi.AuthorizationReversalResponse();
        mock.toReturn = resp;
        ReverseAuthorizationAction.reverser = mock;

        ReverseAuthorizationAction.Request req = buildRequest();

        Test.startTest();
        List<ReverseAuthorizationAction.Result> results =
            ReverseAuthorizationAction.reverseAuthorizations(
                new List<ReverseAuthorizationAction.Request>{ req }
            );
        Test.stopTest();

        System.assertEquals(1, results.size(), 'one result per request');
        System.assertEquals(true, results[0].success, 'happy path should succeed');
        System.assertEquals(null, results[0].errorMessage, 'no error on success');

        System.assertEquals(1, mock.callCount, 'reverser called once');
        System.assertEquals('fakePaymentAuthId', mock.capturedAuthId, 'auth ID forwarded');
        System.assertEquals(25.00, mock.capturedInput.amount, 'amount forwarded');
        System.assertEquals('unit test', mock.capturedInput.comments, 'comments forwarded');
        System.assertEquals('fakeAccountId', mock.capturedInput.accountId, 'accountId forwarded');
        System.assertNotEquals(null, mock.capturedInput.effectiveDate, 'effectiveDate forwarded');
    }

    @isTest
    static void missingAuthorizationId_failsWithoutCallingApi() {
        MockReverser mock = new MockReverser();
        ReverseAuthorizationAction.reverser = mock;

        ReverseAuthorizationAction.Request req = buildRequest();
        req.paymentAuthorizationId = null;

        Test.startTest();
        List<ReverseAuthorizationAction.Result> results =
            ReverseAuthorizationAction.reverseAuthorizations(
                new List<ReverseAuthorizationAction.Request>{ req }
            );
        Test.stopTest();

        System.assertEquals(false, results[0].success);
        System.assert(
            results[0].errorMessage != null
                && results[0].errorMessage.containsIgnoreCase('paymentauthorizationid'),
            'errorMessage should mention paymentAuthorizationId, got: ' + results[0].errorMessage
        );
        System.assertEquals(0, mock.callCount, 'API not called when validation fails');
    }

    @isTest
    static void missingAmount_failsWithoutCallingApi() {
        MockReverser mock = new MockReverser();
        ReverseAuthorizationAction.reverser = mock;

        ReverseAuthorizationAction.Request req = buildRequest();
        req.amount = null;

        Test.startTest();
        List<ReverseAuthorizationAction.Result> results =
            ReverseAuthorizationAction.reverseAuthorizations(
                new List<ReverseAuthorizationAction.Request>{ req }
            );
        Test.stopTest();

        System.assertEquals(false, results[0].success);
        System.assert(
            results[0].errorMessage != null
                && results[0].errorMessage.containsIgnoreCase('amount'),
            'errorMessage should mention amount, got: ' + results[0].errorMessage
        );
        System.assertEquals(0, mock.callCount, 'API not called when validation fails');
    }

    @isTest
    static void thrownException_becomesFailureResult() {
        MockReverser mock = new MockReverser();
        mock.toThrow = new ApiTestException('simulated gateway failure');
        ReverseAuthorizationAction.reverser = mock;

        Test.startTest();
        List<ReverseAuthorizationAction.Result> results =
            ReverseAuthorizationAction.reverseAuthorizations(
                new List<ReverseAuthorizationAction.Request>{ buildRequest() }
            );
        Test.stopTest();

        System.assertEquals(false, results[0].success);
        System.assert(
            results[0].errorMessage != null
                && results[0].errorMessage.contains('simulated gateway failure'),
            'errorMessage should carry the thrown message, got: ' + results[0].errorMessage
        );
    }

    @isTest
    static void responseWithError_failsWithErrorMessage() {
        ConnectApi.AuthorizationReversalResponse resp = new ConnectApi.AuthorizationReversalResponse();
        ConnectApi.ErrorResponse err = new ConnectApi.ErrorResponse();
        err.message = 'auth not found';
        resp.error = err;

        Test.startTest();
        ReverseAuthorizationAction.Result r =
            ReverseAuthorizationAction.interpretResponse(resp);
        Test.stopTest();

        System.assertEquals(false, r.success);
        System.assertEquals('auth not found', r.errorMessage);
    }

    @isTest
    static void nullResponse_failsCleanly() {
        Test.startTest();
        ReverseAuthorizationAction.Result r =
            ReverseAuthorizationAction.interpretResponse(null);
        Test.stopTest();

        System.assertEquals(false, r.success);
        System.assertNotEquals(null, r.errorMessage);
    }

    @isTest
    static void gatewayLogWithSuccessCode_succeeds() {
        ConnectApi.AuthorizationReversalResponse resp = new ConnectApi.AuthorizationReversalResponse();
        ConnectApi.GatewayLogResponse log = new ConnectApi.GatewayLogResponse();
        log.gatewayResultCode = 'OK';
        resp.paymentGatewayLogs = new List<ConnectApi.GatewayLogResponse>{ log };

        Test.startTest();
        ReverseAuthorizationAction.Result r =
            ReverseAuthorizationAction.interpretResponse(resp);
        Test.stopTest();

        System.assertEquals(true, r.success, 'OK log should mark success');
        System.assertEquals(null, r.errorMessage);
    }

    @isTest
    static void gatewayLogWithNonSuccessCode_failsWithCodeInMessage() {
        ConnectApi.AuthorizationReversalResponse resp = new ConnectApi.AuthorizationReversalResponse();
        ConnectApi.GatewayLogResponse log = new ConnectApi.GatewayLogResponse();
        log.gatewayResultCode = 'declined';
        resp.paymentGatewayLogs = new List<ConnectApi.GatewayLogResponse>{ log };

        Test.startTest();
        ReverseAuthorizationAction.Result r =
            ReverseAuthorizationAction.interpretResponse(resp);
        Test.stopTest();

        System.assertEquals(false, r.success);
        System.assert(
            r.errorMessage != null && r.errorMessage.contains('declined'),
            'errorMessage should surface the gateway result code, got: ' + r.errorMessage
        );
    }

    @isTest
    static void multipleRequests_processedIndependently() {
        MockReverser mock = new MockReverser();
        mock.toReturn = new ConnectApi.AuthorizationReversalResponse();
        ReverseAuthorizationAction.reverser = mock;

        ReverseAuthorizationAction.Request bad = buildRequest();
        bad.paymentAuthorizationId = null;

        Test.startTest();
        List<ReverseAuthorizationAction.Result> results =
            ReverseAuthorizationAction.reverseAuthorizations(
                new List<ReverseAuthorizationAction.Request>{ buildRequest(), bad }
            );
        Test.stopTest();

        System.assertEquals(2, results.size());
        System.assertEquals(true, results[0].success, 'first request succeeds');
        System.assertEquals(false, results[1].success, 'second request fails validation');
    }
}