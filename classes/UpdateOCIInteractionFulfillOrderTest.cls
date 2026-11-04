@isTest
private class UpdateOCIInteractionFulfillOrderTest {
    @isTest static void test_UpdateOCIInteractionFulfillOrderTrigger() {
        
        // Create Records
        FulfillmentOrder fo = seedFulfillOrder();
        FulfillmentOrderLineItem foli = seedFulfillOrderLineItem(fo);
        OCIInteractionFulfillOrder__c ociFulfill = seedOCIFullfillOrder(fo);
        OCIInteractionFulfillOrderItem__c ociFulfillItem = seedOCIFullfillOrderItem(ociFulfill, foli);

        Test.startTest();
        ociFulfill.Status__c = 'ABANDONED';
        ociFulfill.Type__c = 'TRANSFER_CANCEL';
        update ociFulfill;

        Test.stopTest();

        OCIInteractionFulfillOrderItem__c audit = [SELECT Id, Status__c, Type__c FROM OCIInteractionFulfillOrderItem__c WHERE OCIInteractionFulfillOrder__c = : ociFulfill.Id LIMIT 1];
        System.assertEquals(ociFulfillItem.Id, audit.Id);
        System.assertEquals('ABANDONED', audit.Status__c);
        System.assertEquals('TRANSFER_CANCEL', audit.Type__c);       
    }


    // Create Fulfillment Order
    private static FulfillmentOrder seedFulfillOrder(){
        OrderDeliveryMethod odm = new OrderDeliveryMethod(
                                        IsActive = false,
                                        Name = 'test'
                                    );
        insert odm;
        FulfillmentOrder fo = new FulfillmentOrder(
                                    status = 'Draft',
                                    FulfilledToName = 'test',
                                    DeliveryMethodId = odm.Id
                                );
        insert fo;
        return fo;
    }

    // Create Fulfillment Order Line Item
    private static FulfillmentOrderLineItem seedFulfillOrderLineItem(FulfillmentOrder fo){
        FulfillmentOrderLineItem foli = new FulfillmentOrderLineItem(
                                            FulfillmentOrderId = fo.Id,
                                            Quantity = 1.0,
                                            OriginalQuantity = 1.0,
                                            Type = 'Order Product',
                                            TypeCode = 'Product'
                                        );
        insert foli;
        return foli;
    }

    // Create OCI Interaction Fulfillment Order
    private static OCIInteractionFulfillOrder__c seedOCIFullfillOrder(FulfillmentOrder fo){
        OCIInteractionFulfillOrder__c ociFulfill = new OCIInteractionFulfillOrder__c(
                                                        FulfillmentOrder__c = fo.Id,
                                                        Status__c = 'REQUESTED',
                                                        Type__c = 'TRANSFER_MOVE',
                                                        ConnectionFailedAttempts__c = 0,
                                                        Schedule__c = DateTime.now()
                                                    );
        insert ociFulfill;
        return ociFulfill;    
    }
    
    // Create OCI Interaction Fulfillment Order Item
    private static OCIInteractionFulfillOrderItem__c seedOCIFullfillOrderItem(OCIInteractionFulfillOrder__c ociFulfill, FulfillmentOrderLineItem foli){
        OCIInteractionFulfillOrderItem__c ociFulfillItem = new OCIInteractionFulfillOrderItem__c(
                                                                OCIInteractionFulfillOrder__c = ociFulfill.Id,
                                                                FulfillmentOrderItem__c = foli.Id,
                                                                Quantity__c = 1,
                                                                Status__c = 'REQUESTED',
                                                                Type__c = 'TRANSFER_MOVE'
                                                            );
        insert ociFulfillItem;
        return ociFulfillItem;
    }
    
}