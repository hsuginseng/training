public with sharing class RoutingActionInput {
    public RoutingActionInput() {

    }

    @AuraEnabled
    @InvocableVariable(label='Get Inventory Availability Output Representation' description='Get Inventory Availability Output Representation' required=true)
    public List<ConnectApi.OCIGetInventoryAvailabilityOutputRepresentation> inventoryAvailabilityList;

    @AuraEnabled
    @InvocableVariable(label='Rank Available Locations to Fulfill' description='Rank Available Locations to Fulfill' required=true)
    public List<String> rankAvailableLocationsToFulfill;

    @AuraEnabled
    @InvocableVariable(label='Location Group Ids' description='Location Group Ids' required=true)
    public List<ID> locationGroupIds;

    @AuraEnabled
    @InvocableVariable(label='Order Delivery Group Summary Id' description='Order Delivery Group Summary Id' required=true)
    public ID orderDeliveryGroupSummaryId;

    @AuraEnabled
    @InvocableVariable(label='Order Summary Id' description='Order Summary Id' required=true)
    public ID orderSummaryId;

    @AuraEnabled
    @InvocableVariable(label='Order Item Summaries' description='Order Item Summaries' required=true)
    public List<OrderItemSummary> orderItemSummaries;


}