@IsTest
private class ShippingAddressValidatorTest {
    /** 
     * Helper to build a fake zkmulti.AddressValidationResult
     * that our wrapper will consume.
     */
    private static zkmulti.AddressValidationResult buildFakeResult() {
        // 1) Create the outer result
        zkmulti.AddressValidationResult fakeRes = new zkmulti.AddressValidationResult();
        fakeRes.isValid = true;
        
        // 2) Instantiate its 'addresses' list of the nested type
        fakeRes.addresses = new List<zkmulti.AddressValidationResult.AddressResult>();
        
        // 3) Build one AddressResult entry
        zkmulti.AddressValidationResult.AddressResult ar =
            new zkmulti.AddressValidationResult.AddressResult();
        ar.residential = false;
        ar.streetLines = new List<String>{ '123 Main St', 'Apt 4' };
        ar.city = 'CityX';
        ar.state = 'CA';
        ar.postalCode = '90210';
        ar.country = 'US';
        
        fakeRes.addresses.add(ar);
        return fakeRes;
    }

    @IsTest
    static void testValidateDeliveryAddress_Success() {
        // Inject our fake result into the @TestVisible seam
        ShippingAddressValidator.TEST_OVERRIDE_RES = buildFakeResult();
        
        // Call under test (inputs don’t matter once override is set)
        ShippingAddressValidator.AddressValidationResultWrapper wrap =
            ShippingAddressValidator.validateDeliveryAddress(
                new Map<String,String>(), null);
        
        // Verify that the wrapper picked up our fakeRes values
        System.assertEquals(true,  wrap.isValid, 'isValid');
        System.assertEquals(false, wrap.isResidential, 'isResidential');
        System.assertEquals('123 Main St', wrap.streetLine1);
        System.assertEquals('CityX', wrap.city);
        System.assertEquals('CA', wrap.state);
        System.assertEquals('90210', wrap.postalCode);
        System.assertEquals('US', wrap.country);
    }

    @IsTest
    static void testValidateDeliveryAddress_ThrowsAuraHandledException() {
        // Clear the override so the real code path (and its exception branch) runs
        ShippingAddressValidator.TEST_OVERRIDE_RES = null;
        
        // Insert a dummy UPS preference so the SOQL LIKE 'UPS%' finds one
        insert new zkmulti__MCShipmate_Preference__c(
            zkmulti__Carrier__c = 'UPS Test');
        
        // Invoke and confirm we get an AuraHandledException
        Boolean sawException = false;
        try {
            ShippingAddressValidator.validateDeliveryAddress(
                new Map<String,String>(), 'UPS');
        } catch (AuraHandledException ex) {
            sawException = true;
        }
        System.assert(sawException, 'Expected an AuraHandledException when callout/validation fails');
    }
}