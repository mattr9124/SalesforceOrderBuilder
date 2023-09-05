/*
Run as anonymous Apex.

This depends on existing data in the Org

Usage:

Build your order here - by default it will print the Order back to the debug log and then rollback the transaction.

This allows for getting your order to look the way you want before committing it.

When you're ready to commit, set the "rollback" boolean to false and run it again to commit the transaction.
 */

Boolean isRollback = true;

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
            .addProduct(OrderBuilder.productBySku('M12345', 2))
            .addProduct(OrderBuilder.productBySku('M54321', 1))
            .anyPaymentGateway()
            .useStandardPricebook()
            .addPaymentInfo(
                    OrderBuilder.paymentBuilder()
                            .authorizedCreditCard()
            )
            .deliveryMethodByName('DHL')
            .build();
    //refetch
    order = [
            SELECT FIELDS(STANDARD),
            (SELECT FIELDS(STANDARD) FROM OrderItems),
            (SELECT FIELDS(STANDARD) FROM OrderItemTaxLineItems),
            (SELECT FIELDS(STANDARD) FROM OrderDeliveryGroups)
            FROM Order
            WHERE Id = :order.Id
    ];

    System.debug(JSON.serializePretty(order));
} finally {
    if (isRollback) {
        Database.rollback(sp);
    }
}