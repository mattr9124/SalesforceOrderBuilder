/*
Run as anonymous Apex.

This depends on existing data in the Org

Usage:

Build your order here - by default it will print the Order back to the debug log and then rollback the transaction.

This allows for getting your order to look the way you want before committing it.

When you're ready to commit, set the "rollback" boolean to false and run it again to commit the transaction.
 */

Boolean isRollback = false;

Savepoint sp = Database.setSavepoint();
try {
    Order order = OrderBuilder.newOrderBuilderWithDefaults()
            .accountByName('Bob Jones')
            .salesChannelByName('InStore')
            .shippingAndBillingAddress(new Schema.Address(
                    Street = 'Test',
                    City = 'Test',
                    PostalCode = '12345',
                    State = 'NY',
                    Country = 'US'
            )
            )
            .addProductBySku('M12345', 2)
            .anyPaymentGateway()
            .addPaymentInfo(
                    OrderBuilder.paymentBuilder()
                            .authorizedCreditCard()
            )
            .deliveryMethodByName('DHL')
            .build();

    Id orderSummaryId = OmsConnectHelper.createOrderSummary(order.Id).orderSummaryId;
    Id fulfillmentOrderId = OmsConnectHelper.createFulfillmentOrder(orderSummaryId, 'WH1', 'warehouse').fulfillmentOrderIds[0];

    update new FulfillmentOrder(
            Id = fulfillmentOrderId,
            Status = 'Fulfilled'
    );

    Id invoiceId = ConnectApi.FulfillmentOrder.createInvoice(fulfillmentOrderId, new ConnectApi.FulfillmentOrderInvoiceInputRepresentation()).invoiceId;

    Object result = OmsConnectHelper.ensureFunds(orderSummaryId, invoiceId);

    System.debug('Order summary ID: ' + orderSummaryId);
    System.debug(JSON.serializePretty(result));

} finally {
    if (isRollback) {
        Database.rollback(sp);
    }
}