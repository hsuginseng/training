trigger UpdateOCIInteractionFulfillOrder on OCIInteractionFulfillOrder__c (after update) {

    if (trigger.isUpdate){


        List<OCIInteractionFulfillOrder__c> updatedParents = 
        [SELECT Id, Status__c, Type__c ,(SELECT Id FROM OCIInteractionFulfillOrderItems__r) FROM OCIInteractionFulfillOrder__c WHERE Id IN :Trigger.new];

        List<OCIInteractionFulfillOrderItem__c> childToUpdates = new List<OCIInteractionFulfillOrderItem__c>();

        for (OCIInteractionFulfillOrder__c parent : updatedParents) {
            
            for (OCIInteractionFulfillOrderItem__c child : parent.OCIInteractionFulfillOrderItems__r) {
                OCIInteractionFulfillOrderItem__c childToUpdate = new OCIInteractionFulfillOrderItem__c();
                childToUpdate.Id = child.Id;
                childToUpdate.Status__c = parent.Status__c;
                childToUpdate.Type__c = parent.Type__c;
                childToUpdates.add(childToUpdate);
            }
        
        }
        update childToUpdates;

    }
}