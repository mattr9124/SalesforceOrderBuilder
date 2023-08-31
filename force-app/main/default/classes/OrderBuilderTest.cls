
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

        //then: an order should be created

        //refetch
        order = refetchOrder(order);

        // and: order fields should match the inputs
        Assert.areEqual('Bob Jones', order.Account.Name, 'Account name is wrong');
        Assert.areEqual('In Store', order.SalesChannel.SalesChannelName, 'Sales channel name is wrong');
        Assert.areEqual('Net', order.TaxLocaleType, 'Tax type is wrong');
        Assert.areEqual('Draft', order.Status, 'Order status is wrong');
        Assert.areEqual(202.99, order.GrandTotalAmount, 'Order total is wrong');
        Assert.isNotNull(order.OrderNumber, 'Missing order number');
        Assert.isNotNull(order.EffectiveDate, 'Missing effective date');
        Assert.isNotNull(order.OrderedDate, 'Missing ordered date');

        // and: should be 2 order items - one product and one delivery
        Assert.isNotNull(order.OrderItems);
        Assert.isTrue(order.OrderItems.size() == 2, 'There should be 2 order item');

        OrderItem productItem = order.OrderItems[0];

        Assert.areEqual(OrderBuilder.ORDER_TYPE_PRODUCT, productItem.Type);
        Assert.areEqual('M12345', productItem.Product2.ProductCode);
        Assert.areEqual(99, productItem.UnitPrice);
        Assert.areEqual(198, productItem.TotalPrice);
        Assert.areEqual(2, productItem.Quantity);

        OrderItem deliveryItem = order.OrderItems[1];

        Assert.areEqual(OrderBuilder.ORDER_TYPE_DELIVERY, deliveryItem.Type);
        Assert.areEqual('DHL', deliveryItem.Product2.ProductCode);
        Assert.areEqual(4.99, deliveryItem.UnitPrice);
        Assert.areEqual(4.99, deliveryItem.TotalPrice);
        Assert.areEqual(1, deliveryItem.Quantity);
    }

    @IsTest
    static void buildOrderWithAccountAddress() {
        // setup: Create some test data
        TestDataFactory.createBasicTestData();

        //when: building an order with 1 product of quantity 2
        Order order = OrderBuilder.newOrderBuilder()
                .accountByName('Bob Jones')
                .salesChannelByName('In Store')
                .todayDates()
                .addProductBySku('M12345', 2)
                .deliveryMethodByName('DHL')
                .useAccountAddress()
                .useStandardPricebook()
                .build();

        //then: an order should be created with account address

        //refetch
        order = refetchOrder(order);

        Assert.isNotNull(order.OrderDeliveryGroups[0].DeliverToAddress, 'shipping address on delivery group is null');
        Assert.isNotNull(order.BillingAddress, 'billing address is null');
        Assert.isNotNull(order.ShippingAddress, 'shipping address is null');

    }

    @IsTest
    static void basicWithDefaultValues() {
        // setup: Create some test data
        TestDataFactory.createBasicTestData();

        //when: building an order with 1 product of quantity 2
        Order order = OrderBuilder.newOrderBuilderWithDefaults()
                .accountByName('Bob Jones')
                .salesChannelByName('In Store')
                .addProductBySku('M12345', 2)
                .deliveryMethodByName('DHL')
                .shippingAndBillingAddress(getTestAddress())
                .build();

        //then: an order should be created with some default values

        //refetch
        order = refetchOrder(order);

        Assert.isTrue(order.Name.startsWith('TEST-'), 'Missing or incorrect order name');
        Assert.areEqual(order.Name, order.OrderReferenceNumber, 'Order name and reference number should be the same');
        Assert.areEqual(Test.getStandardPricebookId(), order.Pricebook2Id, 'Order should be using standard pricebook ID');
        Assert.areEqual('Activated', order.Status, 'order should be activated');
        Assert.isNotNull(order.EffectiveDate, 'Missing effective date');
        Assert.isNotNull(order.OrderedDate, 'Missing ordered date');
    }

    @IsTest
    static void basicWithExtraFields() {
        // setup: Create some test data
        TestDataFactory.createBasicTestData();

        //when: building an order with extra fields
        String description = 'Cool test order';

        Order order = OrderBuilder.newOrderBuilderWithDefaults()
                .accountByName('Bob Jones')
                .salesChannelByName('In Store')
                .addProductBySku('M12345', 1)
                .deliveryMethodByName('DHL')
                .shippingAndBillingAddress(getTestAddress())
                .withExtraFields(new Map<String, Object> {'Description' => description})
                .build();

        //then: an order should be created with some default values

        //refetch
        order = refetchOrder(order);

        Assert.areEqual(description, order.Description, 'Extra field not set correctly');

    }

    @IsTest
    static void buildOrderWithCapturedPayment() {
        // setup: Create some test data
        TestDataFactory.createBasicTestData();

        //when: building an order with payment info
        // and: with credit card + capture
        Order order = getBuilderForPaymentTest()
                .addPaymentInfo(OrderBuilder.paymentBuilder()
                    .capturedCreditCard()
                    .gatewayReferenceNumber('PSP12345')
                    .withExtraFields(new Map<String, Object>{'GatewayResultCode' => '[accepted]'}))
                .build();

        //then: order should have a payment with capture and correct values
        Payment [] payments = [
                SELECT Type, ProcessingMode, Amount, Status, GatewayResultCode, GatewayRefNumber
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
        Assert.areEqual('[accepted]', payments[0].GatewayResultCode);
        Assert.areEqual('PSP12345', payments[0].GatewayRefNumber);
        Assert.areEqual(202.99, payments[0].Amount);
    }

    @IsTest
    static void buildOrderWithPaymentAuth() {
        // setup: Create some test data
        TestDataFactory.createBasicTestData();

        //when: building an order with payment info
        // and: with authorized CC
        Order order = getBuilderForPaymentTest()
                .addPaymentInfo(OrderBuilder.paymentBuilder()
                    .authorizedCreditCard()
                    .gatewayReferenceNumber('PSP12345')
                    .withExtraFields(new Map<String, Object> {'GatewayResultCode' => '[accepted]'}))
                .build();

        //then: order should have a payment with capture and correct values
        PaymentAuthorization [] paymentAuthorizations = [
                SELECT ProcessingMode, Amount, Status, GatewayResultCode, GatewayRefNumber
                FROM PaymentAuthorization
                WHERE PaymentGroupId IN (
                        SELECT Id
                        FROM PaymentGroup
                        WHERE SourceObjectId = :order.Id
                )
        ];

        Assert.isNotNull(paymentAuthorizations);
        Assert.isTrue(paymentAuthorizations.size() == 1, 'should be exactly 1 payment authorization line');
        Assert.areEqual('Processed', paymentAuthorizations[0].Status);
        Assert.areEqual('External', paymentAuthorizations[0].ProcessingMode);
        Assert.areEqual('[accepted]', paymentAuthorizations[0].GatewayResultCode);
        Assert.areEqual('PSP12345', paymentAuthorizations[0].GatewayRefNumber);
        Assert.areEqual(202.99, paymentAuthorizations[0].Amount);
    }

    @IsTest
    static void buildOrderWithMultiplePaymentAuths() {
        // setup: Create some test data
        TestDataFactory.createBasicTestData();

        //when: building an order with payment info
        // and: with 2 authorized CC (split payment)
        Order order = getBuilderForPaymentTest()
                .addPaymentInfo(OrderBuilder.paymentBuilder()
                        .authorizedCreditCard().paymentAmount(54.99)
                        .gatewayReferenceNumber('PSP12345')
                        .withExtraFields(new Map<String, Object> {'GatewayResultCode' => '[accepted]'}))
                .addPaymentInfo(OrderBuilder.paymentBuilder()
                        .authorizedCreditCard().paymentAmount(148)
                        .gatewayReferenceNumber('PSP54321')
                        .withExtraFields(new Map<String, Object> {'GatewayResultCode' => '[accepted]'}))
                .build();

        //then: order should have a payment with capture and correct values
        PaymentAuthorization [] paymentAuthorizations = [
                SELECT Amount, GatewayRefNumber
                FROM PaymentAuthorization
                WHERE PaymentGroupId IN (
                        SELECT Id
                        FROM PaymentGroup
                        WHERE SourceObjectId = :order.Id
                )
        ];

        Assert.isNotNull(paymentAuthorizations);
        Assert.isTrue(paymentAuthorizations.size() == 2, 'should be exactly 2 payment authorization lines');
        Assert.areEqual('PSP12345', paymentAuthorizations[0].GatewayRefNumber);
        Assert.areEqual('PSP54321', paymentAuthorizations[1].GatewayRefNumber);
        Assert.areEqual(54.99, paymentAuthorizations[0].Amount);
        Assert.areEqual(148, paymentAuthorizations[1].Amount);
    }

    private static OrderBuilder getBuilderForPaymentTest() {
        OrderBuilder builderForPayment = OrderBuilder.newOrderBuilderWithDefaults()
                .accountByName('Bob Jones')
                .salesChannelByName('In Store')
                .addProductBySku('M12345', 2)
                .deliveryMethodByName('DHL')
                .shippingAndBillingAddress(getTestAddress())
                .paymentGateway(new PaymentGateway());
        return builderForPayment;
    }

    @IsTest
    static void buildOrderNoPricebook() {
        // setup: Create some test data
        TestDataFactory.createBasicTestData();

        //when: building an order with 1 product of quantity 2
        Order order = OrderBuilder.newOrderBuilder()
                .accountByName('Bob Jones')
                .salesChannelByName('In Store')
                .todayDates()
                .addProductBySkuWithPrice('M12345', 2, 10)
                .deliveryMethodByNameWithPrice('DHL', 2)
                .shippingAndBillingAddress(getTestAddress())
                .noPricebook()
                .build();

        //then: should get an order with an order item and the correct price
        OrderItem[] orderItems = [
                SELECT UnitPrice, TotalLineAmount FROM OrderItem WHERE OrderId = :order.Id
        ];

        System.debug(JSON.serializePretty(orderItems));

        Assert.isNotNull(orderItems);
        Assert.isTrue(orderItems.size() == 2, 'There should be 2 order item');


    }

    @IsTest
    static void buildOrderItem() {
        // setup: create test data
        TestDataFactory.createBasicTestData();
        // and: create dummy objects
        Order order = new Order(Id = TestDataFactory.FAKE_ORDER_ID);
        OrderDeliveryGroup orderDeliveryGroup = new OrderDeliveryGroup(Id = TestDataFactory.FAKE_ORDER_DELIVERY_GROUP_ID);

        // when: creating an order item
        OrderItem orderItem = OrderBuilder.newOrderItemBuilder(order)
                .productBySku('M12345', 2)
                .orderDeliveryGroup(orderDeliveryGroup)
                .build();

        // then: order item should match

        Assert.isNotNull(orderItem);
        Assert.isNotNull(orderItem.Product2Id);

        Assert.areEqual(orderItem.Product2Id, [SELECT Id FROM Product2 WHERE ProductCode = 'M12345'].Id, 'wrong or missing SKU');
        Assert.areEqual(orderItem.Quantity, 2, 'wrong quantity');
        Assert.areEqual(OrderItem.Type, 'Order Product', 'wrong order item type');

    }

    private static Order refetchOrder(Order order) {
        return [
                SELECT Name, OrderNumber, Account.Name, Pricebook2.Name, SalesChannel.SalesChannelName,
                        GrandTotalAmount, Description,
                        TaxLocaleType, Status, OrderedDate, EffectiveDate, OrderReferenceNumber, BillingAddress, ShippingAddress,
                        (SELECT Product2.Name, Product2.ProductCode, UnitPrice, Quantity, TotalPrice, Type
                        FROM OrderItems
                ), (SELECT  DeliverToAddress FROM OrderDeliveryGroups)
                FROM Order
                WHERE Id = :order.Id
        ];
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