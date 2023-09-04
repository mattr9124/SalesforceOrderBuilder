/*
MIT License

Copyright (c) 2023 Matthew B. Rossner

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
 */
/**
 * Order Builder is a fluent style API to create orders for testing
 * Salesforce Order Management. This should generally never be used
 * in production but should be used to build Apex unit tests and also
 * as part of anonymous Apex scripts to test specific scenarios.
 *
 */
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

    public final static String ORDER_ITEM_TYPE_PRODUCT = 'Order Product';
    public final static String ORDER_ITEM_TYPE_DELIVERY = 'Delivery Charge';

    private final Datetime now = Datetime.now();
    private final Date today = now.date();

    private final List<ProductBuilder> productWrappers = new List<ProductBuilder>();
    private final List<OrderBuilder.PaymentInfo> payments = new List<OrderBuilder.PaymentInfo>();

    private final Map<String, Object> extraOrderFields = new Map<String, Object>();

    private Account account;
    private Pricebook2 pricebook2;
    private SalesChannel salesChannel;
    private OrderDeliveryMethod orderDeliveryMethod;
    private Decimal deliveryPrice;
    private Decimal taxRate = 0;
    private Date effectiveDate;
    private Datetime orderedDate;
    private Schema.Address shippingAddress;
    private Schema.Address billingAddress;

    private String orderName;
    private String orderReferenceNumber;

    private Boolean pricebookOptional = false;
    private Boolean deliveryOrderItem = true;
    private Boolean useAccountAddress = true;

    // default values
    private String taxLocaleType = 'Net';

    // status must be draft, and can be set later
    private final static String status = 'Draft';
    private Boolean activateOrder = false;

    private PaymentGateway paymentGateway;

    private OrderBuilder() {
    }

    /**
     * Creates a new Order Builder
     * @return
     */
    public static OrderBuilder newOrderBuilder() {
        return new OrderBuilder();
    }

    /**
     * Creates a new OrderBuilder with some default settings:
     * <ul>
     *     <li>Random order name</li>
     *     <li>Use account address</li>
     *     <li>Use standard pricebook</li>
     *     <li>Use today dates</li>
     *     <li>Activate the order immediately</li>
     * </ul>
     *
     * @return
     */
    public static OrderBuilder newOrderBuilderWithDefaults() {
        return new OrderBuilder()
                .useRandomOrderName()
                .useAccountAddress()
                .useStandardPricebook()
                .todayDates()
                .activated();
    }

    /**
     * Creates a new payment builder
     * @return
     */
    public static PaymentInfo paymentBuilder() {
        return new PaymentInfo();
    }

    /**
     * Creates a product builder for a given SKU and quantity
     * @param sku Product SKU - will match either Product2.StockKeepingUnit or Product2.ProductCode)
     * @param quantity Order item quantity
     *
     * @return
     */
    public static ProductBuilder productBySku(String sku, Integer quantity) {
        return new ProductBuilder(sku, quantity);
    }

    /**
     * Will build the order based on the inputs given. This will perform
     * all the necessary DML.
     *
     * Currently there is no validation for required fields and no error
     * handling, so this will throw various exceptions for missing fields
     * and potentially null pointer exceptions if certain important
     * elements are missing. In future versions (time-permitting) some
     * validations will be added to provide more meaningful error messages
     * in such cases. Although if all required fields are added then everything
     * should work as expected.
     *
     * @return
     */
    public Order build() {

        validate();

        if (useAccountAddress) {
            setAccountAddresses();
        }

        Order order = createOrder();

        if (!pricebookOptional) {
            order.Pricebook2Id = pricebook2.Id;
        }

        setExtraFields(order, extraOrderFields);

        insert order;

        // TODO add ability to create multiple delivery groups
        OrderDeliveryGroup orderDeliveryGroup = createOrderDeliveryGroup(order);

        // build order items
        OrderItem[] orderItems = buildOrderItems(order, orderDeliveryGroup);

        if (deliveryOrderItem) {
            OrderItem deliveryItem = createDeliveryOrderItem(order, orderDeliveryGroup);
            orderItems.add(deliveryItem);
        }

        if (pricebookOptional) {
            setListPriceOnOrderItems(orderItems);
        } else {
            setOrderItemPrices(orderItems, pricebook2);
        }

        insert orderItems;

        if (taxRate > 0) {
            addTaxLines(orderItems);
        }

        buildPayments(order, payments);

        if (activateOrder) {
            order.Status = 'Activated';
            update order;
        }

        return order;
    }

    private void validate() {
        fieldNotNull(this.account, 'Account is required');
        fieldNotNull(this.salesChannel, 'Sales channel is required');
        fieldNotNull(this.orderDeliveryMethod, 'Order delivery method is required');
    }

    private void fieldNotNull(Object field, String message) {
        if (field == null) throw new RequiredFieldException(message);
    }

    private void addTaxLines(OrderItem[] orderItems) {

        OrderItemTaxLineItem[] orderItemTaxLineItems = new List<OrderItemTaxLineItem>();

        for (OrderItem orderItem : orderItems) {
            orderItemTaxLineItems.add(new OrderItemTaxLineItem(
                    Name = orderItem.Type == ORDER_ITEM_TYPE_DELIVERY ? 'Delivery Charge Tax' :  orderItem.Product2.ProductCode + ' Tax',
                    Type = 'Estimated',
                    TaxEffectiveDate = today,
                    Amount = (orderItem.TotalLineAmount * taxRate).setScale(2),
                    Rate = taxRate,
                    OrderItemId = orderItem.Id
            ));
        }

        insert orderItemTaxLineItems;
    }

    private void setAccountAddresses() {
        Account accountWithAddress = [SELECT
                BillingStreet,
                BillingCity,
                BillingPostalCode,
                BillingState,
                BillingCountry,
                ShippingStreet,
                ShippingCity,
                ShippingPostalCode,
                ShippingState,
                ShippingCountry
        FROM Account WHERE Id = :account.Id];

        this.billingAddress = new Schema.Address(
                        Street = accountWithAddress.BillingStreet,
                        City = accountWithAddress.BillingCity,
                        PostalCode = accountWithAddress.BillingPostalCode,
                        State = accountWithAddress.BillingState,
                        Country = accountWithAddress.BillingCountry);

        this.shippingAddress = new Schema.Address(
                Street = accountWithAddress.ShippingStreet,
                City = accountWithAddress.ShippingCity,
                PostalCode = accountWithAddress.ShippingPostalCode,
                State = accountWithAddress.ShippingState,
                Country = accountWithAddress.ShippingCountry);
    }

    public OrderBuilder addProduct(ProductBuilder productBuilder) {
        this.productWrappers.add(productBuilder);
        return this;
    }

    public OrderBuilder withExtraFields(Map<String, Object> extraFields) {
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
        return pricebook([SELECT Id FROM Pricebook2 WHERE Name = :name]);
    }

    public OrderBuilder useAccountAddress() {
        this.useAccountAddress = true;
        return this;
    }
    
    public OrderBuilder shippingAndBillingAddress(Schema.Address address) {
        this.useAccountAddress = false;
        return shippingAddress(address).billingAddress(address);
    }

    public OrderBuilder shippingAddress(Schema.Address shippingAddress) {
        this.useAccountAddress = false;
        this.shippingAddress = shippingAddress;
        return this;
    }

    public OrderBuilder billingAddress(Schema.Address billingAddress) {
        this.useAccountAddress = false;
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

    public OrderBuilder taxRate(Decimal taxRate) {
        this.taxRate = taxRate;
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

    public OrderBuilder noDeliveryItem() {
        deliveryOrderItem = false;
        return this;
    }

    public OrderBuilder deliveryMethodById(Id deliveryMethodId) {
        return deliveryMethodById(deliveryMethodId, 0);
    }

    public OrderBuilder deliveryMethodById(Id deliveryMethodId, Decimal deliveryPrice) {
        return deliveryMethod(queryDeliveryMethod('Id = :id', new Map<String, Object> { 'id' => deliveryMethodId}), deliveryPrice);
    }

    public OrderBuilder deliveryMethodByProductName(String name) {
        return deliveryMethodByProductName(name, 0);
    }

    public OrderBuilder deliveryMethodByProductName(String name, Decimal deliveryPrice) {
        return deliveryMethod(queryDeliveryMethod('Product.Name = :name', new Map<String, Object> { 'name' => name}), deliveryPrice);
    }

    public OrderBuilder deliveryMethodByName(String name) {
        return deliveryMethodByNameWithPrice(name, 0);
    }

    public OrderBuilder deliveryMethodByNameWithPrice(String name, Decimal deliveryPrice) {
        return deliveryMethod(queryDeliveryMethod('Name = :name', new Map<String, Object> { 'name' => name}), deliveryPrice);
    }

    public OrderBuilder deliveryMethod(OrderDeliveryMethod orderDeliveryMethod, Decimal deliveryPrice) {
        this.orderDeliveryMethod = orderDeliveryMethod;
        this.deliveryPrice = deliveryPrice;
        return this;
    }

    private final static String DELIVERY_QUERY = 'SELECT Id, ProductId, Product.Name, Product.ProductCode, Product.StockKeepingUnit ' +
                                                 'FROM OrderDeliveryMethod WHERE {0}';

    private OrderDeliveryMethod queryDeliveryMethod(String whereClause, Map<String, Object> parameters) {
        String fullQuery = String.format(DELIVERY_QUERY, new Object[] {whereClause});
        OrderDeliveryMethod[] orderDeliveryMethod = Database.queryWithBinds(fullQuery, parameters, AccessLevel.USER_MODE);

        return orderDeliveryMethod[0];
    }

    public OrderBuilder addPaymentInfo(PaymentInfo paymentInfo) {
        payments.add(paymentInfo);
        return this;
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
                ShippingStreet = shippingAddress.Street,
                ShippingCity = shippingAddress.City,
                ShippingPostalCode = shippingAddress.PostalCode,
                ShippingState = shippingAddress.State,
                ShippingCountry = shippingAddress.Country,
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

                    SObject paymentObject;
                    switch on paymentInfo.creditCardMethod {
                        when AUTH {
                            paymentObject = new PaymentAuthorization();
                        }
                        when CAPTURE, SALE {
                            paymentObject = new Payment(Type = paymentInfo.creditCardMethod.name().toLowerCase().capitalize());
                        }
                    }
                    Decimal amount = determinePaymentAmount(paymentInfo, singlePayment, orderTotalAmount);
                    setCommonAndExtraPaymentFields(paymentObject, paymentGroup, paymentInfo, amount, cardPaymentMethod);

                    insert paymentObject;
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

    private void setCommonAndExtraPaymentFields(SObject paymentObject, PaymentGroup paymentGroup, PaymentInfo paymentInfo, Decimal amount, CardPaymentMethod cardPaymentMethod) {
        paymentObject.put('PaymentGroupId', paymentGroup.Id);
        paymentObject.put('PaymentGatewayId', paymentGateway.Id);
        paymentObject.put('PaymentMethodId', cardPaymentMethod.Id);
        paymentObject.put('ProcessingMode', 'External');
        paymentObject.put('GatewayRefNumber', paymentInfo.gatewayReferenceNumber);
        paymentObject.put('Amount', amount);
        paymentObject.put('CurrencyIsoCode', account.CurrencyIsoCode);
        paymentObject.put('Status', 'Processed');

        setExtraFields(paymentObject, paymentInfo.extraFields);
    }

    private Decimal determinePaymentAmount(PaymentInfo paymentInfo, Boolean singlePayment, Order orderTotalAmount) {
        Decimal amount = paymentInfo.paymentAmount == null || singlePayment ? orderTotalAmount.GrandTotalAmount : paymentInfo.paymentAmount;
        return amount;
    }

    private OrderItem[] buildOrderItems(Order order, OrderDeliveryGroup orderDeliveryGroup) {
        List<OrderItem> orderItems = new List<OrderItem>();

        for (ProductBuilder productWrapper : productWrappers) {
            orderItems.add(newOrderItemBuilder()
                            .order(order)
                            .orderDeliveryGroup(orderDeliveryGroup)
                            .productBySku(productWrapper.sku, productWrapper.quantity)
                            .unitPrice(productWrapper.unitPrice)
                            .withExtraFields(productWrapper.extraFields)
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

    private static void setExtraFields(SObject theObject, Map<String, Object> extraFields) {
        for (String key : extraFields.keySet()) {
            theObject.put(key, extraFields.get(key));
        }
    }

    private CardPaymentMethod createCreditCardPayment() {
        return new CardPaymentMethod(
                CardType = 'Visa',
                CardHolderName = account.Name,
                ExpiryYear = 2035,
                ExpiryMonth = 06,
                CardCategory = 'CreditCard',
                Status = 'Active',
                AccountId = account.Id,
                ProcessingMode = 'External'
        );
    }

    private OrderItem createDeliveryOrderItem(Order order, OrderDeliveryGroup orderDeliveryGroup) {

        OrderItem orderItem = newOrderItemBuilder(order)
                .deliveryChargeType()
                .orderDeliveryGroup(orderDeliveryGroup)
                .product(orderDeliveryMethod.Product, 1)
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

    private void setListPriceOnOrderItems(OrderItem[] orderItems) {
        for (OrderItem orderItem : orderItems) {
            orderItem.ListPrice = orderItem.UnitPrice;
        }
    }


    public static OrderItemBuilder newOrderItemBuilder() {
        return new OrderItemBuilder();
    }

    public static OrderItemBuilder newOrderItemBuilder(Order order) {
        return new OrderItemBuilder().order(order);
    }

    public class PaymentInfo {
        private E_PaymentType paymentType;
        private E_CreditCardMethod creditCardMethod;

        private String gatewayReferenceNumber;

        private final Map<String, Object> extraFields = new Map<String, Object>();

        private Decimal paymentAmount;

        PaymentInfo() {
        }

        public PaymentInfo creditCard() {
            paymentType = E_PaymentType.CREDIT_CARD;
            return this;
        }

        public PaymentInfo authorizedCreditCard() {
            return this.creditCard().authorization();
        }

        public PaymentInfo capturedCreditCard() {
            return this.creditCard().capture();
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

        public PaymentInfo gatewayReferenceNumber(String referenceNumber) {
            this.gatewayReferenceNumber = referenceNumber;
            return this;
        }

        public PaymentInfo paymentAmount(Decimal paymentAmount) {
            this.paymentAmount = paymentAmount;
            return this;
        }

        public PaymentInfo withExtraField(String fieldName, Object value) {
            this.extraFields.put(fieldName, value);
            return this;
        }

        public PaymentInfo withExtraFields(Map<String, Object> extraFields) {
            this.extraFields.putAll(extraFields);
            return this;
        }
    }

    public class ProductBuilder {
        private final String sku;
        private final Integer quantity;
        private Decimal unitPrice;
        private final Map<String, Object> extraFields = new Map<String, Object>();

        public ProductBuilder(String sku, Integer quantity) {
            this.sku = sku;
            this.quantity = quantity;
        }

        public ProductBuilder price(Decimal unitPrice) {
            this.unitPrice = unitPrice;
            return this;
        }

        public ProductBuilder withExtraField(String fieldName, Object value) {
            this.extraFields.put(fieldName, value);
            return this;
        }

        public ProductBuilder withExtraFields(Map<String, Object> extraFields) {
            this.extraFields.putAll(extraFields);
            return this;
        }
    }

    private class OrderItemBuilder {
        private Product2 product2;
        private Integer quantity;
        private Decimal unitPrice;
        private Order order;
        private OrderDeliveryGroup orderDeliveryGroup;
        private String type = ORDER_ITEM_TYPE_PRODUCT;

        private final Map<String, Object> extraFields = new Map<String, Object>();

        OrderItemBuilder() {
        }

        OrderItem build() {
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

            setExtraFields(orderItem, this.extraFields);

            return orderItem;
        }

        OrderItemBuilder productBySku(String sku, Integer quantity) {
            return product(
                    [SELECT Id FROM Product2 WHERE StockKeepingUnit = :sku OR ProductCode = :sku LIMIT 1],
                    quantity
            );
        }

        OrderItemBuilder product(Product2 product2, Integer quantity) {
            this.product2 = product2;
            this.quantity = quantity;
            return this;
        }

        OrderItemBuilder unitPrice(Decimal unitPrice) {
            this.unitPrice = unitPrice;
            return this;
        }

        OrderItemBuilder deliveryChargeType() {
            this.type = ORDER_ITEM_TYPE_DELIVERY;
            return this;
        }

        OrderItemBuilder order(Order order) {
            this.order = order;
            return this;
        }

        OrderItemBuilder orderDeliveryGroup(OrderDeliveryGroup orderDeliveryGroup) {
            this.orderDeliveryGroup = orderDeliveryGroup;
            return this;
        }

        OrderItemBuilder withExtraFields(Map<String, Object> extraFields) {
            this.extraFields.putAll(extraFields);
            return this;
        }
    }

    private class RequiredFieldException extends Exception {
    }

    private class UnsupportedPaymentTypeException extends Exception {
    }
}