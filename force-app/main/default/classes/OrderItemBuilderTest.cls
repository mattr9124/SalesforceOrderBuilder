@IsTest
private class OrderItemBuilderTest {
    @IsTest
    static void buildOrderItem() {
        // setup: create test data
        TestDataFactory.createBasicTestData();
        // and: create dummy objects
        Order order = new Order(Id = TestDataFactory.FAKE_ORDER_ID);
        OrderDeliveryGroup orderDeliveryGroup = new OrderDeliveryGroup(Id = TestDataFactory.FAKE_ORDER_DELIVERY_GROUP_ID);

        // when: creating an order item
        OrderItem orderItem = OrderItemBuilder.newOrderItemBuilder(order)
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
}