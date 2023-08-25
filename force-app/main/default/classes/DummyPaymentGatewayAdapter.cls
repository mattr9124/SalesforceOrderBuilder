public with sharing class DummyPaymentGatewayAdapter implements CommercePayments.PaymentGatewayAdapter  {
    public CommercePayments.GatewayResponse processRequest(CommercePayments.PaymentGatewayContext context) {
        return null;
    }
}