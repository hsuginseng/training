/**
 * Tests for OciInventoryPanelController.
 *
 * ConnectApi can't be called in a data-siloed test, so OciInventoryPanelController.reader
 * is swapped for a FakeReader that builds ConnectApi output representations (constructible
 * only in a test context) from a configured identifier -> quantity map. This exercises the
 * real input-building, the location vs location-group routing, and the output mapping.
 *
 * Runs with SeeAllData because the org-agnostic DISCOVERY logic reads real Location and
 * WebStoreInventorySource config (WebStoreInventorySource.LocationSourceExtRef is not
 * createable, so it can't be fabricated in a test).
 */
@isTest(SeeAllData=true)
private class OciInventoryPanelControllerTest {
    /** Builds OCI output reps from a map of identifier -> onHand; null onHand => exists=false. */
    private class FakeReader implements OciInventoryPanelController.AvailabilityReader {
        private Map<String, Decimal> onHandByIdentifier;
        FakeReader(Map<String, Decimal> onHandByIdentifier) {
            this.onHandByIdentifier = onHandByIdentifier;
        }

        public ConnectApi.OCIGetInventoryAvailabilityOutputRepresentation read(
            ConnectApi.OCIGetInventoryAvailabilityInputRepresentation input
        ) {
            String sku = input.stockKeepingUnits[0];
            ConnectApi.OCIGetInventoryAvailabilityOutputRepresentation out =
                new ConnectApi.OCIGetInventoryAvailabilityOutputRepresentation();

            if (input.locationGroupIdentifiers != null) {
                out.locationGroups = new List<ConnectApi.OCILocationGroupAvailabilityOutputRepresentation>();
                for (String id : input.locationGroupIdentifiers) {
                    ConnectApi.OCILocationGroupAvailabilityOutputRepresentation g =
                        new ConnectApi.OCILocationGroupAvailabilityOutputRepresentation();
                    g.locationGroupIdentifier = id;
                    g.inventoryRecords = recordsFor(sku, id);
                    out.locationGroups.add(g);
                }
            }
            if (input.locationIdentifiers != null) {
                out.locations = new List<ConnectApi.OCILocationAvailabilityOutputRepresentation>();
                for (String id : input.locationIdentifiers) {
                    ConnectApi.OCILocationAvailabilityOutputRepresentation loc =
                        new ConnectApi.OCILocationAvailabilityOutputRepresentation();
                    loc.locationIdentifier = id;
                    loc.inventoryRecords = recordsFor(sku, id);
                    out.locations.add(loc);
                }
            }
            return out;
        }

        private List<ConnectApi.OCIInventoryRecordOutputRepresentation> recordsFor(String sku, String id) {
            ConnectApi.OCIInventoryRecordOutputRepresentation rec =
                new ConnectApi.OCIInventoryRecordOutputRepresentation();
            rec.stockKeepingUnit = sku;
            Decimal onHand = onHandByIdentifier.get(id);
            if (onHand == null) {
                rec.exists = false;
                rec.onHand = 0;
                rec.availableToOrder = 0;
                rec.availableToFulfill = 0;
                rec.reserved = 0;
                rec.safetyStockCount = 0;
            } else {
                rec.exists = true;
                rec.onHand = onHand;
                rec.reserved = 1;
                rec.safetyStockCount = 2;
                rec.availableToOrder = onHand - 3;
                rec.availableToFulfill = onHand - 1;
            }
            return new List<ConnectApi.OCIInventoryRecordOutputRepresentation>{ rec };
        }
    }

    /** A map giving every configured location + storefront-group identifier the same onHand. */
    private static Map<String, Decimal> onHandForAllTargets(Decimal onHand) {
        Map<String, Decimal> m = new Map<String, Decimal>();
        for (Schema.Location loc : [
            SELECT ExternalReference FROM Location
            WHERE ShouldSyncWithOci = true AND ExternalReference != null
        ]) {
            m.put(loc.ExternalReference, onHand);
        }
        for (WebStoreInventorySource src : [SELECT LocationSourceExtRef FROM WebStoreInventorySource]) {
            if (String.isNotBlank(src.LocationSourceExtRef)) {
                m.put(src.LocationSourceExtRef, onHand);
            }
        }
        return m;
    }

    private static Integer configuredSourceCount() {
        Integer n = 0;
        for (WebStoreInventorySource src : [SELECT LocationSourceExtRef FROM WebStoreInventorySource]) {
            if (String.isNotBlank(src.LocationSourceExtRef)) {
                n++;
            }
        }
        return n;
    }

    @isTest
    static void blankSkuThrows() {
        Boolean threw = false;
        try {
            OciInventoryPanelController.getInventoryForSku('   ');
        } catch (AuraHandledException e) {
            threw = true;
        }
        System.assert(threw, 'A blank SKU should raise an AuraHandledException.');
    }

    @isTest
    static void assemblesLabelledRowsWithCorrectQuantitiesAndKinds() {
        OciInventoryPanelController.reader = new FakeReader(onHandForAllTargets(123.45));

        Test.startTest();
        OciInventoryPanelController.InventoryView view =
            OciInventoryPanelController.getInventoryForSku('  ANY-SKU  ');
        Test.stopTest();

        System.assertEquals('ANY-SKU', view.sku, 'SKU should be trimmed.');
        System.assert(!view.locations.isEmpty(), 'expected per-location rows in this org');

        for (OciInventoryPanelController.InventoryRow r : view.locations) {
            System.assertEquals('Location', r.targetKind);
            System.assertNotEquals(null, r.targetLabel, 'location rows should be labelled');
            System.assertEquals(true, r.exists);
            System.assertEquals(123.45, r.onHand);
            System.assertEquals(120.45, r.availableToOrder, 'ATO = onHand - safety(2) - reserved(1)');
        }

        System.assertEquals(configuredSourceCount(), view.storefronts.size(), 'one row per storefront source');
        Boolean sawGroup = false;
        for (OciInventoryPanelController.InventoryRow r : view.storefronts) {
            System.assert(
                r.targetKind == 'Location' || r.targetKind == 'Location Group',
                'storefront source must be classified'
            );
            System.assertEquals(true, r.exists);
            if (r.targetKind == 'Location Group') {
                sawGroup = true;
            }
        }
        // This org's B2B storefronts read from Location Groups, so the group path must run.
        System.assert(sawGroup, 'expected at least one Location Group storefront source in this org');
    }

    @isTest
    static void notInOciYieldsExistsFalse() {
        // Empty map => FakeReader returns exists=false for every identifier.
        OciInventoryPanelController.reader = new FakeReader(new Map<String, Decimal>());

        Test.startTest();
        OciInventoryPanelController.InventoryView view =
            OciInventoryPanelController.getInventoryForSku('GHOST-SKU');
        Test.stopTest();

        for (OciInventoryPanelController.InventoryRow r : view.locations) {
            System.assertEquals(false, r.exists, 'unmatched identifiers should read as not-in-OCI');
        }
        for (OciInventoryPanelController.InventoryRow r : view.storefronts) {
            System.assertEquals(false, r.exists);
        }
    }
}