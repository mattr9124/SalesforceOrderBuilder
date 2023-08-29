public with sharing class DummyPaymentGatewayAdapter implements CommercePayments.PaymentGatewayAdapter  {
    public CommercePayments.GatewayResponse processRequest(CommercePayments.PaymentGatewayContext context) {
        PaymentRequestHandler paymentRequestHandler;

        switch on context.getPaymentRequestType() {
            when Capture {
                paymentRequestHandler = new CaptureHandler();
            }
            when ReferencedRefund {
                paymentRequestHandler = new RefundHandler();
            }
            when else {
                throw new PaymentException('Unsupported payment request type: ' + context.getPaymentRequestType());
            }
        }

        return paymentRequestHandler.handlePaymentRequest(context.getPaymentRequest());
    }

    public class PaymentException extends Exception {}

    interface PaymentRequestHandler {
        /**
         * @param paymentRequest
         *
         * @return
         */
        CommercePayments.GatewayResponse handlePaymentRequest(CommercePayments.PaymentGatewayRequest paymentRequest);
    }

    class CaptureHandler implements PaymentRequestHandler {
        public CommercePayments.GatewayResponse handlePaymentRequest(CommercePayments.PaymentGatewayRequest paymentRequest) {
            CommercePayments.CaptureRequest captureRequest = (CommercePayments.CaptureRequest) paymentRequest;
            CommercePayments.CaptureResponse captureResponse = new CommercePayments.CaptureResponse();
            captureResponse.setSalesforceResultCodeInfo(new CommercePayments.SalesforceResultCodeInfo(CommercePayments.SalesforceResultCode.Success));
            captureResponse.setAmount(captureRequest.amount);
            captureResponse.setGatewayReferenceNumber(String.valueOf((Math.random() * 99999999999L).longValue()));
            captureResponse.setGatewayResultCode('[accepted]');
            captureResponse.setGatewayMessage('Dummy adapter - always accepts');
            return captureResponse;
        }
    }

    class RefundHandler implements PaymentRequestHandler {
        public CommercePayments.GatewayResponse handlePaymentRequest(CommercePayments.PaymentGatewayRequest paymentRequest) {
            // TODO implement this
            throw new PaymentException('Refund not yet implemented...');
        }
    }
}
