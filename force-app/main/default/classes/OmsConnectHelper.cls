public with sharing class OmsConnectHelper {

    /**
     * Helper method that will create an order summary from and order
     * @param orderId
     *
     * @return
     */
    public static ConnectApi.OrderSummaryOutputRepresentation createOrderSummary(Id orderId) {
        ConnectApi.OrderSummaryInputRepresentation orderSummaryInput = new ConnectApi.OrderSummaryInputRepresentation();
        orderSummaryInput.orderId = orderId;
        orderSummaryInput.orderLifeCycleType = 'MANAGED';
        return ConnectApi.OrderSummaryCreation.createOrderSummary(orderSummaryInput);
    }


    /**
     * Creates one or many fulfillment orders depending on the second parameter.
     * It assumes a single delivery group and will use the same location
     * and fulfillment type for both.
     * @param orderSummaryId
     * @param fulfillmentSplits
     * @param location
     * @param fulfillmentType
     *
     * @return
     */
    public static ConnectApi.FulfillmentOrderOutputRepresentation createMultipleFulfillmentOrder(Id orderSummaryId, List<List<OrderItemSummary>> fulfillmentSplits,
            String location, String fulfillmentType) {

        String warehouseFromLocationId = [
                SELECT Id
                FROM Location
                WHERE Name = :location
                LIMIT 1
        ].Id;

        ConnectApi.FulfillmentOrderInputRepresentation fulfillmentOrderInput = new ConnectApi.FulfillmentOrderInputRepresentation();
        fulfillmentOrderInput.orderSummaryId = orderSummaryId;

        List<OrderDeliveryGroupSummary> orderDeliveryGroupSummaryList = [
                SELECT Id
                FROM OrderDeliveryGroupSummary
                WHERE OrderSummaryId = :orderSummaryId
                LIMIT 1
        ];

        fulfillmentOrderInput.orderDeliveryGroupSummaryId = orderDeliveryGroupSummaryList[0].Id;

        List<ConnectApi.FulfillmentGroupInputRepresentation> fulfillmentGroups = new List<ConnectApi.FulfillmentGroupInputRepresentation>();


        for (List<OrderItemSummary> subItemSummaries : fulfillmentSplits) {
            ConnectApi.FulfillmentGroupInputRepresentation fulfillmentGroup = new ConnectApi.FulfillmentGroupInputRepresentation();
            fulfillmentGroup.fulfilledFromLocationId = warehouseFromLocationId;
            fulfillmentGroup.fulfillmentType = fulfillmentType;

            List<ConnectApi.OrderItemSummaryInputRepresentation> orderItemSummaries = new List<ConnectApi.OrderItemSummaryInputRepresentation>();

            for (OrderItemSummary orderItemSummary : subItemSummaries) {
                ConnectApi.OrderItemSummaryInputRepresentation oisInputRepresentation = new ConnectApi.OrderItemSummaryInputRepresentation();
                oisInputRepresentation.orderItemSummaryId = orderItemSummary.Id;
                oisInputRepresentation.quantity = orderItemSummary.quantity;
                orderItemSummaries.add(oisInputRepresentation);
            }

            fulfillmentGroup.orderItemSummaries = orderItemSummaries;
            fulfillmentGroups.add(fulfillmentGroup);
            fulfillmentOrderInput.fulfillmentGroups = fulfillmentGroups;
        }

        return ConnectApi.FulfillmentOrder.createFulfillmentOrders(fulfillmentOrderInput);
    }

    /**
     * Creates a single fulfillment order with all items in the order.
     * @param orderSummaryId
     * @param location
     * @param fulfillmentType
     *
     * @return
     */
    public static ConnectApi.FulfillmentOrderOutputRepresentation createFulfillmentOrder(Id orderSummaryId, String location, String fulfillmentType) {
        return createMultipleFulfillmentOrder(orderSummaryId, new List<List<OrderItemSummary>>{ [
                SELECT Id, Quantity
                FROM OrderItemSummary
                WHERE OrderSummaryId = :orderSummaryId
                AND TypeCode = 'Product'
        ]
        }, location, fulfillmentType);
    }

    /**
     * This is really just to write less code. It will call the connect API with the correct input
     * objects.
     * @param orderSummaryId
     * @param invoiceId
     *
     * @return
     */
    public static ConnectApi.EnsureFundsAsyncOutputRepresentation ensureFunds(Id orderSummaryId, Id invoiceId) {
        ConnectApi.EnsureFundsAsyncInputRepresentation ensureFundsAsyncInputRepresentation = new ConnectApi.EnsureFundsAsyncInputRepresentation();

        ensureFundsAsyncInputRepresentation.invoiceId = invoiceId;

        return ConnectApi.OrderSummary.ensureFundsAsync(orderSummaryId, ensureFundsAsyncInputRepresentation);
    }
}