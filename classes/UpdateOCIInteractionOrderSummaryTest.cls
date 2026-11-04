@isTest(SeeAllData=true)
private class UpdateOCIInteractionOrderSummaryTest {
    @isTest static void test_UpdateOCIInteractionOrderSummaryTrigger() {
        
        // Create Records
        FulfillmentOrder fo = seedFulfillOrder();
        FulfillmentOrderLineItem foli = seedFulfillOrderLineItem(fo);        
        TestDataGenerator.seedLocationData();
        String orderSummaryId = seedOrderSummary();
                        
        //Start Test
        Test.startTest();
        String odgsId = TestDataGenerator.getOrderSummaryDeliveryGroup(orderSummaryId);        
        String oisId = TestDataGenerator.getOrderSummaryItems(orderSummaryId);
        OCIInteractionOrderSummary__c ociOrderSummary = seedOCIOrderSummary(fo, orderSummaryId, odgsId);
        OCIInteractionOrderItemSummary__c ociOrderItemSummary = seedOCIOrderItemSummary(ociOrderSummary, fo, oisId);

        ociOrderSummary.Status__c = 'ABANDONED';
        ociOrderSummary.Type__c = 'TRANSFER_MOVING';
        update ociOrderSummary;

        Test.stopTest();

        //Assert
        OCIInteractionOrderItemSummary__c audit = [SELECT Id, Status__c, Type__c FROM OCIInteractionOrderItemSummary__c WHERE OCIInteractionOrderSummary__c = : ociOrderSummary.Id LIMIT 1];
        System.assertEquals(ociOrderItemSummary.Id, audit.Id);
        System.assertEquals('ABANDONED', audit.Status__c);
        System.assertEquals('TRANSFER_MOVING', audit.Type__c);
    }

	private static String seedOrderSummary(){
        // Creating Availability Data       
        List<ConnectApi.OCIInventoryRecordOutputRepresentation> inventoryRecords = new List<ConnectApi.OCIInventoryRecordOutputRepresentation>();
        ConnectApi.OCIInventoryRecordOutputRepresentation record1 = new ConnectApi.OCIInventoryRecordOutputRepresentation();
        record1.stockKeepingUnit = 'sku1';
        record1.availableToFulfill = 10;
        record1.availableToOrder = 10;

        ConnectApi.OCIInventoryRecordOutputRepresentation record2 = new ConnectApi.OCIInventoryRecordOutputRepresentation();
        record2.stockKeepingUnit = 'sku2';
        record2.availableToFulfill = 10;
        record2.availableToOrder = 5;
        inventoryRecords.add(record1);
        inventoryRecords.add(record2);
        
        ConnectApi.OCILocationAvailabilityOutputRepresentation locationAvailability = new ConnectApi.OCILocationAvailabilityOutputRepresentation();
        locationAvailability.locationIdentifier = 'Loc-1';
        locationAvailability.inventoryRecords = inventoryRecords;
        
        List<ConnectApi.OCILocationAvailabilityOutputRepresentation> locations = new List<ConnectApi.OCILocationAvailabilityOutputRepresentation>();
        locations.add(locationAvailability);
        
    	ConnectApi.OCIGetInventoryAvailabilityOutputRepresentation availability1 = new ConnectApi.OCIGetInventoryAvailabilityOutputRepresentation();
        availability1.locations = locations;
        
        List<ConnectApi.OCIGetInventoryAvailabilityOutputRepresentation> inventoryAvailabilityList = new List<ConnectApi.OCIGetInventoryAvailabilityOutputRepresentation>();
        inventoryAvailabilityList.add(availability1);

        // Create Product Data
        String timestamp = String.valueOf(DateTime.now());
        Product2 p1 = new Product2();
        p1.Name = 'P1';
        p1.StockKeepingUnit = 'sku1'+timestamp;
        insert p1;
        
        Product2 p2 = new Product2();
        p2.Name = 'P2';
        p2.StockKeepingUnit = 'sku2'+timestamp;
        insert p2;
        
        Product2 p3 = TestDataGenerator.createProduct2('Shipping', 'sku3'+timestamp);
        insert p3;
        
        PriceBookEntry pbe1 = TestDataGenerator.createPriceBookEntry(p1.Id, System.Test.getStandardPricebookId());
        insert pbe1;
        PriceBookEntry pbe2 = TestDataGenerator.createPriceBookEntry(p2.Id, System.Test.getStandardPricebookId());
        insert pbe2;
        PriceBookEntry pbe3 = TestDataGenerator.createPriceBookEntry(p3.Id, System.Test.getStandardPricebookId());
        insert pbe3;

        OrderDeliveryMethod odm  = TestDataGenerator.createOrderDeliveryMethod('001');
        insert odm;

        // Test Data for Order
        String firstName = 'Codey';
        String lastName = 'Bear';
        String fullName = firstName + lastName;
        String testEmail = 'test1@salesforce.com';
        String testPhone = '555-555-5777';
		
        Account acc = TestDataGenerator.getAccount(fullName);
        Contact contact = null;
        if (acc == null) {
           acc = TestDataGenerator.createAccount(fullName, testEmail);
           contact = TestDataGenerator.createContact(firstName, lastName, testPhone, acc.Id);
        } else {
            contact = TestDataGenerator.getContact(acc.Id);
        }
        
        Saleschannel sc = TestDataGenerator.createSaleschannel('RoutingTest');

        // Create Order, Order Summary, and retrieve Order Delivery Group Summary
        Order order = TestDataGenerator.createOrder(acc.Id, System.Test.getStandardPricebookId(), sc.Id, testEmail);
        insert order;
        
        OrderDeliveryGroup orderDeliveryGroup = TestDataGenerator.createOrderDeliveryGroup(order.Id, odm.Id, testEmail, fullName);
        insert orderDeliveryGroup;
        
        List<String> locationGroupIDs = TestDataGenerator.getLocationGroupIDs();
        String reservedAtLocation = locationGroupIDs[0];
        
        OrderItem oi1 =  TestDataGenerator.createOrderItem(order.Id, p1.Id, pbe1.Id, orderDeliveryGroup.Id, 200.0d, reservedAtLocation);
        insert oi1;
        OrderItem oi2 =  TestDataGenerator.createOrderItem(order.Id, p2.Id, pbe2.Id, orderDeliveryGroup.Id, 249.0d, reservedAtLocation);
        insert oi2;
        OrderItem oi3 =  TestDataGenerator.createShippingOrderItem(order.Id, p3.Id, pbe3.Id, orderDeliveryGroup.Id, 20.0d);
        insert oi3;
        
        order.Status='Activated';
        update order;
        
        String orderSummaryId = TestDataGenerator.createOrderSummary(order.Id);
        System.debug('Order Summary Id: ' + orderSummaryId);
        
        List<OrderItemSummary> orderItemSummaries = TestDataGenerator.getOrderItemSummaries(orderSummaryId);
        System.debug('Order Item Summaries: ' + orderItemSummaries.size());
        
        List<String> rankedAvailableLocations = new List<String>();
        rankedAvailableLocations.add(locationAvailability.locationIdentifier);
        System.debug('Ranked Available Locations: ' + rankedAvailableLocations);
        
        return orderSummaryId;
    }


    // Create Fulfillment Order
    private static FulfillmentOrder seedFulfillOrder(){
        OrderDeliveryMethod odm = new OrderDeliveryMethod(
                                        IsActive = false,
                                        Name = 'test'
                                    );
        insert odm;
        FulfillmentOrder fo = new FulfillmentOrder(
                                    FulfilledToName = 'test',
                                    DeliveryMethodId = odm.Id,
            						status = 'Draft'
                                );
        insert fo;
        return fo;
    }

    // Create Fulfillment Order Line Item
    private static FulfillmentOrderLineItem seedFulfillOrderLineItem(FulfillmentOrder fo){
        FulfillmentOrderLineItem foli = new FulfillmentOrderLineItem(
            								Type = 'Order Product',
            								TypeCode = 'Product',
            								Quantity = 1.0,
            								OriginalQuantity = 1.0,
            								UnitPrice = 100.00,
                                            FulfillmentOrderId = fo.Id                                            
                                        );
        insert foli;
        return foli;
    }

    // Create OCI Interaction Order Summary
    private static OCIInteractionOrderSummary__c seedOCIOrderSummary(FulfillmentOrder fo, String orderSummaryId, String orderDeliveryGroupSummaryId){
        OCIInteractionOrderSummary__c ociOrderSummary = new OCIInteractionOrderSummary__c(
            												OrderSummary__c = orderSummaryId,
                                                        	FulfillmentOrder__c = fo.Id,
            												ConnectionFailAttempts__c = 0,
            												OrderDeliveryGroupSummary__c = orderDeliveryGroupSummaryId,
            												Type__c = 'TRANSFER_ROUTING',
                                                        	Status__c = 'REQUESTED',
                                                        	Schedule__c = DateTime.now()
                                                    	);
        insert ociOrderSummary;
        return ociOrderSummary;    
    }
    
    // Create OCI Interaction Order Item Summary
    private static OCIInteractionOrderItemSummary__c seedOCIOrderItemSummary(OCIInteractionOrderSummary__c ociOrderSummary, FulfillmentOrder fo, String orderItemSummaryId){
        OCIInteractionOrderItemSummary__c ociOrderItemSummary = new OCIInteractionOrderItemSummary__c(
            														Quantity__c = 1,
                                                                	OCIInteractionOrderSummary__c = ociOrderSummary.Id,
                                                                	FulfillmentOrder__c = fo.Id,
                                                                	Type__c = 'TRANSFER_ROUTING',
                                                                	Status__c = 'REQUESTED',
            														OrderItemSummary__c = orderItemSummaryId
                                                            	);
        insert ociOrderItemSummary;
        return ociOrderItemSummary;
    }
        
}