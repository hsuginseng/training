trigger UpdateOCIIntereactionOrderSummary on OCIInteractionOrderSummary__c (after update) {

    if (trigger.isUpdate){

        List<OCIInteractionOrderSummary__c> updatedParents = 
        [SELECT Id, Status__c, Type__c , FulfillmentOrder__c,(SELECT Id FROM OCIInteractionOrderItemSummaries__r) FROM OCIInteractionOrderSummary__c WHERE Id IN :Trigger.new];

        List<OCIInteractionOrderItemSummary__c> childToUpdates = new List<OCIInteractionOrderItemSummary__c>();

        for (OCIInteractionOrderSummary__c parent : updatedParents) {
            
            for (OCIInteractionOrderItemSummary__c child : parent.OCIInteractionOrderItemSummaries__r) {
                OCIInteractionOrderItemSummary__c childToUpdate = new OCIInteractionOrderItemSummary__c();
                childToUpdate.Id = child.Id;
                childToUpdate.Status__c = parent.Status__c;
                childToUpdate.Type__c = parent.Type__c;
                childToUpdate.FulfillmentOrder__c = parent.FulfillmentOrder__c;
                childToUpdates.add(childToUpdate);
            }
        
        }
        update childToUpdates;

    }

  
}