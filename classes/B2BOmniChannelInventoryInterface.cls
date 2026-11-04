// This must implement the sfdc_checkout.CartInventoryValidation interface
// in order to be processed by the checkout flow and used for your Check Inventory integration.
global with sharing class B2BOmniChannelInventoryInterface implements sfdc_checkout.CartInventoryValidation {
    global sfdc_checkout.IntegrationStatus startCartProcessAsync(sfdc_checkout.IntegrationInfo jobInfo, ID cartId) {
        sfdc_checkout.IntegrationStatus integStatus = new sfdc_checkout.IntegrationStatus();
        try {
            // Get all SKUs and their quantities from cart items.
            Map<String, Decimal> quantitiesFromSalesforce = new Map<String, Decimal>();
            for (CartItem cartItem : [SELECT Sku, Quantity FROM CartItem WHERE CartId = :cartId AND Type = 'Product' WITH SECURITY_ENFORCED]) {
                if (String.isBlank(cartItem.Sku)) {
                    String errorMessage = 'The SKUs for all products in your cart must be defined.';
                    return integrationStatusFailedWithCartValidationOutputError(
                        integStatus,
                        errorMessage,
                        jobInfo,
                        cartId
                    );
                }
                quantitiesFromSalesforce.put(cartItem.Sku, cartItem.Quantity);
            }

            // Stop checkout if there are no items in the cart
            if (quantitiesFromSalesforce.isEmpty()) {
                String errorMessage = 'Looks like your cart is empty.';
                return integrationStatusFailedWithCartValidationOutputError(
                    integStatus,
                    errorMessage,
                    jobInfo,
                    cartId
                );
            }

            WebCart currentCart = [SELECT Location__c FROM WebCart WHERE Id =: cartId WITH SECURITY_ENFORCED]; 

            // Stop checkout if B2B Rep doesn't have valid location. (Location__c is set on cart in OOBO flow, based on B2B Rep's user record's Location__c formula field.)
            if (String.isBlank(currentCart.Location__c)) {
                String errorMessage = 'This B2B Representative Does Not Have Their Branch Location Set! Cart Is Missing Location__c Inventory Identifier!';
                return integrationStatusFailedWithCartValidationOutputError(
                    integStatus,
                    errorMessage,
                    jobInfo,
                    cartId
                );
            }
            
            // Get all available quantities for products in the cart (cart items) from an external service.
            Map<String, Decimal> quantitiesFromExternalService = getQuantitiesFromExternalService(quantitiesFromSalesforce.keySet(), currentCart.Location__c);            
            
            // For each cart item SKU, check that the quantity from the external service
            // is greater or equal to the quantity in the cart.
            // If that is not true, set the integration status to "Failed".
            for (String sku : quantitiesFromSalesforce.keySet()) {
                Decimal quantityFromSalesforce = quantitiesFromSalesforce.get(sku);
                Decimal quantityFromExternalService = quantitiesFromExternalService.get(sku);
                if (quantityFromExternalService == null){
                    String errorMessage = 'The product with sku ' + sku + ' could not be found in the external system';
                    return integrationStatusFailedWithCartValidationOutputError(
                       integStatus,
                       errorMessage,
                       jobInfo,
                       cartId
                   );
                } 
                else if (quantityFromExternalService < quantityFromSalesforce){
                   String errorMessage = 'Insufficient quantity for the product with sku ' + sku + ': ' 
                               + quantityFromSalesforce + ' needed, but only '
                               + quantityFromExternalService + ' available.';
                   return integrationStatusFailedWithCartValidationOutputError(
                       integStatus,
                       errorMessage,
                       jobInfo,
                       cartId
                   );
                }
                else {
                    // If the product exists and the available quantity is enough, set status as SUCCESS
                    integStatus.status = sfdc_checkout.IntegrationStatus.Status.SUCCESS;
                }
            }
        } catch(Exception e) {
            // For testing purposes, this example treats exceptions as user errors, which means they are displayed to the buyer user.
            // In production you probably want this to be an admin-type error. In that case, throw the exception here
            // and make sure that a notification system is in place to let the admin know that the error occurred.
            // See the readme section about error handling for details about how to create that notification.
            return integrationStatusFailedWithCartValidationOutputError(
                integStatus,
                'An exception of type ' + e.getTypeName() + ' has occurred: ' + e.getMessage(),
                jobInfo,
                cartId
            );
        }
        return integStatus;
    }
    
    private Map<String, Decimal> getQuantitiesFromExternalService (Set<String> skus, String inventorySource) {
        try {
            List<String> skuList = new List<String>();
            skuList.addAll(skus);
            Map<String, Decimal> quantitiesFromExternalService = InventoryController.getMultipleProductStockB2B(inventorySource, skuList);
        	return quantitiesFromExternalService;
        } catch(Exception e) {
            throw new CalloutException ('There was a problem with the inventory request for ' + skus.toString());
        }
    }  
    
    private sfdc_checkout.IntegrationStatus integrationStatusFailedWithCartValidationOutputError(
        sfdc_checkout.IntegrationStatus integrationStatus, String errorMessage, sfdc_checkout.IntegrationInfo jobInfo, Id cartId) {
            integrationStatus.status = sfdc_checkout.IntegrationStatus.Status.FAILED;
            // To propagate the error to the user, we need to add a new CartValidationOutput record.
            // The following fields must be populated:
            // BackgroundOperationId: Foreign Key to the BackgroundOperation
            // CartId: Foreign key to the WebCart that this validation line is for
            // Level (required): One of the following - Info, Error, or Warning
            // Message (optional): Message displyed to the user
            // Name (required): The name of this CartValidationOutput record. For example CartId:BackgroundOperationId
            // RelatedEntityId (required): Foreign key to WebCart, CartItem, CartDeliveryGroup
            // Type (required): One of the following - SystemError, Inventory, Taxes, Pricing, Shipping, Entitlement, Other
            CartValidationOutput cartValidationError = new CartValidationOutput(
                BackgroundOperationId = jobInfo.jobId,
                CartId = cartId,
                Level = 'Error',
                Message = errorMessage.left(255),
                Name = (String)cartId + ':' + jobInfo.jobId,
                RelatedEntityId = cartId,
                Type = 'Inventory'
            );
            insert(cartValidationError);
            return integrationStatus;
    }
}