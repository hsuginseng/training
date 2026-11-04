global with sharing class InventoryController {

    @AuraEnabled(cacheable=false)
    public static String getCurrentWebstoreId() {
        Map<String, String> ctx = WebStoreContext.getCommerceContext();
        System.debug('ctx: ' + ctx);
        if (ctx == null) return null;
        return ctx.get('storeId');
    }

    @AuraEnabled(cacheable=false)
    public static Map<String, Decimal> getSingleProductStock(String webstoreId, String productId) {
        return getMultipleProductStock(webstoreId, new List<String>{ productId });
    }

    @AuraEnabled(cacheable=false)
    public static Map<String, Decimal> getMultipleProductStock(String webstoreId, List<String> productSkus) {
        try {
            WebStoreInventorySource storeInventorySource = [SELECT LocationSourceExtRef FROM WebStoreInventorySource WHERE WebStoreId =:webstoreId];
            ConnectApi.OCIGetInventoryAvailabilityInputRepresentation input = new ConnectApi.OCIGetInventoryAvailabilityInputRepresentation();
            input.stockKeepingUnits = productSkus;
            input.locationIdentifiers = new List<String>{ storeInventorySource.LocationSourceExtRef };
            input.useCache=false;

            ConnectApi.OCIGetInventoryAvailabilityOutputRepresentation output = ConnectApi.OmnichannelInventoryService.getInventoryAvailability(input);
            
            System.debug(output);
            System.debug(JSON.serialize(output));
            System.debug(output.locations[0]);
            System.debug(JSON.serialize(output.locations[0]));
            System.debug(output.locations[0].inventoryRecords);
            System.debug(JSON.serialize(output.locations[0].inventoryRecords));
            // We wrap it in a Map to avoid "Illegal Conversion" errors in some API versions
            // Map<String, Object> response = new Map<String, Object>();
            // response.put('products', output.locations);
            // return response;
            Map<String, Decimal> response = new Map<String, Decimal>();
            for(ConnectApi.OCIInventoryRecordOutputRepresentation productInventoryLevel : output.locations[0].inventoryRecords) {
                response.put(productInventoryLevel.stockKeepingUnit, (Decimal)productInventoryLevel.availableToOrder);
            }
            System.debug(JSON.serialize(response));
            return response;
            
        } catch (Exception e) {
            // If the type still fails to compile, the feature isn't enabled in the org
            throw new AuraHandledException('OCI not enabled or API version too low: ' + e.getMessage());
        }
    }

    @AuraEnabled(cacheable=false)
    public static Map<String, Decimal> getMultipleProductStockB2B(String inventorySource, List<String> productSkus) {
        try {
            ConnectApi.OCIGetInventoryAvailabilityInputRepresentation input = new ConnectApi.OCIGetInventoryAvailabilityInputRepresentation();
            input.stockKeepingUnits = productSkus;
            input.locationIdentifiers = new List<String>{ inventorySource };
            input.useCache=false;

            ConnectApi.OCIGetInventoryAvailabilityOutputRepresentation output = ConnectApi.OmnichannelInventoryService.getInventoryAvailability(input);
            
            System.debug(output);
            System.debug(JSON.serialize(output));
            System.debug(output.locations[0]);
            System.debug(JSON.serialize(output.locations[0]));
            System.debug(output.locations[0].inventoryRecords);
            System.debug(JSON.serialize(output.locations[0].inventoryRecords));
            // We wrap it in a Map to avoid "Illegal Conversion" errors in some API versions
            Map<String, Decimal> response = new Map<String, Decimal>();
            for(ConnectApi.OCIInventoryRecordOutputRepresentation productInventoryLevel : output.locations[0].inventoryRecords) {
                response.put(productInventoryLevel.stockKeepingUnit, (Decimal)productInventoryLevel.availableToOrder);
            }
            System.debug(JSON.serialize(response));
            return response;
            
        } catch (Exception e) {
            // If the type still fails to compile, the feature isn't enabled in the org
            throw new AuraHandledException('OCI not enabled or API version too low: ' + e.getMessage());
        }
    }
}