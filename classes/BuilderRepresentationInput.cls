public with sharing  class BuilderRepresentationInput {
    public BuilderRepresentationInput() {

    }
    
    @AuraEnabled
    @InvocableVariable(label='Get Inventory Availability Output Representation' description='Get Inventory Availability Output Representation' required=true)
    public List<ConnectApi.OCIGetInventoryAvailabilityOutputRepresentation> inventoryAvailabilityList;

    @AuraEnabled
    @InvocableVariable(label='Order Item Summaries' description='Order Item Summaries' required=true)
    public List<OrderItemSummary> orderItemSummaries;

    @AuraEnabled
    @InvocableVariable(label='Maximum Number Of Splits' description='Maximum Number Of Splits' required=true)
    public Integer maximumSplits;


}