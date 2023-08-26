
@IsTest
private class OrderBuilderTest {

    @IsTest
    static void buildOrderTest() {
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