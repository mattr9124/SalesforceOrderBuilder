/*
TODO maybe put this back into order builder class
While I like separating things, since this is meant to be
a utility, it might be worth keeping it in a single class
that way can easily be deployed and removed.
 */
public with sharing class OrderItemBuilder {
    public final static String ORDER_TYPE_PRODUCT = 'Order Product';
    public final static String ORDER_TYPE_DELIVERY = 'Delivery Charge';

    private Product2 product2;
    private Integer quantity;
    private Decimal unitPrice;
    private Order order;
    private OrderDeliveryGroup orderDeliveryGroup;
    private String type = ORDER_TYPE_PRODUCT;

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

        if (unitPrice != null && unitPrice > 0) {
            orderItem.UnitPrice = unitPrice;
            orderItem.TotalLineAmount = unitPrice * quantity; // TODO this logic is duplicated - find a better way
        }

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

    public OrderItemBuilder unitPrice(Decimal unitPrice) {
        this.unitPrice = unitPrice;
        return this;
    }

    public OrderItemBuilder deliveryChargeType() {
        this.type = ORDER_TYPE_DELIVERY;
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