import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import SKU_FIELD from '@salesforce/schema/Product2.StockKeepingUnit';
import NAME_FIELD from '@salesforce/schema/Product2.Name';
import getInventoryForSku from '@salesforce/apex/OciInventoryPanelController.getInventoryForSku';

const NUMBER_ATTRS = { maximumFractionDigits: 3 };

const NUMERIC_FIELDS = ['onHand', 'availableToOrder', 'availableToFulfill', 'reserved', 'safetyStockCount'];

// Only the free-text columns are pinned (so long group-ref strings wrap instead of
// stretching). The numeric/status columns are left unsized: in fixed-width mode they split
// the remaining panel width evenly, filling it with no trailing whitespace.
const STOREFRONT_COLUMNS = [
    { label: 'Storefront', fieldName: 'targetLabel', wrapText: true, sortable: true, initialWidth: 170 },
    { label: 'Source', fieldName: 'targetId', wrapText: true, sortable: true, initialWidth: 230 },
    { label: 'Kind', fieldName: 'targetKind', sortable: true },
    { label: 'Status', fieldName: 'status', sortable: true, cellAttributes: { class: { fieldName: 'statusClass' } } },
    { label: 'On hand', fieldName: 'onHand', type: 'number', typeAttributes: NUMBER_ATTRS, sortable: true, cellAttributes: { alignment: 'right' } },
    { label: 'ATO', fieldName: 'availableToOrder', type: 'number', typeAttributes: NUMBER_ATTRS, sortable: true, cellAttributes: { alignment: 'right' } },
    { label: 'Reserved', fieldName: 'reserved', type: 'number', typeAttributes: NUMBER_ATTRS, sortable: true, cellAttributes: { alignment: 'right' } },
    { label: 'Safety stock', fieldName: 'safetyStockCount', type: 'number', typeAttributes: NUMBER_ATTRS, sortable: true, cellAttributes: { alignment: 'right' } }
];

const LOCATION_COLUMNS = [
    { label: 'Location', fieldName: 'targetLabel', wrapText: true, sortable: true, initialWidth: 210 },
    { label: 'Ref', fieldName: 'targetId', wrapText: true, sortable: true, initialWidth: 130 },
    { label: 'Status', fieldName: 'status', sortable: true, cellAttributes: { class: { fieldName: 'statusClass' } } },
    { label: 'On hand', fieldName: 'onHand', type: 'number', typeAttributes: NUMBER_ATTRS, sortable: true, cellAttributes: { alignment: 'right' } },
    { label: 'ATO', fieldName: 'availableToOrder', type: 'number', typeAttributes: NUMBER_ATTRS, sortable: true, cellAttributes: { alignment: 'right' } },
    { label: 'Available to fulfill', fieldName: 'availableToFulfill', type: 'number', typeAttributes: NUMBER_ATTRS, sortable: true, cellAttributes: { alignment: 'right' } },
    { label: 'Reserved', fieldName: 'reserved', type: 'number', typeAttributes: NUMBER_ATTRS, sortable: true, cellAttributes: { alignment: 'right' } },
    { label: 'Safety stock', fieldName: 'safetyStockCount', type: 'number', typeAttributes: NUMBER_ATTRS, sortable: true, cellAttributes: { alignment: 'right' } }
];

export default class OciInventoryPanel extends LightningElement {
    @api recordId;

    sku;
    productName;
    error;
    loading = false;
    loaded = false;

    // Backing data (already in default meaningful order).
    _storefronts = [];
    _locations = [];

    // Per-table sort state.
    storefrontSortBy;
    storefrontSortDirection = 'asc';
    locationSortBy;
    locationSortDirection = 'asc';

    // Collapse the long tail of "Not in OCI" locations by default.
    showAllLocations = false;

    storefrontColumns = STOREFRONT_COLUMNS;
    locationColumns = LOCATION_COLUMNS;

    @wire(getRecord, { recordId: '$recordId', fields: [SKU_FIELD, NAME_FIELD] })
    wiredProduct({ data, error }) {
        if (data) {
            this.productName = getFieldValue(data, NAME_FIELD);
            this.sku = getFieldValue(data, SKU_FIELD);
            this.loadInventory();
        } else if (error) {
            this.error = this.reduceError(error);
            this.loaded = true;
        }
    }

    async loadInventory() {
        // No SKU on the product => OCI has nothing to join to. Show the empty state.
        if (!this.sku) {
            this._storefronts = [];
            this._locations = [];
            this.loaded = true;
            return;
        }
        this.loading = true;
        this.error = undefined;
        try {
            const view = await getInventoryForSku({ sku: this.sku });
            this._storefronts = defaultOrder((view.storefronts || []).map(decorate));
            this._locations = defaultOrder((view.locations || []).map(decorate));
            // Reset any prior sort so we land on the meaningful default order.
            this.storefrontSortBy = undefined;
            this.locationSortBy = undefined;
        } catch (e) {
            this.error = this.reduceError(e);
            this._storefronts = [];
            this._locations = [];
        } finally {
            this.loading = false;
            this.loaded = true;
        }
    }

    handleRefresh() {
        this.loadInventory();
    }

    handleStorefrontSort(event) {
        const { fieldName, sortDirection } = event.detail;
        this.storefrontSortBy = fieldName;
        this.storefrontSortDirection = sortDirection;
        this._storefronts = sortRows(this._storefronts, fieldName, sortDirection);
    }

    handleLocationSort(event) {
        const { fieldName, sortDirection } = event.detail;
        this.locationSortBy = fieldName;
        this.locationSortDirection = sortDirection;
        this._locations = sortRows(this._locations, fieldName, sortDirection);
    }

    handleToggleEmpty(event) {
        this.showAllLocations = event.target.checked;
    }

    get storefronts() {
        return this._storefronts;
    }

    /** Locations actually present in OCI, unless the user opts to show the full list. */
    get visibleLocations() {
        if (this.showAllLocations) {
            return this._locations;
        }
        return this._locations.filter((r) => r.exists);
    }

    get hiddenLocationCount() {
        return this._locations.filter((r) => !r.exists).length;
    }

    get hasHiddenLocations() {
        return !this.showAllLocations && this.hiddenLocationCount > 0;
    }

    get toggleLabel() {
        return `Show ${this.hiddenLocationCount} location(s) not in OCI`;
    }

    /** "In stock on 2 of 3 storefronts" — quick read of buyability. */
    get storefrontSummary() {
        if (!this._storefronts.length) {
            return null;
        }
        const inStock = this._storefronts.filter((r) => r.exists && Number(r.availableToOrder) > 0).length;
        return `Available on ${inStock} of ${this._storefronts.length} storefront(s)`;
    }

    get hasSku() {
        return !!this.sku;
    }

    get showEmptyState() {
        return this.loaded && !this.loading && !this.hasSku && !this.error;
    }

    get hasStorefronts() {
        return this._storefronts.length > 0;
    }

    get hasVisibleLocations() {
        return this.visibleLocations.length > 0;
    }

    get hasAnyLocations() {
        return this._locations.length > 0;
    }

    reduceError(error) {
        if (Array.isArray(error?.body)) {
            return error.body.map((e) => e.message).join(', ');
        }
        return error?.body?.message || error?.message || 'Unknown error reading inventory.';
    }
}

/** Adds a human-readable status + SLDS text colour to each row. */
function decorate(row) {
    let status;
    let statusClass;
    if (!row.exists) {
        status = 'Not in OCI';
        statusClass = 'slds-text-color_weak';
    } else if (Number(row.availableToOrder) > 0) {
        status = 'In stock';
        statusClass = 'slds-text-color_success';
    } else {
        status = 'No availability';
        statusClass = 'slds-text-color_error';
    }
    return { ...row, status, statusClass };
}

/** Rank: stocked (2) > in OCI but zero (1) > not in OCI (0). Higher floats to top. */
function stockRank(row) {
    if (row.exists && Number(row.onHand) > 0) {
        return 2;
    }
    return row.exists ? 1 : 0;
}

/** Default meaningful order: stocked locations first, then by label. */
function defaultOrder(rows) {
    return [...rows].sort((a, b) => stockRank(b) - stockRank(a) || String(a.targetLabel).localeCompare(String(b.targetLabel)));
}

function sortRows(rows, field, direction) {
    const factor = direction === 'asc' ? 1 : -1;
    const numeric = NUMERIC_FIELDS.includes(field);
    return [...rows].sort((a, b) => factor * compareValues(a[field], b[field], numeric));
}

function compareValues(a, b, numeric) {
    // Treat blanks as lowest so empty rows settle at the bottom on a descending sort.
    if (a == null && b == null) return 0;
    if (a == null) return -1;
    if (b == null) return 1;
    if (numeric) {
        return Number(a) - Number(b);
    }
    return String(a).localeCompare(String(b));
}