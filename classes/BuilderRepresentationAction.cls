public with sharing  class BuilderRepresentationAction {
   
    public BuilderRepresentationAction() {

    }

    @InvocableMethod(label='Generate Find Routes With Fewest Splits Input Representation' description='Generate Find Routes With Fewest Splits Input Representation' category='Order Management')
    public static List<BuilderRepresentationResult> generateFindRoutesWithFewestSplitsInput(List<BuilderRepresentationInput> inputs){

        List<BuilderRepresentationResult> results = new List<BuilderRepresentationResult>();
        
        for ( BuilderRepresentationInput input : inputs) {

            BuilderRepresentationResult result = new BuilderRepresentationResult();
            BuilderRepresentationOutput output = new BuilderRepresentationOutput();

            ConnectApi.FindRoutesWithFewestSplitsInputRepresentation frwfsInput = new ConnectApi.FindRoutesWithFewestSplitsInputRepresentation();
            frwfsInput.locationAvailableInventory = new List<ConnectApi.LocationAvailabilityInputRepresentation>();
            frwfsInput.orderedQuantities = new List<ConnectApi.QuantityWithSkuInputRepresentation>();
            frwfsInput.maximumNumberOfSplits = input.maximumSplits;
            

            for (ConnectApi.OCIGetInventoryAvailabilityOutputRepresentation inventory : input.inventoryAvailabilityList) {

                for (ConnectApi.OCILocationAvailabilityOutputRepresentation location : inventory.locations) {

                    for (ConnectApi.OCIInventoryRecordOutputRepresentation inventoryRecord : location.inventoryRecords) {
                        ConnectApi.LocationAvailabilityInputRepresentation locationAvailabilityInputRepresentation = new ConnectApi.LocationAvailabilityInputRepresentation();
                        locationAvailabilityInputRepresentation.externalReferenceId = location.locationIdentifier;
                        locationAvailabilityInputRepresentation.stockKeepingUnit = inventoryRecord.stockKeepingUnit;
                        locationAvailabilityInputRepresentation.quantity = inventoryRecord.availableToFulfill;
                        frwfsInput.locationAvailableInventory.add(locationAvailabilityInputRepresentation);
                    }

                }
            }

            for (OrderItemSummary orderItemSummary : input.orderItemSummaries) {
                if (orderItemSummary.Type != 'Delivery Charge') {
                    ConnectApi.QuantityWithSkuInputRepresentation qwsInputRep = new ConnectApi.QuantityWithSkuInputRepresentation();
                    qwsInputRep.quantity = orderItemSummary.QuantityAvailableToFulfill;
                    qwsInputRep.stockKeepingUnit = orderItemSummary.StockKeepingUnit;
                    frwfsInput.orderedQuantities.add(qwsInputRep);
                }       
            }

            output.findRoutesWithFewestSplitsInput = frwfsInput;
            result.builderOutput = output;

            results.add(result);
            
        }

        return results;
    }


}