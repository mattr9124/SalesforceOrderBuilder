# Project Overview

This project is meant for Salesforce developers who are working on Salesforce Order Management projects. The goal is to easily create orders in a specific state using a fluent style API. 

This can be useful for:
* Developing new features
* Debugging issues
* Creating unit tests

and hopefully more...

# Usage

Examples that can be run as anonymous Apex with existing data in the Org.

Simple order with a product and no payments:
```apex
Order order = OrderBuilder.newOrderBuilder()
        .accountByName('Bob Jones')
        .useAccountAddress()
        .salesChannelByName('In Store')
        .todayDates()
        .addProduct(OrderBuilder.productBySku('M12345', 2))
        .deliveryMethodByName('DHL')
        .useStandardPricebook()
        .build();
```

An order with already captured payment:
```apex
OrderBuilder.newOrderBuilderWithDefaults()
    .accountByName('Bob Jones')
    .salesChannelByName('In Store')
    .addProduct(OrderBuilder.productBySku('M12345', 2))
    .deliveryMethodByName('DHL')
    .paymentGateway(new PaymentGateway())
    .addPaymentInfo(OrderBuilder.paymentBuilder()
        .capturedCreditCard()
        .gatewayReferenceNumber('PSP12345')
        .withExtraField('GatewayResultCode', '[accepted]'))
    .build();
```

Order with multiple payment authorizations (payment with 2 cards for $50 and $25):
```apex
OrderBuilder.newOrderBuilderWithDefaults()
    .accountByName('Bob Jones')
    .salesChannelByName('In Store')
    .addProduct(OrderBuilder.productBySku('M12345', 2))
    .deliveryMethodByName('DHL')
    .shippingAndBillingAddress(getTestAddress())
    .paymentGateway(new PaymentGateway())
    .addPaymentInfo(OrderBuilder.paymentBuilder()
        .authorizedCreditCard().paymentAmount(50)
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

# Video Demo

Coming soon - I'm working on a little YouTube demo so check back for that soon.
