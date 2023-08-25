public with sharing class OrderBuilder {

    private Account account;
    private Pricebook2 pricebook2;
    private SalesChannel salesChannel;
    private OrderDeliveryMethod orderDeliveryMethod;
    private Datetime now = Datetime.now();
    private Date today = now.date();

    private Date effectiveDate;
    private Datetime orderedDate;
    private Schema.Address billingAddress;

    private String orderName;
    private String orderReferenceNumber;

    private final List<OrderItem> orderItems = new List<OrderItem>();

    // default values
    private String taxLocaleType = 'Net';
    private String status = 'Draft';

    //switches (defaults to false)
    private Boolean creditCartPayment;
    private String paymentType = 'Auth';
    private PaymentGateway paymentGateway;


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
                OrderReferenceNumber = orderReferenceNumber,
                BillingStreet = billingAddress.Street,
                BillingCity = billingAddress.City,
                BillingPostalCode = billingAddress.PostalCode,
                BillingState = billingAddress.State,
                BillingCountry = billingAddress.Country
        );

        insert order;

        // TODO create order delivery group

        updateOrderItems(order, orderItems, pricebook2);

        OrderItem deliveryItem = createDeliveryOrderItem(order, pricebook2, orderDeliveryMethod);
        orderItems.add(deliveryItem);

        insert orderItems;

        if (creditCartPayment) {

            createPaymentObjects(order);

        }

        return order;
    }

    private void createPaymentObjects(Order order) {
        PaymentGroup paymentGroup = new PaymentGroup(
                SourceObjectId = order.Id
        );

        CardPaymentMethod cardPaymentMethod = new CardPaymentMethod(
                CardType = 'Visa',
                CardHolderName = 'Bob Jones',
                ExpiryYear = 2035,
                ExpiryMonth = 06,
                CardCategory = 'CreditCard',
                Status = 'Active',
                AccountId = account.Id,
                ProcessingMode = 'External'
        );

        insert new SObject[]{
                paymentGroup, cardPaymentMethod
        };


        Order orderWithTotals = [SELECT GrandTotalAmount FROM Order WHERE Id = :order.Id];

        if (paymentType == 'Auth') {
//            createAuthorization();
        } else {
            System.debug(JSON.serializePretty(orderWithTotals));
            createPayment(orderWithTotals.GrandTotalAmount, cardPaymentMethod, paymentGroup);
        }
    }

    private Payment createPayment(Decimal totalAmount, CardPaymentMethod cardPaymentMethod, PaymentGroup paymentGroup) {
        Payment payment = new Payment(
                PaymentGroupId = paymentGroup.Id,
                ProcessingMode = 'External',
                Type = paymentType,
                PaymentGatewayId = paymentGateway.Id,
                AccountId = account.Id,
                PaymentMethodId = cardPaymentMethod.Id,
                Status = 'Processed',
                Amount = totalAmount
        );

        insert payment;

        return payment;
    }

    private OrderItem createDeliveryOrderItem(Order order, Pricebook2 pricebook2, OrderDeliveryMethod orderDeliveryMethod) {

        OrderItem orderItem = orderItemBuilder()
                .withProductBySku(orderDeliveryMethod.Product.ProductCode, 1)
                .withDeliveryChargeType()
                .build();

        orderItem.OrderId = order.Id;

        // TODO maybe figure a way to override delivery price since it might not exist on every pricebook
        PricebookEntry pricebookEntry = [
                SELECT UnitPrice
                FROM PricebookEntry
                WHERE Product2Id = :orderDeliveryMethod.ProductId
                AND Pricebook2Id = :pricebook2.Id
                LIMIT 1
        ];

        setOrderItemPrice(orderItem, pricebookEntry);

        return orderItem;
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
            setOrderItemPrice(productToOrderItemMapping.get(pricebookEntry.Product2Id), pricebookEntry);
        }
    }

    private void setOrderItemPrice(OrderItem orderItem, PricebookEntry pricebookEntry) {
        orderItem.UnitPrice = pricebookEntry.UnitPrice;
        orderItem.PricebookEntryId = pricebookEntry.Id;
    }

    public OrderBuilder withAnyPaymentGateway() {
        return withPaymentGateway([ // take the first one you find
                SELECT Id
                FROM PaymentGateway
                LIMIT 1
        ]);
    }

    public OrderBuilder withPaymentGatewayByName(String name) {
        return withPaymentGateway([
                SELECT Id
                FROM PaymentGateway
                WHERE PaymentGatewayName = :name
                LIMIT 1
        ]);
    }

    public OrderBuilder withPaymentGateway(PaymentGateway paymentGateway) {
        this.paymentGateway = paymentGateway;
        return this;
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
        return withPricebook(Test.isRunningTest() ? new Pricebook2(Id = Test.getStandardPricebookId()) : [SELECT Id FROM Pricebook2 WHERE IsStandard = TRUE LIMIT 1]);
    }

    public OrderBuilder withPricebook(Pricebook2 pricebook2) {
        this.pricebook2 = pricebook2;
        return this;
    }

    public OrderBuilder withPricebookByName(String name) {

        return this;
    }
    public OrderBuilder withBillingAddress(Schema.Address billingAddress) {
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
        return withDeliveryMethod([
                SELECT Id, ProductId, Product.Name, Product.ProductCode, Product.StockKeepingUnit
                FROM OrderDeliveryMethod
                WHERE Name = :name
                LIMIT 1
        ]);
    }

    public OrderBuilder withDeliveryMethod(OrderDeliveryMethod orderDeliveryMethod) {
        this.orderDeliveryMethod = orderDeliveryMethod;
        return this;
    }

    public OrderBuilder withCreditCardPayment() {
        this.creditCartPayment = true;
        return this;
    }

    public OrderBuilder withCapture() {
        this.paymentType = 'Capture';
        return this;
    }

    public OrderBuilder withSale() {
        this.paymentType = 'Sale';
        return this;
    }

    private class OrderItemBuilder {
        private Product2 product2;
        private Integer quantity;
        private String type = 'Order Product';

        private OrderItemBuilder() {
        }

        public OrderItem build() {
            OrderItem orderItem = new OrderItem(
                    Product2Id = product2.Id,
                    Quantity = quantity,
                    Type = type
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

        OrderItemBuilder withDeliveryChargeType() {
            this.type = 'Delivery Charge';
            return this;
        }
    }
}