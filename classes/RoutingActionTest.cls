@IsTest(SeeAllData=true)
public class RoutingActionTest {

    // Expected Input: RoutingActionInput containing location group Ids, summaries, etc
    // Expected Output: RoutingActionResult containing a RoutingActionOutput object embedded
    @IsTest static void test_RoutingAction_success() {
        // Arrange
        TestDataGenerator.seedLocationData();
 		Test.startTest();
		List<RoutingActionInput> routingActionInputs = createRoutingActionInputs();
        
        System.assertNotEquals(null, routingActionInputs, 'Routing Action Inputs list should not be null');
        
        // Act
        List<RoutingActionResult> routingActionResults = RoutingAction.generateRoutingData(routingActionInputs);
        Test.stopTest();
        System.assertNotEquals(null, routingActionResults, 'Routing Action Results list should not be null');
        
        // Assert
        for(RoutingActionResult routingActionResult : routingActionResults) {
            RoutingActionOutput routingActionOutput = routingActionResult.output;

            System.assertNotEquals(null, routingActionOutput, 'Routing Action Output object should not be null');
            System.assertNotEquals(null, routingActionOutput.orderSummaryId, 'Order Summary ID should not be null');
        }
         
    }
    
    private static List<RoutingActionInput> createRoutingActionInputs() {
        List<RoutingActionInput> inputs = new List<RoutingActionInput>();
        String timestamp = String.valueOf(DateTime.now());
        
        // Creating Availability Data       
        List<ConnectApi.OCIInventoryRecordOutputRepresentation> inventoryRecords = new List<ConnectApi.OCIInventoryRecordOutputRepresentation>();
        ConnectApi.OCIInventoryRecordOutputRepresentation record1 = new ConnectApi.OCIInventoryRecordOutputRepresentation();
        String sku1 = 'sku1' + timestamp;
        record1.stockKeepingUnit = sku1;
        record1.availableToFulfill = 10;
        record1.availableToOrder = 10;
        record1.onHand = 5;

        ConnectApi.OCIInventoryRecordOutputRepresentation record2 = new ConnectApi.OCIInventoryRecordOutputRepresentation();
        String sku2 = 'sku2' + timestamp;
        record2.stockKeepingUnit = sku2;
        record2.availableToFulfill = 10;
        record2.availableToOrder = 5;
        record2.onHand = 6;
        
        ConnectApi.OCIInventoryRecordOutputRepresentation record3 = new ConnectApi.OCIInventoryRecordOutputRepresentation();
        String sku3 = 'sku3'+timestamp;
        record3.stockKeepingUnit = sku3;
        record3.availableToFulfill = 1;
        record3.availableToOrder = 1;
        inventoryRecords.add(record1);
        inventoryRecords.add(record2);
        inventoryRecords.add(record3);
        
        ConnectApi.OCILocationAvailabilityOutputRepresentation locationAvailability1 = new ConnectApi.OCILocationAvailabilityOutputRepresentation();
        locationAvailability1.locationIdentifier = 'Loc-1';
        locationAvailability1.inventoryRecords = inventoryRecords;
        
        ConnectApi.OCILocationAvailabilityOutputRepresentation locationAvailability2 = new ConnectApi.OCILocationAvailabilityOutputRepresentation();
        locationAvailability2.locationIdentifier = 'Loc-2';
        locationAvailability2.inventoryRecords = inventoryRecords;
        
        List<ConnectApi.OCILocationAvailabilityOutputRepresentation> locations = new List<ConnectApi.OCILocationAvailabilityOutputRepresentation>();
        locations.add(locationAvailability1);
        locations.add(locationAvailability2);
        
    	ConnectApi.OCIGetInventoryAvailabilityOutputRepresentation availability1 = new ConnectApi.OCIGetInventoryAvailabilityOutputRepresentation();
        availability1.locations = locations;
        
        List<ConnectApi.OCIGetInventoryAvailabilityOutputRepresentation> inventoryAvailabilityList = new List<ConnectApi.OCIGetInventoryAvailabilityOutputRepresentation>();
        inventoryAvailabilityList.add(availability1);

        // Create Product Data
        
        Product2 p1 = TestDataGenerator.createProduct2('P1', sku1);
        insert p1;
        
        Product2 p2 = TestDataGenerator.createProduct2('P2', sku2);
        insert p2;        
        
        PriceBookEntry pbe1 = TestDataGenerator.createPriceBookEntry(p1.Id, System.Test.getStandardPricebookId());
        insert pbe1;
        PriceBookEntry pbe2 = TestDataGenerator.createPriceBookEntry(p2.Id, System.Test.getStandardPricebookId());
        insert pbe2;

        // Test Purchaser Data for Order
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
        
        OrderDeliveryMethod odm  = TestDataGenerator.getOrderDeliveryMethod('002');
        Product2 p3 = null;
        PriceBookEntry pbe3 = null;
        if (odm == null) {
            // Only Create the product if needed for the Order Delivery Method
            p3 = TestDataGenerator.createProduct2('Shipping', sku3);
        	insert p3;
            
            pbe3 = TestDataGenerator.createPriceBookEntry(p3.Id, System.Test.getStandardPricebookId());
        	insert pbe3;
            
            odm = TestDataGenerator.createOrderDeliveryMethodWithProduct('Overnight Shipping', '002', p3);
        	insert odm;
            
			System.debug('New Shipping Entry Created: ' + odm);
        } else {
            // Query for Product2 entry and pb entry
            p3 = TestDataGenerator.getProduct2(odm.ProductId);
            System.debug('Found p3 ' + p3);
            pbe3 = TestDataGenerator.getPricebookEntry(odm.ProductId);
            System.debug('Retrieved Shipping Charge Product Entry ' + p3.Id + ' and PricebookEntry '+ pbe3.Id);
        }
        
        OrderDeliveryGroup orderDeliveryGroup = TestDataGenerator.createOrderDeliveryGroup(order.Id, odm.Id, testEmail, fullName);
        insert orderDeliveryGroup;
        
        System.debug('Order Delivery Method Referenced: ' + odm);
        
        List<String> locationGroupIDs = TestDataGenerator.getLocationGroupIDs();
        String reservedAtLocation = locationGroupIDs[0];
        
        OrderItem oi1 =  TestDataGenerator.createOrderItem(order.Id, p1.Id, pbe1.Id, orderDeliveryGroup.Id, 200.0d, reservedAtLocation);
        insert oi1;
        OrderItem oi2 =  TestDataGenerator.createOrderItem(order.Id, p2.Id, pbe2.Id, orderDeliveryGroup.Id, 249.0d, reservedAtLocation);
        insert oi2;
        OrderItem oi3 =  TestDataGenerator.createShippingOrderItem(order.Id, p3.Id, pbe3.Id, orderDeliveryGroup.Id, 20.0d);
        insert oi3;
            
        System.debug('Shipping Order Item: ' + oi3);
        System.debug('Shipping Order Item Id: ' + oi3.Id);
        
        order.Status='Activated';
        update order;
        
        String orderSummaryId = TestDataGenerator.createOrderSummary(order.Id);
        
        List<OrderItemSummary> orderItemSummaries = TestDataGenerator.getOrderItemSummaries(orderSummaryId);
        for(OrderItemSummary orderItemSummary: orderItemSummaries) {
            if (orderItemSummary.Product2Id == p3.Id) {
                System.debug('Fulfillment QTY for shipping item ' + orderItemSummary.QuantityAvailableToFulfill);
            } 
        }
        
        
        List<String> rankedAvailableLocations = new List<String>();
        rankedAvailableLocations.add(locationAvailability1.locationIdentifier);
        rankedAvailableLocations.add(locationAvailability2.locationIdentifier);
        
        // Build out the RoutingActionInput
        RoutingActionInput routingActionInput = new RoutingActionInput();
        routingActionInput.orderItemSummaries = orderItemSummaries;
        routingActionInput.orderSummaryId = orderSummaryId;
        routingActionInput.locationGroupIds = locationGroupIDs;
        routingActionInput.inventoryAvailabilityList = inventoryAvailabilityList;
        routingActionInput.rankAvailableLocationsToFulfill = rankedAvailableLocations;
        
        inputs.add(routingActionInput);
        
        System.debug('Routing Action Input: ' + inputs);
        
        return inputs;
    }
}