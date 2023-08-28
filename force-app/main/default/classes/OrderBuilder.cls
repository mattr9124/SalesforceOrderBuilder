public with sharing class OrderBuilder {

    /*
    NOTE: Using E_ prefix to avoid naming conflicts
    If using PaymentType directly, it works but only
    if fully qualified which makes a lot more typing.
     */
    private enum E_PaymentType {
        CREDIT_CARD, DIGITAL_WALLET
    }

    private enum E_CreditCardMethod {
        AUTH, CAPTURE, SALE
    }


    private Account account;
    private Pricebook2 pricebook2;
    private SalesChannel salesChannel;
    private OrderDeliveryMethod orderDeliveryMethod;
    private Decimal deliveryPrice;
    private Datetime now = Datetime.now();
    private Date today = now.date();

    private Date effectiveDate;
    private Datetime orderedDate;
    private Schema.Address shippingAddress;
    private Schema.Address billingAddress;

    private String orderName;
    private String orderReferenceNumber;

    private final List<ProductBuilder> productWrappers = new List<ProductBuilder>();
    private final List<OrderBuilder.PaymentInfo> payments = new List<OrderBuilder.PaymentInfo>();

    private Boolean pricebookOptional = false;

    // default values
    private String taxLocaleType = 'Net';

    // status must be draft, and can be set later
    private final static String status = 'Draft';
    private Boolean activateOrder = false;

    private PaymentGateway paymentGateway;

    private final Map<String, Object> extraOrderFields = new Map<String, Object>();
    private final Map<String, Object> extraPaymentFields = new Map<String, Object>();

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

    public static PaymentInfo paymentBuilder() {
        return new PaymentInfo();
    }

    public Order build() {
        Order order = createOrder();

        if (!pricebookOptional) {
            order.Pricebook2Id = pricebook2.Id;
        }

        setExtraFields(order, extraOrderFields);

        insert order;

        OrderDeliveryGroup orderDeliveryGroup = createOrderDeliveryGroup(order);

        // build order items
        OrderItem[] orderItems = buildOrderItems(order, orderDeliveryGroup);

        OrderItem deliveryItem = createDeliveryOrderItem(order, orderDeliveryGroup);
        orderItems.add(deliveryItem);

        if (!pricebookOptional) {
            setOrderItemPrices(orderItems, pricebook2);
        }

        insert orderItems;

        buildPayments(order, payments);

        if (activateOrder) {
            order.Status = 'Activated';
            update order;
        }

        return order;
    }

    public OrderBuilder extraFields(Map<String, Object> extraFields) {
        this.extraOrderFields.putAll(extraFields);
        return this;
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

    public OrderBuilder noPricebook() {
        pricebookOptional = true;
        return this;
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
        productWrappers.add(new ProductBuilder(sku, quantity));
        return this;
    }

    public OrderBuilder addProductBySkuWithPrice(String sku, Integer quantity, Decimal unitPrice) {
        productWrappers.add(new ProductBuilder(sku, quantity, unitPrice));
        return this;
    }

    public OrderBuilder deliveryMethodByName(String name) {
        return deliveryMethodByNameWithPrice(name, 0);
    }

    public OrderBuilder deliveryMethodByNameWithPrice(String name, Decimal deliveryPrice) {
        return deliveryMethod([
                SELECT Id, ProductId, Product.Name, Product.ProductCode, Product.StockKeepingUnit
                FROM OrderDeliveryMethod
                WHERE Name = :name
                LIMIT 1
        ], deliveryPrice);
    }

    public OrderBuilder deliveryMethod(OrderDeliveryMethod orderDeliveryMethod, Decimal deliveryPrice) {
        this.orderDeliveryMethod = orderDeliveryMethod;
        this.deliveryPrice = deliveryPrice;
        return this;
    }

    public OrderBuilder addPaymentInfo(PaymentInfo paymentInfo) {
        payments.add(paymentInfo);
        return this;
    }

    public PaymentInfo authorizedCreditCardPayment() {
        return paymentBuilder().creditCard().authorization();
    }

    public PaymentInfo capturedCreditCardPayment() {
        return paymentBuilder().creditCard().capture();
    }

    public OrderBuilder useRandomOrderName() {
        String randomName = 'TEST-' + (Math.random() * 999999999999L).longValue();
        orderName(randomName);
        orderReferenceNumber(randomName);
        return this;
    }

    public OrderBuilder orderName(String name) {
        this.orderName = name;
        return this;
    }

    public OrderBuilder orderReferenceNumber(String orderReferenceNumber) {
        this.orderReferenceNumber = orderReferenceNumber;
        return this;
    }

    public OrderBuilder anyPaymentGateway() {
        return paymentGateway([ // take the first one you find
                SELECT Id
                FROM PaymentGateway
                LIMIT 1
        ]);
    }

    private Order createOrder() {
        Order order = new Order(
                Name = orderName,
                AccountId = account.Id,
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
        return order;
    }

    private void buildPayments(Order order, List<OrderBuilder.PaymentInfo> paymentInfos) {

        Order orderTotalAmount = [SELECT GrandTotalAmount FROM Order WHERE Id = :order.Id];
        Boolean singlePayment = paymentInfos.size() == 1;

        for (PaymentInfo paymentInfo : payments) {
            PaymentGroup paymentGroup = new PaymentGroup(
                    SourceObjectId = order.Id
            );


            switch on paymentInfo.paymentType {
                when CREDIT_CARD {
                    CardPaymentMethod cardPaymentMethod = createCreditCardPayment();

                    insert new SObject[]{
                            paymentGroup, cardPaymentMethod
                    };

                    switch on paymentInfo.creditCardMethod {
                        when AUTH {
                            // TODO implement this!
                            throw new UnsupportedPaymentTypeException();
                        }
                        when CAPTURE, SALE {
                            Decimal amount = paymentInfo.paymentAmount == null || singlePayment ? orderTotalAmount.GrandTotalAmount : paymentInfo.paymentAmount;
                            createPayment(amount, cardPaymentMethod, paymentGroup, paymentInfo.creditCardMethod.name());
                        }
                    }
                }
                when DIGITAL_WALLET {
                    // TODO implement this!
                    throw new UnsupportedPaymentTypeException();
                }
                when else {
                    throw new UnsupportedPaymentTypeException();
                }
            }

        }
    }

    private OrderItem[] buildOrderItems(Order order, OrderDeliveryGroup orderDeliveryGroup) {
        List<OrderItem> orderItems = new List<OrderItem>();

        for (ProductBuilder productWrapper : productWrappers) {
            orderItems.add(
                    OrderItemBuilder.newOrderItemBuilder()
                            .order(order)
                            .orderDeliveryGroup(orderDeliveryGroup)
                            .productBySku(productWrapper.sku, productWrapper.quantity)
                            .unitPrice(productWrapper.unitPrice)
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

    private Payment createPayment(Decimal totalAmount, CardPaymentMethod cardPaymentMethod, PaymentGroup paymentGroup, String paymentType) {
        Payment payment = new Payment(
                PaymentGroupId = paymentGroup.Id,
                ProcessingMode = 'External',
                Type = paymentType.toLowerCase().capitalize(),
                PaymentGatewayId = paymentGateway.Id,
                AccountId = account.Id,
                PaymentMethodId = cardPaymentMethod.Id,
                Status = 'Processed',
                Amount = totalAmount
        );

        setExtraFields(payment, extraPaymentFields);

        insert payment;

        return payment;
    }

    private void setExtraFields(SObject theObject, Map<String, Object> extraFields) {
        for (String key : extraFields.keySet()) {
            theObject.put(key, extraFields.get(key));
        }
    }

    private CardPaymentMethod createCreditCardPayment() {
        return new CardPaymentMethod(
                CardType = 'Visa',
                CardHolderName = 'Bob Jones',
                ExpiryYear = 2035,
                ExpiryMonth = 06,
                CardCategory = 'CreditCard',
                Status = 'Active',
                AccountId = account.Id,
                ProcessingMode = 'External'
        );
    }

    private OrderItem createDeliveryOrderItem(Order order, OrderDeliveryGroup orderDeliveryGroup) {

        OrderItem orderItem = OrderItemBuilder.newOrderItemBuilder(order)
                .productBySku(orderDeliveryMethod.Product.ProductCode, 1)
                .deliveryChargeType()
                .orderDeliveryGroup(orderDeliveryGroup)
                .build();

        orderItem.OrderId = order.Id;

        if (deliveryPrice != null && deliveryPrice > 0) {
            setOrderItemPrice(orderItem, deliveryPrice);
        }

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

    private void setOrderItemPrice(OrderItem orderItem, Decimal priceValue) {
        orderItem.UnitPrice = priceValue;
        orderItem.TotalLineAmount = orderItem.Quantity * priceValue; // this needs some additional data but for now good enough
    }

    private void setOrderItemPrice(OrderItem orderItem, PricebookEntry pricebookEntry) {
        orderItem.PricebookEntryId = pricebookEntry.Id;
        setOrderItemPrice(orderItem, pricebookEntry.UnitPrice);
    }

    public class PaymentInfo {
        private E_PaymentType paymentType;
        private E_CreditCardMethod creditCardMethod;

        private Decimal paymentAmount;

        PaymentInfo() {
        }

        public PaymentInfo creditCard() {
            paymentType = E_PaymentType.CREDIT_CARD;
            return this;
        }

        public PaymentInfo digitalWallet() {
            paymentType = OrderBuilder.E_PaymentType.DIGITAL_WALLET;
            return this;
        }

        public PaymentInfo authorization() {
            creditCardMethod = OrderBuilder.E_CreditCardMethod.AUTH;
            return this;
        }

        public PaymentInfo capture() {
            creditCardMethod = OrderBuilder.E_CreditCardMethod.CAPTURE;
            return this;
        }

        public PaymentInfo sale() {
            creditCardMethod = OrderBuilder.E_CreditCardMethod.SALE;
            return this;
        }

        public PaymentInfo paymentAmount(Decimal paymentAmount) {
            this.paymentAmount = paymentAmount;
            return this;
        }
    }

    private class ProductBuilder {
        final String sku;
        final Integer quantity;
        final Decimal unitPrice;

        ProductBuilder(String sku, Integer quantity) {
            this(sku, quantity, 0);
        }

        ProductBuilder(String sku, Integer quantity, Decimal unitPrice) {
            this.sku = sku;
            this.quantity = quantity;
            this.unitPrice = unitPrice;
        }
    }

    private class UnsupportedPaymentTypeException extends Exception {}
}