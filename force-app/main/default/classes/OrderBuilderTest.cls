
@IsTest
private class OrderBuilderTest {

    @IsTest
    static void buildOrderBasic() {
        // setup: Create some test data
        TestDataFactory.createBasicTestData();

        //when: building an order with 1 product of quantity 2
        Order order = OrderBuilder.newOrderBuilder()
                .accountByName('Bob Jones')
                .salesChannelByName('In Store')
                .todayDates()
                .addProductBySku('M12345', 2)
                .deliveryMethodByName('DHL')
                .shippingAndBillingAddress(getTestAddress())
                .useStandardPricebook()
                .build();

        //then: should get an order with an order item and the correct price
        //refetch
        order = [
                SELECT Name, Account.Name, Pricebook2.Name, SalesChannel.SalesChannelName, TaxLocaleType, Status, OrderedDate, EffectiveDate, OrderReferenceNumber,
                        BillingStreet, BillingCity, BillingPostalCode, BillingState, BillingCountry,
                (

                        SELECT Product2.Name, Product2.ProductCode, UnitPrice, Quantity, TotalPrice, Type
                        FROM OrderItems
                )
                FROM Order
        ];

        System.debug(JSON.serializePretty(order));

        Assert.isNotNull(order.OrderItems);
        Assert.isTrue(order.OrderItems.size() == 2, 'There should be 2 order item');

    }
    @IsTest
    static void buildOrderWithPayment() {
        // setup: Create some test data
        TestDataFactory.createBasicTestData();

        //when: building an order with payment info
        // and: with credit card + capture
        Order order = OrderBuilder.newOrderBuilder()
                .accountByName('Bob Jones')
                .salesChannelByName('In Store')
                .todayDates()
                .addProductBySku('M12345', 1)
                .deliveryMethodByName('DHL')
                .shippingAndBillingAddress(getTestAddress())
                .useStandardPricebook()
                .paymentGateway(new PaymentGateway())
                .addPaymentInfo(
                        OrderBuilder.paymentBuilder()
                                .creditCard()
                                .capture())
                .build();

        //then: order should have a payment with capture and correct values
        Payment [] payments = [
                SELECT Type, ProcessingMode, Amount, Status
                FROM Payment
                WHERE PaymentGroupId IN (
                        SELECT Id
                        FROM PaymentGroup
                        WHERE SourceObjectId = :order.Id
                )
        ];

        Assert.isNotNull(payments);
        Assert.isTrue(payments.size() == 1, 'should be exactly 1 payment line');
        Assert.areEqual('Capture', payments[0].Type);
        Assert.areEqual('Processed', payments[0].Status);
        Assert.areEqual('External', payments[0].ProcessingMode);
        Assert.areEqual(103.99, payments[0].Amount);

    }
    private static Schema.Address getTestAddress() {
        return new Schema.Address(
                Street = 'Test',
                City = 'Test',
                PostalCode = '12345',
                State = 'NY',
                Country = 'US'
        );
    }
}