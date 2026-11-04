public with sharing class RoutingAction {
    public RoutingAction() {

    }

    @InvocableMethod(label='Generate Interaction Order Summary Data' description='Generate Interaction Order Summary Data' category='Order Management')
    public static List<RoutingActionResult> generateRoutingData(List<RoutingActionInput> inputs){
       
        List<RoutingActionResult> results = new List<RoutingActionResult>();
        Set<ID> locationGroupSet = new Set<ID>();

        for (RoutingActionInput input : inputs) {
            locationGroupSet.addAll(input.locationGroupIds);
        }

        List<Schema.LocationGroupAssignment> locationGroupAssignments = [SELECT LocationId, LocationExternalReference  
        FROM LocationGroupAssignment 
        WHERE LocationGroupId  IN: locationGroupSet];

        Map<String,Schema.LocationGroupAssignment> mapLocation = new Map<String,Schema.LocationGroupAssignment>();
        for (Schema.LocationGroupAssignment locationGroupAssignment : locationGroupAssignments) {
            if (!mapLocation.containsKey(locationGroupAssignment.LocationExternalReference)) {
                mapLocation.put(locationGroupAssignment.LocationExternalReference,locationGroupAssignment);
            }
        }

        for (RoutingActionInput input : inputs) {
            
            RoutingActionResult result = new RoutingActionResult();
            RoutingActionOutput output = new RoutingActionOutput();
            
            Map<String,List<ConnectApi.OCILocationAvailabilityOutputRepresentation>> locationInvtMap = 
            new  Map<String,List<ConnectApi.OCILocationAvailabilityOutputRepresentation>>();
            
            for (ConnectApi.OCIGetInventoryAvailabilityOutputRepresentation inventory : input.inventoryAvailabilityList) {
                for (ConnectApi.OCILocationAvailabilityOutputRepresentation location : inventory.locations) {
                    if (input.rankAvailableLocationsToFulfill.contains(location.locationIdentifier)) {

                        if (locationInvtMap.containsKey(location.locationIdentifier)) {
                            locationInvtMap.get(location.locationIdentifier).add(location);
                        } else {
                            List<ConnectApi.OCILocationAvailabilityOutputRepresentation> listInv = 
                            new List<ConnectApi.OCILocationAvailabilityOutputRepresentation>();
                            listInv.add(location);
                            locationInvtMap.put(location.locationIdentifier,listInv);
                        }
                        
                    }
                }

            }

            Map<String,RoutingGroup> mapRoutingGroup = new  Map<String,RoutingGroup>();
            List<OrderItemSummary> deliveryChargeItems = new List<OrderItemSummary>();

            for (OrderItemSummary orderItemSummary : input.orderItemSummaries) {
                Double missingQuantityToFulfill = orderItemSummary.QuantityAvailableToFulfill;

                if (orderItemSummary.Type == 'Delivery Charge') {
                    deliveryChargeItems.add(orderItemSummary);
                } else {
                    for (String rankAvailableLocationToFulfill : input.rankAvailableLocationsToFulfill) {
                        List<ConnectApi.OCILocationAvailabilityOutputRepresentation> locations = locationInvtMap.get(rankAvailableLocationToFulfill);
                        ID currentLocationId = mapLocation.get(rankAvailableLocationToFulfill).LocationId;
                        for (ConnectApi.OCILocationAvailabilityOutputRepresentation location : locations) {

                            for (ConnectApi.OCIInventoryRecordOutputRepresentation inventoryRecord : location.inventoryRecords) {

                                if (inventoryRecord.stockKeepingUnit == orderItemSummary.StockKeepingUnit && 
                                    inventoryRecord.availableToFulfill > 0 && 
                                    missingQuantityToFulfill > 0.0) {
                                        
                                        RoutingItem routingItem = new RoutingItem();
                                        routingItem.reservedAtLocationId = orderItemSummary.ReservedAtLocationId;
                                        routingItem.orderItemSummaryId = orderItemSummary.Id;

                                        if (inventoryRecord.availableToFulfill >= missingQuantityToFulfill ) {
                                            routingItem.quantity = missingQuantityToFulfill;
                                            missingQuantityToFulfill = 0.0;
                                        } else {
                                            routingItem.quantity = inventoryRecord.availableToFulfill;
                                            missingQuantityToFulfill = missingQuantityToFulfill - inventoryRecord.availableToFulfill;
                                        }
                                        
                                        if (mapRoutingGroup.containsKey(currentLocationId)) {
                                            RoutingGroup rg = mapRoutingGroup.get(currentLocationId);
                                            rg.routingItems.add(routingItem);
                                        } else {
                                            RoutingGroup rg = new RoutingGroup();
                                            rg.routingItems = new List<RoutingItem>();
                                            rg.fulfillFromLocationId = currentLocationId;
                                            rg.routingItems.add(routingItem);
                                            mapRoutingGroup.put(currentLocationId,rg);
                                        }
                                }
                            }
                        }
                    }
                }
            }

            if (deliveryChargeItems.size() > 0 ) {
                for (OrderItemSummary deliveryChargeItem : deliveryChargeItems) {
                    RoutingItem routingItem = new RoutingItem();
                    routingItem.orderItemSummaryId = deliveryChargeItem.Id;
                    routingItem.quantity = deliveryChargeItem.QuantityAvailableToFulfill;
                    mapRoutingGroup.values().get(0).routingItems.add(routingItem);
                }
            }

            output.orderDeliveryGroupSummaryId = input.orderDeliveryGroupSummaryId;
            output.orderSummaryId = input.orderSummaryId;
            output.routingGroupList = mapRoutingGroup.values();
            result.output = output;

            results.add(result);
            
        }

        return results;

    }
}