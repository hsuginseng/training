public class ShippingAddressValidator {

    /** Test‐only hook: when non‐null in @isTest, we skip the real callout */
    @TestVisible private static zkmulti.AddressValidationResult TEST_OVERRIDE_RES;

    @AuraEnabled (cacheable=true)
    public static AddressValidationResultWrapper validateDeliveryAddress(Map<String, String> address, String shippingPreferenceKeyword){

        // SHORT-CIRCUIT IN TESTS
        if (Test.isRunningTest() && TEST_OVERRIDE_RES != null) {
            return new AddressValidationResultWrapper(TEST_OVERRIDE_RES);
        }
        /*
        Map looks like this:
        <
            "company": "",
            "email": "",
            "name": "",
            "phone": "",
            "street": "",
            "city": "",
            "postalCode": "",
            "stateCode": "",
            "countryCode": ""
        >
        */
        
        if(shippingPreferenceKeyword == null){ shippingPreferenceKeyword = 'UPS'; }
        shippingPreferenceKeyword = shippingPreferenceKeyword + '%';
        Id preferenceId = [Select Id, zkmulti__Carrier__c FROM zkmulti__MCShipmate_Preference__c WHERE zkmulti__Carrier__c LIKE :shippingPreferenceKeyword LIMIT 1][0].Id; // Salesforce ID of your UPS Preference];
        
        zkmulti__MCShipment__c ship = new zkmulti__MCShipment__c(
            // recipient info
            zkmulti__Recipient_Company__c = address.get('company'),
            zkmulti__Recipient_Email__c = address.get('email'),
            zkmulti__Recipient_Name__c = address.get('name'),
            zkmulti__Recipient_Phone__c = address.get('phone'),
            zkmulti__Recipient_Street__c = address.get('street'),
            zkmulti__Recipient_City__c = address.get('city'),
            zkmulti__Recipient_Zip_Postal_Code__c = address.get('postalCode'),
            zkmulti__Recipient_State_Province__c = address.get('stateCode'),
            zkmulti__Recipient_Country__c = address.get('countryCode')
        );

        try {
            //result:AddressValidationResult:
            //[addresses=(AddressResult:[addressClassificationCode=null, city=Glendale Heights,
            //country=US, description=null, postalCode=60139, postalCodeZip4=null, residential=true,
            //state=IL, streetLines=(31 Devon Dr), urbanizationCode=null]), attributes={validAddressIndicator=true},
            //isResidential=false, isValid=true, messages=()]
            zkmulti.AddressValidationResult result = zkmulti.ShipmentInterface.validateAddress(ship, preferenceId);
            System.debug('result:' + result);
            System.debug('result.AddressValidationResult.isValid: ' + result.isValid);

            AddressValidationResultWrapper resultWrapper = new AddressValidationResultWrapper(result);
            return resultWrapper;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    public class AddressValidationResultWrapper{
        @AuraEnabled public Boolean isValid;
        @AuraEnabled public Boolean isResidential;
        @AuraEnabled public String streetLine1;
        @AuraEnabled public String streetLine2;
        @AuraEnabled public String city;
        @AuraEnabled public String state;
        @AuraEnabled public String postalCode;
        @AuraEnabled public String country;

        public AddressValidationResultWrapper(zkmulti.AddressValidationResult result){
            this.isValid = result.isValid;
            this.isResidential = result.addresses[0].residential;
            this.streetLine1 = result.addresses[0].streetLines[0];
            //this.streetLine2 = result.addresses[0].
            this.city = result.addresses[0].city;
            this.state = result.addresses[0].state;
            this.postalCode = result.addresses[0].postalCode;
            this.country = result.addresses[0].country;
        }
    }
}