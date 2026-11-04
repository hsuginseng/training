public class TestDataGenerator {
	public static void seedLocationData(){
        // Create Locations
        Schema.Location loc1 = new Schema.Location(
                                    Name = 'Loc-1',
                                    LocationType = 'Warehouse',
                                    ShouldSyncWithOci = true,
            						ExternalReference = 'Loc-1'
                                );  
        Schema.Location loc2 = new Schema.Location(
                                    Name = 'Loc-2',
                                    LocationType = 'Warehouse',
                                    ShouldSyncWithOci = true,
            						ExternalReference = 'Loc-2'
                                ); 
        Schema.Location loc3 = new Schema.Location(
                                    Name = 'Loc-3',
                                    LocationType = 'Warehouse',
                                    ShouldSyncWithOci = true,
            						ExternalReference = 'Loc-3'
                                );
        Schema.Location loc4 = new Schema.Location(
                                    Name = 'Loc-4',
                                    LocationType = 'Warehouse',
                                    ShouldSyncWithOci = true,
            						ExternalReference = 'Loc-4'
                                );
        
        List<Schema.Location> locations = new List<Schema.Location>();
        locations.add(loc1); 
        locations.add(loc2);
        locations.add(loc3);
        locations.add(loc4);
        insert locations;                  


        // Create LocationGroups
        List<LocationGroup> locationGroups = createLocationGroups();

        // Create Location Group Assignment
        List<LocationGroupAssignment> assignments = new List<LocationGroupAssignment> {
            new LocationGroupAssignment(
                LocationId = loc1.Id,
                LocationGroupId = locationGroups[0].Id
            ),
            new LocationGroupAssignment(
                LocationId = loc2.Id,
                LocationGroupId = locationGroups[0].Id
            ),
            new LocationGroupAssignment(
                LocationId = loc3.Id,
                LocationGroupId = locationGroups[0].Id
            ),
            new LocationGroupAssignment(
                LocationId = loc4.Id,
                LocationGroupId = locationGroups[1].Id
            )
        };
        insert assignments;

    }
    
    public static List<LocationGroup> createLocationGroups() {
        // Create LocationGroups - Default East and West Warehouse types
        LocationGroup group1 = new LocationGroup(
                                    LocationGroupName = 'East',
                                    ExternalReference = 'East',
                                    ShouldSyncWithOci = true
                                );
        LocationGroup group2 = new LocationGroup(
                                    LocationGroupName = 'West',
                                    ExternalReference = 'West',
                                    ShouldSyncWithOci = true
                                );
        
        List<LocationGroup> locationGroups = new List<LocationGroup>();
        locationGroups.add(group1);
        locationGroups.add(group2);
        insert locationGroups;
        
        return locationGroups;
    }
    
    public static List<String> getLocationGroupIDs() {
        // Query LocationGroups East and West for their IDs
        List<Schema.LocationGroup> locationGroups = [SELECT Id, ExternalReference 
                                                     FROM LocationGroup 
                                                     WHERE ExternalReference  = 'West' OR ExternalReference  = 'East'];
        
        List<String> locationGroupIDs = new List<String>();
        for(LocationGroup locationGroup : locationGroups) {
            locationGroupIDs.add(locationGroup.Id);
        }
        
        System.assertNotEquals(null, locationGroupIDs, 'Location Group IDs should not be null');
        
        return locationGroupIDs;
    }
    
    public static Account getAccount(String name) {
        List<Account> account = [SELECT Id, Name FROM Account WHERE Name =: name LIMIT 1];
        
        if (account.size() == 0) {
            return null;
        }
        
        return account[0];
    }
    
    public static Contact getContact(String accountId) {
        List<Contact> contact = [SELECT Id FROM Contact WHERE AccountId =: accountId LIMIT 1];
        
        if (contact.size() == 0) {
            return null;
        }
        
        return contact[0];
    }
    
    public static List<OrderItemSummary> getOrderItemSummaries(String orderSummaryId) {
        List<OrderItemSummary> orderItemSummaries = [SELECT Id, QuantityOrdered, StockKeepingUnit, 
                                                     Product2Id, OrderSummaryId, QuantityAvailableToFulfill, 
                                                     Type, ReservedAtLocationId FROM OrderItemSummary WHERE OrderSummaryId =: orderSummaryId ];
        
        return orderItemSummaries;
    }
    
    public static List<OrderItemSummary> getOrderItemSummariesByIdList(List<String> orderSummaries) {
        List<OrderItemSummary> orderItemSummaries = [SELECT Id, QuantityOrdered, StockKeepingUnit, 
                                                     Product2Id, OrderSummaryId, QuantityAvailableToFulfill, 
                                                     Type, ReservedAtLocationId FROM OrderItemSummary 
                                                     WHERE OrderSummaryId IN :orderSummaries ];
        
        return orderItemSummaries;
    }

    public static Account createAccount(String name, String email)
    {
      
        Account a = new Account(Name='SFDX Test');
        insert a;
            
        return a;
    }

    public static Contact createContact(String firstName, String lastName, String phoneNumber, String accID)
    {
        Contact con = new Contact(
            FirstName=firstName,
            LastName=lastName,
            Phone=phoneNumber,
            AccountId=accID);

        Database.DMLOptions dml = new Database.DMLOptions(); 
        dml.DuplicateRuleHeader.allowSave = true;
        Database.SaveResult sr = Database.insert(con, dml);
    
        if (sr.isSuccess()) {
            System.debug('Duplicate account has been inserted in Salesforce!');
        }

        System.debug('Contact Test: ' + con);
        
        return con;
    }

    public static SalesChannel createSalesChannel(String channelname)
    {
        SalesChannel sc = new SalesChannel();
        sc.SalesChannelName = channelname;
        
        return sc;
    }

    public static OrderItem createShippingOrderItem(Id orderId, Id product2Id, Id pricebookEntryId, Id orderDeliveryGroupId, Double amount)
    {
        OrderItem oi = new OrderItem();
        oi.OrderId = orderId;
        oi.Quantity = 1;
        oi.UnitPrice = 10;
        oi.Product2id = product2Id;
        oi.PricebookEntryId=pricebookEntryId;
        oi.OrderDeliveryGroupId = orderDeliveryGroupId;
        oi.Description = 'Shipping';
        oi.Type = 'Delivery Charge';
        oi.TotalLineAmount = amount; 
        
        return oi;
    }
    
    public static OrderDeliveryMethod createOrderDeliveryMethod(String name)
    {        
        OrderDeliveryMethod odm = new OrderDeliveryMethod(IsActive = true,
                                                          Name = name);
        
        return odm;
    }
    
    public static OrderDeliveryMethod createOrderDeliveryMethodWithProduct(String name, String externalReference, Product2 shippingProduct) {
        OrderDeliveryMethod odm = new OrderDeliveryMethod(IsActive = true,
                                                          Name = name,
                                                          ReferenceNumber = externalReference,
                                                          ProductId = shippingProduct.Id);
        
        return odm;
    }
    
    public static OrderDeliveryMethod getOrderDeliveryMethod(String externalReference) {
        List<OrderDeliveryMethod> orderDeliveryMethod = [SELECT Id, Name, ReferenceNumber FROM OrderDeliveryMethod WHERE ReferenceNumber =: externalReference LIMIT 1];
        
        if (orderDeliveryMethod.size() == 0) {
            return null;
        }
        
        return orderDeliveryMethod[0];
    }

    public static OrderDeliveryGroup createOrderDeliveryGroup(String orderId, Id orderDeliveryMethodId, 
                                                              String email, String name)
    {
        OrderDeliveryGroup odg = new OrderDeliveryGroup(DeliverToCity = 'Deerfield Beach', 
                                                       DeliverToStreet = '1166 W Newport Center Dr STE 210', 
                                                       DeliverToPostalCode = '33442',
                                                       DeliverToState = 'FL',
                                                       EmailAddress = email,
                                                       OrderId = orderId, 
                                                       DeliverToName = name, 
                                                       OrderDeliveryMethodId = orderDeliveryMethodId);        
        return odg;
    }

    
    public static Product2 createProduct2(String name, String sku) {
        Product2 p2 = new Product2();
        p2.Name = name;
        p2.StockKeepingUnit = sku;
        
        return p2;
    }
    
    public static Product2 getProduct2(String productId) {
        List<Product2> result = [SELECT Id, Name FROM Product2 WHERE Id =: productId LIMIT 1];
        System.debug('Product Search result for productId=' + productId + ': ' + result);
        if ( result == null || result.size() == 0) {
            return null;
        } else {
            return result[0];
        }
    }
    
    public static PricebookEntry getPricebookEntry(String product2Id) {
        List<PricebookEntry> result = [SELECT Id FROM PricebookEntry WHERE Product2Id =: product2Id LIMIT 1];
        
        if (result.size() == 0) {
            return null;
        }
        
        return result[0];
    }

    public static OrderItem createOrderItem(Id orderId, Id product2Id, Id pricebookEntryId, Id orderDeliveryGroupId, 
                                            Double amount, String reservedAtLocation)
    {
        OrderItem oi = new OrderItem();
        oi.OrderId = orderId;
        oi.Quantity = 2;
        oi.UnitPrice = 240;
        oi.Product2id = product2Id;
        oi.PricebookEntryId=pricebookEntryId;
        oi.OrderDeliveryGroupId = orderDeliveryGroupId;
        oi.Description = 'Some Product';
        oi.TotalLineAmount = amount;
        oi.ReservedAtLocationId = reservedAtLocation;
        oi.Type = 'Order Product';
        
        return oi;
    }

    public static PriceBookEntry createPriceBookEntry(String productId, String priceBookId)
    {
       PricebookEntry pbe = new PricebookEntry();
        pbe.Pricebook2Id = priceBookId;
        pbe.Product2Id = productId;
        pbe.UnitPrice = 100;
        pbe.IsActive = true;

       return pbe ;
    }

    public static Order createOrder(Id accountId, Id pricebook2Id, Id salesChannelId, String email)
    {
        Order o = new Order(Name = 'Order123456', 
                            AccountId = accountId, 
                            EffectiveDate = system.today(), 
                            status = 'Draft',
                            Pricebook2Id = pricebook2Id, 
                            SalesChannelId= salesChannelId,
                            OrderReferenceNumber ='CCS-Standard3', 
                            BillingStreet = '1166 W Newport Center Dr STE 210', 
                            BillingState= 'FL', 
                            BillingCountry = 'US', 
                            BillingPostalCode = '33442', 
                            BillingCity ='Deerfield Beach', 
                            OrderedDate = system.today(),
                            BillingEmailAddress = email);
        
        return o;
    }

    public static String createOrderSummary(String orderId)
    {
        ConnectApi.OrderSummaryInputRepresentation inputRep  = new ConnectApi.OrderSummaryInputRepresentation();
        inputRep.orderId = orderId;
        inputRep.orderLifeCycleType = 'Managed';
        inputRep.name = 'OrderSummary' + orderId;
        
        ConnectApi.OrderSummaryOutputRepresentation outputRep = new ConnectApi.OrderSummaryOutputRepresentation();
        outputRep = connectapi.OrderSummaryCreation.createOrderSummary(inputRep);
        
        return outputRep.orderSummaryId;
    }

    
    public static String getOrderSummaryDeliveryGroup(String orderSummaryId){
        List<OrderDeliveryGroupSummary> odgs = [SELECT Id  FROM OrderDeliveryGroupSummary WHERE OrderSummaryId =: orderSummaryId LIMIT 1];
        return odgs[0].Id;
    }
    
    public static String getOrderSummaryItems(String orderSummaryId){
        List<OrderItemSummary> ois = [SELECT Id  FROM OrderItemSummary WHERE OrderSummaryId =: orderSummaryId LIMIT 1];
    	return ois[0].Id;
    }
    
}