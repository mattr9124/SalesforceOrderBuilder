/**
 * Created by mrossner on 26/08/2023.
 */

@IsTest
public class TestDataFactory {
    public final static Id NO_ID = '000000000000000000';
    public final static Id FAKE_ORDER_ID = '8011q000006HFluAAG';
    public final static Id FAKE_ORDER_DELIVERY_GROUP_ID = '2Dg1q000000Ccv9CAC';

    public static void createBasicTestData() {
        Account account = new Account(
                Name = 'Bob Jones',
                BillingStreet = 'TestBilling',
                BillingCity = 'TestBilling',
                BillingPostalCode = '12345',
                BillingState = 'NY',
                BillingCountry = 'US',
                ShippingStreet = 'TestShipping',
                ShippingCity = 'TestShipping',
                ShippingPostalCode = '12345',
                ShippingState = 'NY',
                ShippingCountry = 'US'

        );

        SalesChannel salesChannel = new SalesChannel(SalesChannelName = 'In Store');
        Product2 product2 = new Product2(
                Name = 'Test product1',
                StockKeepingUnit = 'M12345',
                ProductCode = 'M12345'
        );

        Product2 deliveryProduct = new Product2(
                Name = 'DHL',
                StockKeepingUnit = 'DHL',
                ProductCode = 'DHL'
        );
        insert new SObject[]{
                account, salesChannel, product2, deliveryProduct
        };

        PricebookEntry pricebookEntry = new PricebookEntry(
                Product2Id = product2.Id,
                Pricebook2Id = Test.getStandardPricebookId(),
                UnitPrice = 99
        );

        PricebookEntry deliveryPricebookEntry = new PricebookEntry(
                Product2Id = deliveryProduct.Id,
                Pricebook2Id = Test.getStandardPricebookId(),
                UnitPrice = 4.99
        );

        OrderDeliveryMethod orderDeliveryMethod = new OrderDeliveryMethod(
                Name = 'DHL',
                ProductId = deliveryProduct.Id
        );

        insert new SObject[]{
                pricebookEntry, deliveryPricebookEntry, orderDeliveryMethod
        };
    }
}