public with sharing  class RoutingActionResult {
    public RoutingActionResult() {

    }

    @InvocableVariable(label='Routing Action Output' description='Routing Action Output' required=true)
    @AuraEnabled
    public RoutingActionOutput output;
}