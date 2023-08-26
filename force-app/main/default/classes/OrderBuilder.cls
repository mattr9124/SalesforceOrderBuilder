public with sharing class OrderBuilder {

    /*
    TODO probably want to create a separate payment builder
    for now payments are integrated directly in this thing and
    it's getting a bit messy.
     */

    private Account account;
    private Pricebook2 pricebook2;
    private SalesChannel salesChannel;
    private OrderDeliveryMethod orderDeliveryMethod;
    private Datetime now = Datetime.now();
    private Date today = now.date();

    private Date effectiveDate;
    private Datetime orderedDate;
    private Schema.Address shippingAddress;
    private Schema.Address billingAddress;

    private String orderName;
    private String orderReferenceNumber;

    private final List<ProductWrapper> productWrappers = new List<ProductWrapper>();

    // default values
    private String taxLocaleType = 'Net';

    // status must be draft, and can be set later
    private final static String status = 'Draft';
    private Boolean activateOrder = false;

    private Boolean createOrderDeliveryGroup = true;

    // TODO need to make payment specific builder as it's complex
    //switches (defaults to false)
    private Boolean creditCartPayment = false;
    private String paymentType = 'Auth';
    private PaymentGateway paymentGateway;
    private Map<String, Object> extraPaymentFields;

    private OrderBuilder() {
    }

    public static OrderBuilder newOrderBuilderWithDefaults() {
        return new OrderBuilder()
                .useRandomOrderName()
                .useStandardPricebook()
                .todayDates()
                .activated();
    }

    public static OrderBuilder newOrderBuilder() {
        return new OrderBuilder();
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
                BillingCountry = billingAddress.Country,
                CurrencyIsoCode = account.CurrencyIsoCode
        );

        insert order;

        OrderDeliveryGroup orderDeliveryGroup = createOrderDeliveryGroup(order);

        // build order items
        OrderItem[] orderItems = buildOrderItems(order, productWrappers, orderDeliveryGroup, pricebook2);

        setOrderItemPrices(orderItems, pricebook2);

        OrderItem deliveryItem = createDeliveryOrderItem(order, pricebook2, orderDeliveryMethod, orderDeliveryGroup);
        orderItems.add(deliveryItem);

        insert orderItems;

        if (creditCartPayment) {
            createPaymentObjects(order);
        }

        if (activateOrder) {
            order.Status = 'Activated';
            update order;
        }

        return order;
    }

    private OrderItem[] buildOrderItems(Order order, List<OrderBuilder.ProductWrapper> productWrappers, OrderDeliveryGroup orderDeliveryGroup, Pricebook2 pricebook2) {
        List<OrderItem> orderItems = new List<OrderItem>();

        for (ProductWrapper productWrapper : productWrappers) {
            orderItems.add(
                    OrderItemBuilder.newOrderItemBuilder()
                            .order(order)
                            .orderDeliveryGroup(orderDeliveryGroup)
                            .productBySku(productWrapper.sku, productWrapper.quantity)
                            .build());

        }
        return orderItems;
    }

    private OrderDeliveryGroup createOrderDeliveryGroup(Order order) {

        OrderDeliveryGroup orderDeliveryGroup = new OrderDeliveryGroup(
                OrderId = order.Id,
                OrderDeliveryMethodId = orderDeliveryMethod.Id,
                DeliverToStreet = shippingAddress.Street,
                DeliverToCity = shippingAddress.City,
                DeliverToState = shippingAddress.State,
                DeliverToPostalCode = shippingAddress.PostalCode,
                DeliverToCountry = shippingAddress.Country,
                DeliverToName = account.Name
        );

        insert orderDeliveryGroup;

        return orderDeliveryGroup;
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

        for (String key : extraPaymentFields.keySet()) {
            payment.put(key, extraPaymentFields.get(key));
        }

        insert payment;

        System.debug(payment.Id);
        System.debug(payment.PaymentGroupId);

        return payment;
    }

    private OrderItem createDeliveryOrderItem(Order order, Pricebook2 pricebook2, OrderDeliveryMethod orderDeliveryMethod, OrderDeliveryGroup orderDeliveryGroup) {

        OrderItem orderItem = OrderItemBuilder.newOrderItemBuilder(order)
                .productBySku(orderDeliveryMethod.Product.ProductCode, 1)
                .deliveryChargeType()
                .orderDeliveryGroup(orderDeliveryGroup)
                .build();

        orderItem.OrderId = order.Id;

        // TODO maybe figure a way to override delivery price since it might not exist on every pricebook
        PricebookEntry pricebookEntry = [
                SELECT UnitPrice
                FROM PricebookEntry
                WHERE Product2Id = :orderDeliveryMethod.ProductId
                AND Pricebook2Id = :pricebook2.Id
                AND CurrencyIsoCode = :account.CurrencyIsoCode
                LIMIT 1
        ];

        setOrderItemPrice(orderItem, pricebookEntry);

        return orderItem;
    }

    private void setOrderItemPrices(List<OrderItem> orderItems, Pricebook2 pricebook2) {

        Map<Id, OrderItem> productToOrderItemMapping = new Map<Id, OrderItem>();

        for (OrderItem orderItem : orderItems) {
            productToOrderItemMapping.put(orderItem.Product2Id, orderItem);
        }

        for (PricebookEntry pricebookEntry : [
                SELECT Product2Id, UnitPrice
                FROM PricebookEntry
                WHERE Pricebook2Id = :pricebook2.Id
                AND Product2Id IN :productToOrderItemMapping.keySet()
                AND CurrencyIsoCode = :account.CurrencyIsoCode
        ]) {
            setOrderItemPrice(productToOrderItemMapping.get(pricebookEntry.Product2Id), pricebookEntry);
        }
    }

    private void setOrderItemPrice(OrderItem orderItem, PricebookEntry pricebookEntry) {
        orderItem.UnitPrice = pricebookEntry.UnitPrice;
        orderItem.PricebookEntryId = pricebookEntry.Id;
        orderItem.TotalLineAmount = orderItem.Quantity * pricebookEntry.UnitPrice; // this needs some additional data but for now good enough
    }

    public OrderBuilder useRandomOrderName() {
        orderName = 'TEST-' + (Math.random() * 999999999999L).longValue();
        orderReferenceNumber = orderName;
        return this;
    }

    public OrderBuilder anyPaymentGateway() {
        return paymentGateway([ // take the first one you find
                SELECT Id
                FROM PaymentGateway
                LIMIT 1
        ]);
    }

    public OrderBuilder paymentGatewayByName(String name) {
        return paymentGateway([
                SELECT Id
                FROM PaymentGateway
                WHERE PaymentGatewayName = :name
                LIMIT 1
        ]);
    }

    public OrderBuilder paymentGateway(PaymentGateway paymentGateway) {
        this.paymentGateway = paymentGateway;
        return this;
    }

    public OrderBuilder accountByName(String accountName) {
        account([SELECT Name, CurrencyIsoCode FROM Account WHERE Name = :accountName]);
        return this;
    }

    public OrderBuilder account(Account account) {
        this.account = account;
        return this;
    }

    public OrderBuilder useStandardPricebook() {
        return pricebook(Test.isRunningTest() ? new Pricebook2(Id = Test.getStandardPricebookId()) : [SELECT Id FROM Pricebook2 WHERE IsStandard = TRUE LIMIT 1]);
    }

    public OrderBuilder pricebook(Pricebook2 pricebook2) {
        this.pricebook2 = pricebook2;
        return this;
    }

    public OrderBuilder pricebookByName(String name) {

        return this;
    }

    public OrderBuilder shippingAndBillingAddress(Schema.Address address) {
        return shippingAddress(address).billingAddress(address);
    }

    public OrderBuilder shippingAddress(Schema.Address shippingAddress) {
        this.shippingAddress = shippingAddress;
        return this;
    }

    public OrderBuilder billingAddress(Schema.Address billingAddress) {
        this.billingAddress = billingAddress;
        return this;
    }

    public OrderBuilder salesChannelByName(String name) {
        return salesChannel([SELECT Id FROM SalesChannel WHERE SalesChannelName = :name LIMIT 1]);
    }

    public OrderBuilder salesChannel(SalesChannel salesChannel) {
        this.salesChannel = salesChannel;
        return this;
    }

    public OrderBuilder todayDates() {
        effectiveDate(today);
        orderedDate(now);
        return this;
    }

    public OrderBuilder effectiveDate(Date effectiveDate) {
        this.effectiveDate = effectiveDate;
        return this;
    }

    public OrderBuilder orderedDate(Datetime orderedDate) {
        this.orderedDate = orderedDate;
        return this;
    }

    public OrderBuilder activated() {
        activateOrder = true;
        return this;
    }

    public OrderBuilder addProductBySku(String sku, Integer quantity) {
        productWrappers.add(new ProductWrapper(sku, quantity));
        return this;
    }

    public OrderBuilder deliveryMethodByName(String name) {
        return deliveryMethod([
                SELECT Id, ProductId, Product.Name, Product.ProductCode, Product.StockKeepingUnit
                FROM OrderDeliveryMethod
                WHERE Name = :name
                LIMIT 1
        ]);
    }

    public OrderBuilder deliveryMethod(OrderDeliveryMethod orderDeliveryMethod) {
        this.orderDeliveryMethod = orderDeliveryMethod;
        return this;
    }

//    public OrderBuilder creditCardPayment() {
//        return this.creditCardPayment(new Map<String, Object> {});
//    }
//
//    public OrderBuilder creditCardPayment(Map<String, Object> extraFields) {
//        this.creditCartPayment = true;
//        this.extraPaymentFields = extraFields;
//        return this;
//    }
//
//    public OrderBuilder withCapture() {
//        this.paymentType = 'Capture';
//        return this;
//    }
//
//    public OrderBuilder withSale() {
//        this.paymentType = 'Sale';
//        return this;
//    }
//
    private class ProductWrapper {
        final String sku;
        final Integer quantity;

        ProductWrapper(String sku, Integer quantity) {
            this.sku = sku;
            this.quantity = quantity;
        }
    }
}