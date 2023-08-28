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
            .addProductBySku('M12345', 2)
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
            SELECT Name, Account.Name, Pricebook2.Name, SalesChannel.SalesChannelName, TaxLocaleType, Status, OrderedDate, EffectiveDate, OrderReferenceNumber, (
                    SELECT Product2.Name, Product2.ProductCode, UnitPrice, Quantity, TotalPrice
                    FROM OrderItems
            )
            FROM Order
    ];

    System.debug(JSON.serializePretty(order));
} finally {
    if (isRollback) {
        Database.rollback(sp);
    }
}