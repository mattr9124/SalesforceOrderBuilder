public with sharing class OrderItemBuilder {
    private Product2 product2;
    private Integer quantity;
    private Order order;
    private OrderDeliveryGroup orderDeliveryGroup;
    private String type = 'Order Product';

    private OrderItemBuilder() {
    }

    public static OrderItemBuilder newOrderItemBuilder() {
        return new OrderItemBuilder();
    }

    public static OrderItemBuilder newOrderItemBuilder(Order order) {
        return new OrderItemBuilder().order(order);
    }

    public OrderItem build() {
        OrderItem orderItem = new OrderItem(
                Product2Id = product2.Id,
                Quantity = quantity,
                OrderId = order.Id,
                OrderDeliveryGroupId = orderDeliveryGroup.Id,
                Type = type
        );

        return orderItem;
    }

    public OrderItemBuilder productBySku(String sku, Integer quantity) {
        return product(
                [SELECT Id FROM Product2 WHERE StockKeepingUnit = :sku OR ProductCode = :sku LIMIT 1],
                quantity
        );
    }

    public OrderItemBuilder product(Product2 product2, Integer quantity) {
        this.product2 = product2;
        this.quantity = quantity;
        return this;
    }

    public OrderItemBuilder deliveryChargeType() {
        this.type = 'Delivery Charge';
        return this;
    }

    public OrderItemBuilder order(Order order) {
        this.order = order;
        return this;
    }

    public OrderItemBuilder orderDeliveryGroup(OrderDeliveryGroup orderDeliveryGroup) {
        this.orderDeliveryGroup = orderDeliveryGroup;
        return this;
    }
}