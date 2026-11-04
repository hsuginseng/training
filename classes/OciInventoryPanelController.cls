/**
 * Read-only Omnichannel Inventory (OCI) view for a single SKU, resolved across every
 * storefront and every OCI-synced location in the org.
 *
 * Fully ORG-AGNOSTIC by design: locations, storefronts, and the Location-vs-LocationGroup
 * classification are all discovered at runtime from queryable config (Location,
 * WebStoreInventorySource). There are NO hardcoded identifiers, so the same class drops
 * into any org that has Omnichannel Inventory.
 *
 * Why Apex + Connect API: OCI quantities are not exposed to SOQL or the REST data APIs.
 * The supported read path is ConnectApi.OmnichannelInventoryService.getInventoryAvailability.
 * A storefront's source (WebStoreInventorySource.LocationSourceExtRef) is either a Location
 * ExternalReference or a Location Group identifier; the two use DIFFERENT input/output
 * fields on that call (locationIdentifiers/output.locations vs
 * locationGroupIdentifiers/output.locationGroups). We classify each ref against the set of
 * Location.ExternalReference values and route it to the correct bucket.
 *
 * Read-only: this class never writes inventory.
 */
public with sharing class OciInventoryPanelController {
    // OCI hard cap: stockKeepingUnits.size() * identifiers.size() must be <= 100 per call.
    @TestVisible
    private static final Integer MAX_CHECKS_PER_CALL = 100;

    /**
     * The single point that touches OCI. Swapped for a fake in tests (ConnectApi can't be
     * called in a data-siloed test) so the input-building and output-mapping logic is still
     * exercised. The live implementation is one line; everything else is testable.
     */
    public interface AvailabilityReader {
        ConnectApi.OCIGetInventoryAvailabilityOutputRepresentation read(
            ConnectApi.OCIGetInventoryAvailabilityInputRepresentation input
        );
    }

    private class LiveReader implements AvailabilityReader {
        public ConnectApi.OCIGetInventoryAvailabilityOutputRepresentation read(
            ConnectApi.OCIGetInventoryAvailabilityInputRepresentation input
        ) {
            return ConnectApi.OmnichannelInventoryService.getInventoryAvailability(input);
        }
    }

    @TestVisible
    private static AvailabilityReader reader = new LiveReader();

    @AuraEnabled(cacheable=false)
    public static InventoryView getInventoryForSku(String sku) {
        try {
            if (String.isBlank(sku)) {
                throw new AuraHandledException('A SKU is required to read inventory.');
            }
            sku = sku.trim();

            // 1. Discover OCI-synced locations (ExternalReference -> Name). Org-agnostic.
            //    Schema.Location disambiguates from System.Location (the geolocation type).
            Map<String, String> locationNameByRef = new Map<String, String>();
            for (Schema.Location loc : [
                SELECT Name, ExternalReference
                FROM Location
                WHERE ShouldSyncWithOci = true AND ExternalReference != null
            ]) {
                locationNameByRef.put(loc.ExternalReference, loc.Name);
            }

            // 2. Discover storefront -> inventory source. LocationSourceExtRef is not
            //    filterable in SOQL, so blanks are skipped in Apex below.
            List<WebStoreInventorySource> sources = [
                SELECT WebStore.Name, LocationSourceExtRef
                FROM WebStoreInventorySource
                ORDER BY WebStore.Name
            ];

            // 3. Partition every identifier we must read into the two OCI buckets. A
            //    storefront source is a Location when its ref is a known Location
            //    ExternalReference; otherwise it's a Location Group.
            Set<String> locationIds = new Set<String>(locationNameByRef.keySet());
            Set<String> groupIds = new Set<String>();
            for (WebStoreInventorySource src : sources) {
                if (String.isBlank(src.LocationSourceExtRef)) {
                    continue;
                }
                if (!locationNameByRef.containsKey(src.LocationSourceExtRef)) {
                    groupIds.add(src.LocationSourceExtRef);
                }
            }

            // 4. Read OCI for both buckets (chunked to the 100-check cap).
            Map<String, InventoryRow> byLocation = readBucket(sku, new List<String>(locationIds), false);
            Map<String, InventoryRow> byGroup = readBucket(sku, new List<String>(groupIds), true);

            // 5. Assemble the view.
            InventoryView view = new InventoryView();
            view.sku = sku;
            view.locations = new List<InventoryRow>();
            view.storefronts = new List<InventoryRow>();

            // Per-location detail (stable order by reference).
            List<String> orderedRefs = new List<String>(locationNameByRef.keySet());
            orderedRefs.sort();
            for (String ref : orderedRefs) {
                view.locations.add(rowFor(byLocation, ref, 'Location', locationNameByRef.get(ref)));
            }

            // Per-storefront: the source each store actually sells from.
            for (WebStoreInventorySource src : sources) {
                if (String.isBlank(src.LocationSourceExtRef)) {
                    continue;
                }
                Boolean isGroup = !locationNameByRef.containsKey(src.LocationSourceExtRef);
                view.storefronts.add(rowFor(
                    isGroup ? byGroup : byLocation,
                    src.LocationSourceExtRef,
                    isGroup ? 'Location Group' : 'Location',
                    src.WebStore != null ? src.WebStore.Name : src.LocationSourceExtRef
                ));
            }

            return view;
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('Error reading OCI inventory: ' + e.getMessage());
        }
    }

    /**
     * Reads availability for one SKU across many identifiers of a single kind, chunked to
     * the OCI 100-check cap. Returns a map identifier -> InventoryRow (quantities only).
     */
    private static Map<String, InventoryRow> readBucket(String sku, List<String> identifiers, Boolean isGroup) {
        Map<String, InventoryRow> result = new Map<String, InventoryRow>();
        if (identifiers.isEmpty()) {
            return result;
        }

        // 1 SKU here, so up to MAX_CHECKS_PER_CALL identifiers per call; the math
        // generalizes if this is ever extended to multiple SKUs.
        Integer chunkSize = Math.max(1, MAX_CHECKS_PER_CALL); // skuCount == 1
        for (Integer i = 0; i < identifiers.size(); i += chunkSize) {
            List<String> chunk = new List<String>();
            for (Integer j = i; j < Math.min(i + chunkSize, identifiers.size()); j++) {
                chunk.add(identifiers[j]);
            }

            ConnectApi.OCIGetInventoryAvailabilityInputRepresentation input =
                new ConnectApi.OCIGetInventoryAvailabilityInputRepresentation();
            input.stockKeepingUnits = new List<String>{ sku };
            input.useCache = false;
            if (isGroup) {
                input.locationGroupIdentifiers = chunk;
            } else {
                input.locationIdentifiers = chunk;
            }

            ConnectApi.OCIGetInventoryAvailabilityOutputRepresentation output = reader.read(input);

            if (isGroup) {
                if (output.locationGroups != null) {
                    for (ConnectApi.OCILocationGroupAvailabilityOutputRepresentation g : output.locationGroups) {
                        result.put(g.locationGroupIdentifier, toRow(sku, g.inventoryRecords));
                    }
                }
            } else if (output.locations != null) {
                for (ConnectApi.OCILocationAvailabilityOutputRepresentation loc : output.locations) {
                    result.put(loc.locationIdentifier, toRow(sku, loc.inventoryRecords));
                }
            }
        }
        return result;
    }

    /** Picks the record for our SKU out of a target's inventoryRecords, or null. */
    private static InventoryRow toRow(
        String sku,
        List<ConnectApi.OCIInventoryRecordOutputRepresentation> records
    ) {
        if (records == null) {
            return null;
        }
        for (ConnectApi.OCIInventoryRecordOutputRepresentation r : records) {
            if (r.stockKeepingUnit == sku) {
                InventoryRow row = new InventoryRow();
                row.exists = r.exists;
                row.onHand = r.onHand;
                row.availableToOrder = r.availableToOrder;
                row.availableToFulfill = r.availableToFulfill;
                row.reserved = r.reserved;
                row.safetyStockCount = r.safetyStockCount;
                return row;
            }
        }
        return null;
    }

    /**
     * Builds a fresh labelled row from the bucket's quantity data, defaulting to a
     * not-in-OCI (exists=false) row when OCI returned nothing for the identifier. Always
     * returns a new instance so a location source shared by a storefront (e.g. D2C reading
     * a Location) doesn't alias the per-location row's label.
     */
    private static InventoryRow rowFor(Map<String, InventoryRow> bucket, String id, String kind, String label) {
        InventoryRow data = bucket.get(id);
        InventoryRow row = new InventoryRow();
        row.targetId = id;
        row.targetKind = kind;
        row.targetLabel = label;
        if (data == null) {
            row.exists = false;
        } else {
            row.exists = data.exists;
            row.onHand = data.onHand;
            row.availableToOrder = data.availableToOrder;
            row.availableToFulfill = data.availableToFulfill;
            row.reserved = data.reserved;
            row.safetyStockCount = data.safetyStockCount;
        }
        return row;
    }

    public class InventoryView {
        @AuraEnabled
        public String sku;
        @AuraEnabled
        public List<InventoryRow> storefronts;
        @AuraEnabled
        public List<InventoryRow> locations;
    }

    public class InventoryRow {
        @AuraEnabled
        public String targetId;
        @AuraEnabled
        public String targetKind;
        @AuraEnabled
        public String targetLabel;
        @AuraEnabled
        public Boolean exists;
        @AuraEnabled
        public Decimal onHand;
        @AuraEnabled
        public Decimal availableToOrder;
        @AuraEnabled
        public Decimal availableToFulfill;
        @AuraEnabled
        public Decimal reserved;
        @AuraEnabled
        public Decimal safetyStockCount;
    }
}