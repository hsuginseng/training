public  with sharing  class RoutingGroup {
    public RoutingGroup() {

    }

    @InvocableVariable(label='fulfillFromLocationId' description='fulfillFromLocationId' required=true)
    @AuraEnabled
    public ID fulfillFromLocationId;

    @InvocableVariable(label='routingItems' description='routingItems' required=true)
    @AuraEnabled
    public List<RoutingItem> routingItems;

    
}