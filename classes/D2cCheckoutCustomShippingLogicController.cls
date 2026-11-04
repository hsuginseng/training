public with sharing class D2cCheckoutCustomShippingLogicController {
    @AuraEnabled(cacheable=false)
    public static boolean removeFreshProductsFromCart(Id cartId) {
        try {
            List<CartItem> cartItems = [SELECT Id, 
                                                CartId, 
                                                Shipping_Category__c 
                                        FROM CartItem  
                                        WHERE CartId =: cartId 
                                        AND Shipping_Category__c = 1];
            delete cartItems;

            //Shipping category of -1 indicates the cart item is a shipping item (not an actual product for sale)
            List<CartItem> cartItemsAfterDelete = [SELECT Id, 
                                                            CartId, 
                                                            Shipping_Category__c 
                                                    FROM CartItem  
                                                    WHERE CartId =: cartId 
                                                    AND Shipping_Category__c != -1];
            if(cartItemsAfterDelete.size() == 0) {
                WebCart cartToDelete = [SELECT Id FROM WebCart WHERE Id =:cartId];
                delete cartToDelete;
                //indicates a deleted cart
                return true;
            }
            //indicates cart record not deleted
            return false;
        }catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=false)
    public static boolean createOrderDeliveryGroup(Id cartId) {
        List<CartDeliveryGroup> cdgList = [SELECT Id, 
                                                    Name, 
                                                    CartId, 
                                                    DeliverToFirstName, 
                                                    DeliverToLastName, 
                                                    DeliverToName, 
                                                    DeliverToStreet, 
                                                    DeliverToCity, 
                                                    DeliverToState, 
                                                    DeliverToPostalCode, 
                                                    DeliverToCountry, 
                                                    DeliveryMethodId, 
                                                    Total_Shipping_Weight_LBs__c,
                                                    TotalAdjustmentAmount,
                                                    Cart.Applied_Loyalty_Voucher_Id__c
                                            FROM CartDeliveryGroup 
                                            WHERE CartId =: cartId 
                                            ORDER BY Name 
                                            DESC];

        cdgList = matchCartDeliveryGroupDeliveryAddresses(cdgList);

        List<CartItem> cartItems = [SELECT Id, 
                                            Name, 
                                            CartId, 
                                            Shipping_Category__c, 
                                            CartDeliveryGroupId 
                                    FROM CartItem 
                                    WHERE CartId =: cartId 
                                    AND Shipping_Category__c != -1];

        WebCart cart = [SELECT Id, 
                                Is_Destination_State_In_Two_Day_Zone__c, 
                                Is_Destination_State_In_Lower_48__c, 
                                Fresh_Ginseng_Weight__c, 
                                Total_Shipping_Weight_LBs__c,
                                Is_OOBO_Cart__c,
                                Applied_Loyalty_Voucher_Id__c, 
                                Cart_Total_Discount_Percentage_Formula__c 
                        FROM WebCart 
                        WHERE Id =: cartId];

        //Calculate Hsus business logic to determine if cart meets split shipment criteria
        Decimal shippingWeightDifferential = cart.Total_Shipping_Weight_LBs__c - cart.Fresh_Ginseng_Weight__c;
        Boolean shouldSplitShipment = false;

        if(!cart.Is_Destination_State_In_Two_Day_Zone__c && shippingWeightDifferential > 1) {
            shouldSplitShipment = true;
        }

        //store all fresh cart items to a list and set a flag if there are any standard products
        List<CartItem> freshProductCartItems = new List<CartItem>();
        Boolean doesCartHaveStandardProducts = false;

        for(CartItem ci: cartItems) {
            //standard product cart item
            if(ci.Shipping_Category__c == 0 || ci.Shipping_Category__c == null) {
                doesCartHaveStandardProducts = true;
            }
            //fresh product cart item
            if(ci.Shipping_Category__c == 1) {
                freshProductCartItems.add(ci);
            }
        }

        //enforcing ginseng removal business logic on back end.
        if(!cart.Is_Destination_State_In_Lower_48__c && freshProductCartItems.size() > 0) {
            throw new HandledException('Fresh ginseng cannot be shipped to your location.');
        }

        //bypass Split-Shipment if the cart originates from an Order on Behalf Of Flow
        if(cart.Is_OOBO_Cart__c == true) {
            return false;
        }

        if(cdgList.size() > 1){
            if(cdgList[0].DeliverToStreet == '123 null st' && !String.isBlank(cdgList[0].Cart.Applied_Loyalty_Voucher_Id__c)) {
                return false;
            }
        }

        //combine fresh and non-fresh if in two-day zone (edge case)
        if(cdgList.size() > 1) {
            if(cart.Is_Destination_State_In_Two_Day_Zone__c && cdgList[1].Total_Shipping_Weight_LBs__c > 0) {
                updateCartItemCartDeliveryGroupID(freshProductCartItems, cdgList[0].Id);
                CartDeliveryGroup cdgToDelete = cdgList[1];
                delete cdgToDelete;
                return true;
            }
        }

        //only process carts that include fresh and non-fresh ginseng products and qualify based on Hsus business logic
        if(freshProductCartItems.size() > 0 && doesCartHaveStandardProducts && shouldSplitShipment) {
            //check for an existing fresh product Cart Delivery Group
            Boolean isFreshProductCDGCreated = false;
            CartDeliveryGroup freshCDG = new CartDeliveryGroup();
            for(CartDeliveryGroup cdg: cdgList) {
                if(cdg.Name == 'Fresh Ginseng Shipment') {
                    isFreshProductCDGCreated = true;
                    freshCDG = cdg;
                }
            }
            //create a fresh product Cart Delivery Group if it doesn't exist yet
            if(!isFreshProductCDGCreated) {
                CartDeliveryGroup cdg = new CartDeliveryGroup();
                cdg.CartId = cartId;
                cdg.Name = 'Fresh Ginseng Shipment';
                cdg.DeliverToFirstName = cdgList[0].DeliverToFirstName;
                cdg.DeliverToLastName = cdgList[0].DeliverToLastName;
                cdg.DeliverToName = cdgList[0].DeliverToName;
                cdg.DeliverToStreet = cdgList[0].DeliverToStreet;
                cdg.DeliverToCity = cdgList[0].DeliverToCity;
                cdg.DeliverToState = cdgList[0].DeliverToState;
                cdg.DeliverToPostalCode = cdgList[0].DeliverToPostalCode;
                cdg.DeliverToCountry = cdgList[0].DeliverToCountry;
                insert cdg;
                //assign fresh product Cart Items to new fresh product Cart Delivery Group
                updateCartItemCartDeliveryGroupID(freshProductCartItems, cdg.Id);
                // Boolean isLoyaltyApplied = D2cCheckoutCustomLoyaltyController.applyLoyaltyVoucher(cartId, cart.Applied_Loyalty_Voucher_Id__c);
                return true;
            }else {
                // check cart items to see if update is necessary
                Boolean shouldUpdateFreshCartItems = false;
                for(CartItem ci: freshProductCartItems){
                    if(ci.CartDeliveryGroupId != freshCDG.Id)
                        shouldUpdateFreshCartItems = true;
                }
                if(shouldUpdateFreshCartItems) {
                    //assign fresh product Cart Items to existing fresh product Cart Delivery Group
                    updateCartItemCartDeliveryGroupID(freshProductCartItems, freshCDG.Id);

                    return true;
                }else {
                    return false;
                }
            }
        }
        //if no cart items manipulated, return false
        return false; 
    }

    private static void updateCartItemCartDeliveryGroupID(List<CartItem> cartItems, Id targetCartDeliveryGroupId) {
        for(CartItem ci: cartItems) {
            ci.CartDeliveryGroupId = targetCartDeliveryGroupId;
        }
        update cartItems;
    }

    private static List<CartDeliveryGroup> matchCartDeliveryGroupDeliveryAddresses(List<CartDeliveryGroup> cdgList) {
        Boolean shouldUpdateRecords = false;
    
        if(cdgList.size() > 1) {
            if(!(cdgList[0].DeliverToStreet == '123 null st' && !String.isBlank(cdgList[0].Cart.Applied_Loyalty_Voucher_Id__c))){
                if(cdgList[0].DeliverToStreet != cdgList[1].DeliverToStreet) {
                    cdgList[1].DeliverToStreet = cdgList[0].DeliverToStreet;
                    shouldUpdateRecords = true;
                }
                if(cdgList[0].DeliverToCity != cdgList[1].DeliverToCity) {
                    cdgList[1].DeliverToCity = cdgList[0].DeliverToCity;
                    shouldUpdateRecords = true;
                }
                if(cdgList[0].DeliverToState != cdgList[1].DeliverToState) {
                    cdgList[1].DeliverToState = cdgList[0].DeliverToState;
                    shouldUpdateRecords = true;
                }
                if(cdgList[0].DeliverToPostalCode != cdgList[1].DeliverToPostalCode) {
                    cdgList[1].DeliverToPostalCode = cdgList[0].DeliverToPostalCode;
                    shouldUpdateRecords = true;
                }
                if(cdgList[0].DeliverToCountry != cdgList[1].DeliverToCountry) {
                    cdgList[1].DeliverToCountry = cdgList[0].DeliverToCountry;
                    shouldUpdateRecords = true;
                }
                if(cdgList[0].DeliverToName != cdgList[1].DeliverToName) {
                    cdgList[1].DeliverToName = cdgList[0].DeliverToName;
                    shouldUpdateRecords = true;
                }
                if(cdgList[0].DeliverToFirstName != cdgList[1].DeliverToFirstName) {
                    cdgList[1].DeliverToFirstName = cdgList[0].DeliverToFirstName;
                    shouldUpdateRecords = true;
                }
                if(cdgList[0].DeliverToLastName != cdgList[1].DeliverToLastName) {
                    cdgList[1].DeliverToLastName = cdgList[0].DeliverToLastName;
                    shouldUpdateRecords = true;
                }
            }
        }

        if(shouldUpdateRecords) {
            update cdgList;
        }

        return cdgList;
    }
}