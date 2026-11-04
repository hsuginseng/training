public with sharing  class RoutingActionOutput {
    public RoutingActionOutput() {

    }

    @InvocableVariable(label='orderSummaryId' description='orderSummaryId' required=true)
    @AuraEnabled
    public ID orderSummaryId;

    @InvocableVariable(label='orderDeliveryGroupSummaryId' description='orderDeliveryGroupSummaryId' required=true)
    @AuraEnabled
    public ID orderDeliveryGroupSummaryId;

    @InvocableVariable(label='Routing Group' description='Routing Group' required=true)
    @AuraEnabled
    public List<RoutingGroup> routingGroupList;
    
}