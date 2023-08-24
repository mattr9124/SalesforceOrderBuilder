
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
                .withStandardPricebook()
                .build();

        //then: should get an order with an order item and the correct price
        //refetch
        order = [
                SELECT Name, Account.Name, Pricebook2.Name, SalesChannel.SalesChannelName, TaxLocaleType, Status, OrderedDate, EffectiveDate, OrderReferenceNumber, (
                        SELECT Product2.Name, Product2.ProductCode, UnitPrice, Quantity, TotalPrice
                        FROM OrderItems
                )
                FROM Order
        ];

        System.debug(JSON.serializePretty(order));

        Assert.isNotNull(order.OrderItems);
        Assert.isTrue(order.OrderItems.size() == 1, 'There should be 1 order item');

    }

    private static void createBasicTestData() {
        Account account = new Account(Name = 'Bob Jones');
        SalesChannel salesChannel = new SalesChannel(SalesChannelName = 'In Store');
        Product2 product2 = new Product2(
                Name = 'Test product1',
                StockKeepingUnit = 'M12345',
                ProductCode = 'M12345'
        );
        insert new SObject[] {account, salesChannel, product2};

        PricebookEntry pricebookEntry = new PricebookEntry(
                Product2Id = product2.Id,
                Pricebook2Id = Test.getStandardPricebookId(),
                UnitPrice = 99
        );

        insert pricebookEntry;
    }
}