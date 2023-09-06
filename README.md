# Project Overview

This project is meant for Salesforce developers who are working on Salesforce Order Management projects. The goal is to easily create orders in a specific state using a fluent style API. 

This can be useful for:
* Developing new features
* Debugging issues
* Creating unit tests

and hopefully more...

Check out this video demo here: https://youtu.be/sAjTY5Va5GE

# Usage

Examples that can be run as anonymous Apex with existing data in the Org.

Simple order with a product and no payments:
```apex
Order order = OrderBuilder.newOrderBuilder()
        .accountByName('Bob Jones')
        .useAccountAddress()
        .salesChannelByName('In Store')
        .todayDates()
        .addProduct(OrderBuilder.productBySku('M12345', 2)) // will look up product price in the standard pricebook
        .deliveryMethodByName('DHL')
        .useStandardPricebook()
        .build();
```

Get a default order builder, which will return the following: 
```apex
OrderBuilder.newOrderBuilderWithDefaults();
// returns the following
OrderBuilder()
    .useRandomOrderName()
    .useAccountAddress()
    .useStandardPricebook()
    .todayDates()
    .activated();
```

Add extra fields (for example custom fields):
```apex
OrderBuilder.newOrderBuilderWithDefaults()
    .accountByName('Bob Jones')
    .salesChannelByName('In Store')
    .withExtraField('My_Custom_Field1__c', 'value1')
    .withExtraField('My_Custom_Field2__c', 'value2')
    .addProduct(OrderBuilder.productBySku('M12345', 2).withExtraField('Item_Custom_Field__c', 'value3'))
    .build();
```

If you have many extra fields to add you can also pass in a Map instead:
```apex
OrderBuilder.newOrderBuilderWithDefaults()
    .withExtraFields(new Map<String, Object> {
            'My_Custom_Field1__c' => 'value1',
            'My_Custom_Field2__c' => 'value1',
            'My_Custom_NumericField__c' => 25
    })
    //...
    .build();
```

An order with already captured payment:
```apex
OrderBuilder.newOrderBuilderWithDefaults()
    .accountByName('Bob Jones')
    .salesChannelByName('In Store')
    .addProduct(OrderBuilder.productBySku('M12345', 2))
    .deliveryMethodByName('DHL')
    .paymentGatewayByName('Adyen')
    .addPaymentInfo(OrderBuilder.paymentBuilder() // will set the payment amount to the order total 
        .capturedCreditCard()
        .gatewayReferenceNumber('PSP12345')
        .withExtraField('GatewayResultCode', '[accepted]')) // add extra fields
    .build();
```

Order with multiple payment authorizations (payment with 2 cards for $50 and $30):
```apex
OrderBuilder.newOrderBuilderWithDefaults()
    .accountByName('Bob Jones')
    .salesChannelByName('In Store')
    .addProduct(OrderBuilder.productBySku('M12345', 2).price(30)) // overrides unit price to 30
    .addProduct(OrderBuilder.productBySku('M54321', 1).price(20)) 
    .deliveryMethodByName('DHL')
    .shippingAndBillingAddress(getTestAddress())
    .paymentGatewayByName('Adyen')
    .addPaymentInfo(OrderBuilder.paymentBuilder()
        .authorizedCreditCard().paymentAmount(50) // explicitly set the payment amount
        .gatewayReferenceNumber('PSP12345')
        .withExtraField('GatewayResultCode', '[accepted]'))
    .addPaymentInfo(OrderBuilder.paymentBuilder()
        .authorizedCreditCard().paymentAmount(25)
        .gatewayReferenceNumber('PSP54321')
        .withExtraField('GatewayResultCode', '[accepted]'))
    .build();
```

# Installation

For now it's just Apex. After a few iterations it was decided to contain it all in a single class. While I would have preferred a multi class design to better split things up, for deployment purposes it's much easier to just have a single class.

You can deploy it to any Org using this command (or however you like to deploy Apex):
```shell
sfdx project deploy start -o <your_authorized_org_alias> -m "ApexClass:OrderBuilder"
```

Now you can create all the orders you like. 

# Other Tools

Be sure to check out the anonymous Apex [examples](scripts) in this repository.

I have also included an OMS Connect Helper. This is just a collection of static methods that can be used to create order summaries, fulfillment orders and other Order Management objects. These are all things you can do directly via Connect API although if you've worked a lot with Connect API, it can be really verbose. The helper is there to make it less verbose and ultimately make the developer's life easier.

# Contributions and Feedback

Contributions are more than welcome, also I am very interested in user feedback. I want the API to be as easy and intuitive to use as possible. So something doesn't make sense we can change it for the better. 
