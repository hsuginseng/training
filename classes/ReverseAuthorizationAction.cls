/**
 * ReverseAuthorizationAction
 *
 * Flow-invocable wrapper around ConnectApi.Payments.reverseAuthorization.
 * Returns a lightweight success/errorMessage result. Gateway-level declines
 * (which do not throw) are surfaced as failures so a Flow can branch on them.
 *
 * Testability:
 *   The ConnectApi call sits behind the IReverser interface so tests can
 *   inject a mock and exercise every branch (success, error response,
 *   gateway decline, thrown exception) without invoking ConnectApi.
 */
public with sharing class ReverseAuthorizationAction {

    @TestVisible
    private static final String GATEWAY_SUCCESS_CODE = 'OK';

    // -------- Invocable surface --------

    public class Request {
        @InvocableVariable(required=true label='Payment Authorization ID')
        public String paymentAuthorizationId;

        @InvocableVariable(required=true label='Amount')
        public Decimal amount;

        @InvocableVariable(label='Comments' description='Optional. Max 1000 characters.')
        public String comments;

        @InvocableVariable(label='Effective Date')
        public Datetime effectiveDate;

        @InvocableVariable(label='Account ID' description='Optional. Must match the payment authorization\'s account.')
        public String accountId;
    }

    public class Result {
        @InvocableVariable(label='Success')
        public Boolean success;

        @InvocableVariable(label='Error Message')
        public String errorMessage;
    }

    @InvocableMethod(
        label='Reverse Payment Authorization'
        description='Calls ConnectApi.Payments.reverseAuthorization. Returns success/errorMessage. Gateway declines are reported as failures.'
        category='Payments'
    )
    public static List<Result> reverseAuthorizations(List<Request> requests) {
        List<Result> results = new List<Result>();
        for (Request req : requests) {
            results.add(reverseOne(req));
        }
        return results;
    }

    // -------- Test seam --------

    public interface IReverser {
        ConnectApi.AuthorizationReversalResponse reverse(
            ConnectApi.AuthorizationReversalRequest input,
            String authorizationId
        );
    }

    private class ConnectApiReverser implements IReverser {
        public ConnectApi.AuthorizationReversalResponse reverse(
            ConnectApi.AuthorizationReversalRequest input,
            String authorizationId
        ) {
            return ConnectApi.Payments.reverseAuthorization(input, authorizationId);
        }
    }

    @TestVisible
    private static IReverser reverser = new ConnectApiReverser();

    // -------- Core logic --------

    private static Result reverseOne(Request req) {
        Result r = new Result();
        try {
            if (req == null || String.isBlank(req.paymentAuthorizationId)) {
                r.success = false;
                r.errorMessage = 'paymentAuthorizationId is required.';
                return r;
            }
            if (req.amount == null) {
                r.success = false;
                r.errorMessage = 'amount is required.';
                return r;
            }

            ConnectApi.AuthorizationReversalRequest input = new ConnectApi.AuthorizationReversalRequest();
            input.amount = req.amount.doubleValue();
            if (!String.isBlank(req.comments)) {
                input.comments = req.comments;
            }
            if (req.effectiveDate != null) {
                input.effectiveDate = req.effectiveDate;
            }
            if (!String.isBlank(req.accountId)) {
                input.accountId = req.accountId;
            }

            ConnectApi.AuthorizationReversalResponse resp =
                reverser.reverse(input, req.paymentAuthorizationId);
            return interpretResponse(resp);

        } catch (Exception e) {
            r.success = false;
            r.errorMessage = e.getTypeName() + ': ' + e.getMessage();
            return r;
        }
    }

    @TestVisible
    private static Result interpretResponse(ConnectApi.AuthorizationReversalResponse resp) {
        Result r = new Result();

        if (resp == null) {
            r.success = false;
            r.errorMessage = 'No response returned from ConnectApi.';
            return r;
        }

        if (resp.error != null) {
            r.success = false;
            r.errorMessage = String.isBlank(resp.error.message)
                ? 'ConnectApi error (no message provided).'
                : resp.error.message;
            return r;
        }

        if (resp.paymentGatewayLogs != null && !resp.paymentGatewayLogs.isEmpty()) {
            Boolean cancelled = false;
            String lastSeenCode = null;
            for (ConnectApi.GatewayLogResponse log : resp.paymentGatewayLogs) {
                if (log == null) {
                    continue;
                }
                lastSeenCode = log.gatewayResultCode;
                if (GATEWAY_SUCCESS_CODE.equalsIgnoreCase(lastSeenCode)) {
                    cancelled = true;
                }
            }
            if (!cancelled) {
                r.success = false;
                r.errorMessage = 'Gateway result code: '
                    + (String.isBlank(lastSeenCode) ? '(none)' : lastSeenCode);
                return r;
            }
        }

        r.success = true;
        return r;
    }
}