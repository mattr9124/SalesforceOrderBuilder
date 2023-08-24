public with sharing class OrderBuilder {

    private Account account;
    private Pricebook2 pricebook2;
    private SalesChannel salesChannel;
    private OrderDeliveryMethod orderDeliveryMethod;
    private Datetime now = Datetime.now();
    private Date today = now.date();

    private Date effectiveDate;
    private Datetime orderedDate;
    private Address billingAddress;

    private String orderName;
    private String orderReferenceNumber;

    private final List<OrderItem> orderItems = new List<OrderItem>();

    // default values
    private String taxLocaleType = 'Net';
    private String status = 'Draft';

    private OrderBuilder() {
    }

    public static OrderBuilder newOrderBuilder() {
        return new OrderBuilder();
    }

    public static OrderItemBuilder orderItemBuilder() {
        return new OrderItemBuilder();
    }

    public Order build() {
        Order order = new Order(
                Name = orderName,
                AccountId = account.Id,
                Pricebook2Id = pricebook2.Id,
                SalesChannelId = salesChannel.Id,
                TaxLocaleType = taxLocaleType,
                Status = status,
                OrderedDate = orderedDate,
                EffectiveDate = effectiveDate,
                OrderReferenceNumber = orderReferenceNumber
//                BillingAddress = billingAddress
        );

        insert order;

        updateOrderItems(order, orderItems, pricebook2);

        insert orderItems;

        return order;
    }

    private void updateOrderItems(Order order, List<OrderItem> orderItems, Pricebook2 pricebook2) {

        Map<Id, OrderItem> productToOrderItemMapping = new Map<Id, OrderItem>();

        for (OrderItem orderItem : orderItems) {
            orderItem.OrderId = order.Id;
            productToOrderItemMapping.put(orderItem.Product2Id, orderItem);
        }

        for (PricebookEntry pricebookEntry : [
                SELECT Product2Id, UnitPrice
                FROM PricebookEntry
                WHERE Pricebook2Id = :pricebook2.Id
                AND Product2Id IN :productToOrderItemMapping.keySet()
        ]) {
            productToOrderItemMapping.get(pricebookEntry.Product2Id).UnitPrice = pricebookEntry.UnitPrice;
            productToOrderItemMapping.get(pricebookEntry.Product2Id).PricebookEntryId = pricebookEntry.Id;
        }
    }


    public OrderBuilder withAccountByName(String name) {
        withAccount([SELECT Id FROM Account WHERE Name = :name]);
        return this;
    }

    public OrderBuilder withAccount(Account account) {
        this.account = account;
        return this;
    }

    public OrderBuilder withStandardPricebook() {
        return withPricebook(Test.isRunningTest() ? new Pricebook2(Id = Test.getStandardPricebookId()) :
                [SELECT Id FROM Pricebook2 WHERE IsStandard = TRUE LIMIT 1]);
    }

    public OrderBuilder withPricebook(Pricebook2 pricebook2) {
        this.pricebook2 = pricebook2;
        return this;
    }

    public OrderBuilder withPricebookByName(String name) {

        return this;
    }
    public OrderBuilder withBillingAddress(Address billingAddress) {
        this.billingAddress = billingAddress;
        return this;
    }

    public OrderBuilder withSalesChannelByName(String name) {
        return withSalesChannel([SELECT Id FROM SalesChannel WHERE SalesChannelName = :name LIMIT 1]);
    }

    public OrderBuilder withSalesChannel(SalesChannel salesChannel) {
        this.salesChannel = salesChannel;
        return this;
    }

    public OrderBuilder withTodayDates() {
        this.effectiveDate = today;
        this.orderedDate = now;
        return this;
    }

    public OrderBuilder withEffectiveDate(Date effectiveDate) {
        this.effectiveDate = effectiveDate;
        return this;
    }

    public OrderBuilder withOrderedDate(Date orderedDate) {
        this.orderedDate = orderedDate;
        return this;
    }

    public OrderBuilder withProductBySku(String sku, Integer quantity) {
        orderItems.add(orderItemBuilder().withProductBySku(sku, quantity).build());
        return this;
    }

    public OrderBuilder withProduct(Product2 product2, Integer quantity) {
        orderItems.add(orderItemBuilder().withProduct(product2, quantity).build());
        return this;
    }

    public OrderBuilder withDeliveryMethodByName(String name) {
        return this;
    }

    public OrderBuilder withDeliveryMethod(OrderDeliveryMethod orderDeliveryMethod) {
        this.orderDeliveryMethod = orderDeliveryMethod;
        return this;
    }

    private class OrderItemBuilder {
        private Product2 product2;
        private Integer quantity;

        private OrderItemBuilder() {
        }

        public OrderItem build() {
            OrderItem orderItem = new OrderItem(
                    Product2Id = product2.Id,
                    Quantity = quantity
            );

            return orderItem;
        }

        OrderItemBuilder withProductBySku(String sku, Integer quantity) {
            return withProduct(
                    [SELECT Id FROM Product2 WHERE StockKeepingUnit = :sku OR ProductCode = :sku LIMIT 1],
                    quantity
            );
        }

        OrderItemBuilder withProduct(Product2 product2, Integer quantity) {
            this.product2 = product2;
            this.quantity = quantity;
            return this;
        }
    }
}