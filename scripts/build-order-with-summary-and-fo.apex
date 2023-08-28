/*
Run as anonymous Apex.

This depends on existing data in the Org

This one will use the connect helper to create the order summary and a fulfillment order.

You can do all that with ConnectAPI, but this does it with much less code.

Usage:

Build your order here - by default it will print the Order back to the debug log and then rollback the transaction.

This allows for getting your order to look the way you want before committing it.

When you're ready to commit, set the "rollback" boolean to false and run it again to commit the transaction.
 */

Savepoint sp = Database.setSavepoint();
try {
    Order order = OrderBuilder.newOrderBuilder()
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
            .todayDates()
            .addProductBySku('M12345', 2)
            .anyPaymentGateway()
            .useStandardPricebook()
            .activated()
            .addPaymentInfo(
                    OrderBuilder.paymentBuilder()
                            .creditCard().sale()
            )
            .deliveryMethodByName('DHL')
            .build();

    Id orderSummaryId = OmsConnectHelper.createOrderSummary(order.Id).orderSummaryId;

    List<Id> fulfillmentOrderIds = OmsConnectHelper.createFulfillmentOrder(orderSummaryId, 'WH1', 'warehouse').fulfillmentOrderIds;
    // do something with FO IDs

    System.debug(JSON.serializePretty(
    [
            SELECT OrderNumber, GrandTotalAmount, (SELECT Name, ProductCode, UnitPrice, TotalLineAmount FROM OrderItemSummaries), (SELECT FullName, AuthorizationAmount, CapturedAmount, BalanceAmount FROM OrderPaymentSummaries), (SELECT TotalAmount FROM FulfillmentOrders)
            FROM OrderSummary
            WHERE Id = :orderSummaryId
    ]));
} finally {
    Database.rollback(sp);
}
