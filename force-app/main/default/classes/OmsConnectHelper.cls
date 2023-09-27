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
        ]
        }, location, fulfillmentType);
    }

    /**
     * Cancels the whole fulfillment order
     * @param fulfillmentOrderId
     *
     * @return
     */
    public static ConnectApi.FulfillmentOrderCancelLineItemsOutputRepresentation cancelFulfillmentItem(Id fulfillmentOrderId) {
        return cancelFulfillmentItem(fulfillmentOrderId, 0, 0);
    }

    /**
     * Cancel a fulfillment order.
     *
     * @param fulfillmentOrderId The FO Id
     * @param lines How many lines to cancel - null or 0 will cancel the whole FO, otherwise it will go in the order it finds, so passing 1 will cancel the first line, 2 will cancel the first 2, etc...
     * @param quantity - Quantity to cancel - null or 0 will cancel all, otherwise same logic as lines parameter
     *
     * @return
     */
    public static ConnectApi.FulfillmentOrderCancelLineItemsOutputRepresentation cancelFulfillmentItem(Id fulfillmentOrderId, Integer lines, Integer quantity) {
        // will cancel quantity 1 and first line

        ConnectApi.FulfillmentOrderLineItemsToCancelInputRepresentation cancelInput = new ConnectApi.FulfillmentOrderLineItemsToCancelInputRepresentation();

        FulfillmentOrderLineItem[] fulfillmentItems = [
                SELECT Id, Quantity
                FROM FulfillmentOrderLineItem
                WHERE FulfillmentOrderId = :fulfillmentOrderId
        ];

        cancelInput.fulfillmentOrderLineItemsToCancel = new List<ConnectApi.FulfillmentOrderLineItemInputRepresentation>();

        Integer foLineSize = lines == null || lines <= 0 || lines > fulfillmentItems.size() ? fulfillmentItems.size() : lines;

        for (Integer foIndex = 0; foIndex < foLineSize; foIndex++) {
            FulfillmentOrderLineItem fulfillmentOrderLineItem = fulfillmentItems[foIndex];
            ConnectApi.FulfillmentOrderLineItemInputRepresentation inputLine = new ConnectApi.FulfillmentOrderLineItemInputRepresentation();

            inputLine.fulfillmentOrderLineItemId = fulfillmentOrderLineItem.Id;
            inputLine.quantity = quantity == null || quantity <= 0 ? fulfillmentOrderLineItem.Quantity : quantity;

            cancelInput.fulfillmentOrderLineItemsToCancel.add(inputLine);
        }

        return ConnectApi.FulfillmentOrder.cancelFulfillmentOrderLineItems(fulfillmentOrderId, cancelInput);
    }


    /**
     * Cancel or return items this will return/cancel the whole order
     * Future versions might allow passing in specific order items
     *
     * @param orderSummaryId
     * @param cancel True for cancel, False for return
     * @param shippingFlag Sets the shipping reduction flag on the change order
     * @param reason Must be valid reason, check the picklist configuration in your Org on the OrderItemSummaryChange.Reason field
     * @param preview Preview or commit changes
     *
     * @return
     */
    public static ConnectApi.BaseOutputRepresentation createChangeOrder(Id orderSummaryId, Boolean cancel, Boolean shippingFlag, String reason, Boolean preview) {
        ConnectApi.ChangeInputRepresentation changeInputRepresentation = new ConnectApi.ChangeInputRepresentation();
        changeInputRepresentation.changeItems = new ConnectApi.ChangeItemInputRepresentation []{};
        for (OrderItemSummary orderItemSummary : [SELECT Quantity FROM OrderItemSummary WHERE OrderSummaryId = :orderSummaryId AND TypeCode = 'Product']) {
            ConnectApi.ChangeItemInputRepresentation changeItemInputRepresentation = new ConnectApi.ChangeItemInputRepresentation();

            changeItemInputRepresentation.quantity = orderItemSummary.Quantity;
            changeItemInputRepresentation.orderItemSummaryId = orderItemSummary.Id;
            changeItemInputRepresentation.reason = reason;
            changeItemInputRepresentation.shippingReductionFlag = shippingFlag;

            changeInputRepresentation.changeItems.add(changeItemInputRepresentation);
        }

        if (cancel) {
            return handleCancel(orderSummaryId, changeInputRepresentation, preview);
        }
        return handleReturn(orderSummaryId, changeInputRepresentation, preview);
    }

    private static ConnectApi.BaseOutputRepresentation handleCancel(Id orderSummaryId, ConnectApi.ChangeInputRepresentation changeInputRepresentation, Boolean preview) {
        if (preview) {
            return ConnectApi.OrderSummary.previewCancel(orderSummaryId, changeInputRepresentation);
        }
        return ConnectApi.OrderSummary.submitCancel(orderSummaryId, changeInputRepresentation);
    }

    private static ConnectApi.BaseOutputRepresentation handleReturn(Id orderSummaryId, ConnectApi.ChangeInputRepresentation changeInputRepresentation, Boolean preview) {
        if (preview) {
            return ConnectApi.OrderSummary.previewReturn(orderSummaryId, changeInputRepresentation);
        }
        return ConnectApi.OrderSummary.submitReturn(orderSummaryId, changeInputRepresentation);
    }

    /**
     * Wrapper method that will call connect API with less code.
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

    /**
     * Wrapper method that will call connect API with less code.
     * @param orderSummaryId
     * @param refundAmount
     *
     * @return
     */
    public static ConnectApi.EnsureRefundsAsyncOutputRepresentation ensureRefundByExcessFunds(Id orderSummaryId, Decimal refundAmount) {
        ConnectApi.EnsureRefundsAsyncInputRepresentation inputRepresentation = new ConnectApi.EnsureRefundsAsyncInputRepresentation();
        inputRepresentation.excessFundsAmount = refundAmount;
        return ConnectApi.OrderSummary.ensureRefundsAsync(orderSummaryId, inputRepresentation);
    }

    /**
     * Wrapper method that will call connect API with less code.
     * @param orderSummaryId
     * @param creditMemoId
     *
     * @return
     */
    public static ConnectApi.EnsureRefundsAsyncOutputRepresentation ensureRefundByCreditMemo(Id orderSummaryId, Id creditMemoId) {
        ConnectApi.EnsureRefundsAsyncInputRepresentation inputRepresentation = new ConnectApi.EnsureRefundsAsyncInputRepresentation();
        inputRepresentation.creditMemoId = creditMemoId;
        return ConnectApi.OrderSummary.ensureRefundsAsync(orderSummaryId, inputRepresentation);
    }
}