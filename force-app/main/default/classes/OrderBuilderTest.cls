
@IsTest
private class OrderBuilderTest {
    @IsTest
    static void buildOrderTest() {
        // setup: Create some test data
        createBasicTestData();

        //when: building an order with 1 product of quantity 2
        Order order = OrderBuilder.newOrderBuilder()
                .withAccountByName('Bob Jones')
                .withSalesChannelByName('In Store')
                .withTodayDates()
                .withProductBySku('M12345', 2)
                .withDeliveryMethodByName('DHL')
                .withBillingAddress(getTestAddress())
                .withStandardPricebook()
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

    private static void createBasicTestData() {
        Account account = new Account(Name = 'Bob Jones');
        SalesChannel salesChannel = new SalesChannel(SalesChannelName = 'In Store');
        Product2 product2 = new Product2(
                Name = 'Test product1',
                StockKeepingUnit = 'M12345',
                ProductCode = 'M12345'
        );

        Product2 deliveryProduct = new Product2(
                Name = 'DHL',
                StockKeepingUnit = 'DHL',
                ProductCode = 'DHL'
        );
        insert new SObject[] {account, salesChannel, product2, deliveryProduct};

        PricebookEntry pricebookEntry = new PricebookEntry(
                Product2Id = product2.Id,
                Pricebook2Id = Test.getStandardPricebookId(),
                UnitPrice = 99
        );

        PricebookEntry deliveryPricebookEntry = new PricebookEntry(
                Product2Id = deliveryProduct.Id,
                Pricebook2Id = Test.getStandardPricebookId(),
                UnitPrice = 4.99
        );

        OrderDeliveryMethod orderDeliveryMethod = new OrderDeliveryMethod(
                Name = 'DHL',
                ProductId = deliveryProduct.Id
        );

        insert new SObject[] {pricebookEntry, deliveryPricebookEntry, orderDeliveryMethod};
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