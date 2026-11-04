import { getAppContext } from 'commerce/contextApi';
import LANG from '@salesforce/i18n/lang';
import IS_GUEST from '@salesforce/user/isGuest';

const DEFAULT_COMMERCE_INVENTORY_LEVELS_PARAMS = {
    includeRelatedProducts: false,
    htmlEncode: false
};

/** Production storefront serves webruntime under `/webruntime/...`; Experience Cloud UAT uses `/d2c/webruntime/...`. */
const commerceInventoryLevelsUrl = () => {
    const hasWindow = typeof window !== 'undefined';
    const origin = hasWindow
        ? `${window.location.protocol}//${window.location.hostname}`
        : 'https://www.hsuginseng.com';
    const hostname = hasWindow ? window.location.hostname : 'www.hsuginseng.com';
    const webRuntimeBase =
        hostname === 'www.hsuginseng.com' || hostname === 'hsuginseng.com'
            ? '/webruntime'
            : '/d2c/webruntime';
    return `${origin.replace(/\/$/, '')}${webRuntimeBase}/api/services/data/v66.0/commerce/inventory/levels`;
};

const toQueryString = (params) =>
    Object.entries(params)
        .map(([key, value]) => `${encodeURIComponent(key)}=${encodeURIComponent(String(value))}`)
        .join('&');

/** Commerce inventory/levels expects multiple `products` (or `locations`) as a comma-separated list in the query string. */
const toCsvParam = (value) => {
    if (Array.isArray(value)) {
        return value.filter(Boolean).join(',');
    }
    return value;
};

const normalizeInventoryLevelsPayload = (payload) => {
    const records = payload?.totalInventory ?? [];
    return Object.fromEntries(
        records
            .filter((record) => record?.product2Id)
            .map((record) => [
                record.product2Id,
                {
                    availableToOrder: Number(record.availableToOrder ?? 0),
                    availableToFulfill: Number(record.availableToFulfill ?? 0),
                    onHand: Number(record.onHand ?? 0)
                }
            ])
    );
};

const buildDynamicInventoryLevelsParams = async () => {
    const appContext = await getAppContext();
    const webstoreId = appContext?.webstoreId ?? appContext?.store?.id ?? null;
    const locationSourceId =
        appContext?.inventoryConfiguration?.inventoryDefaultSource?.locationSourceId ?? null;

    return {
        locations: locationSourceId || undefined,
        scope: webstoreId ? `webStoreId eq ${webstoreId}` : undefined,
        language: LANG || 'en-US',
        asGuest: Boolean(IS_GUEST)
    };
};

/**
 * Fetch commerce inventory levels and return map keyed by Product2 Id.
 * Pass any number of Product2 Ids; they are sent as one `products` query param (comma-separated), same as valid URLs like
 * `...&products=01t...,01t...&...`.
 *
 * @param {string[]} products List of Product2 Id values.
 * @returns {Promise<Object<string, {availableToOrder:number, availableToFulfill:number, onHand:number}>>}
 */
const fetchCommerceInventoryLevels = async (products = []) => {
    const productList = Array.isArray(products) ? products.filter(Boolean) : [];
    if (productList.length === 0) return {};

    const dynamicParams = await buildDynamicInventoryLevelsParams();
    const mergedParams = {
        ...DEFAULT_COMMERCE_INVENTORY_LEVELS_PARAMS,
        ...dynamicParams,
        products: toCsvParam(productList) // e.g. "01t...,01t..." → multiple products in one request
    };
    mergedParams.products = toCsvParam(mergedParams.products);
    mergedParams.locations = toCsvParam(mergedParams.locations);
    const url = `${commerceInventoryLevelsUrl()}?${toQueryString(mergedParams)}`;
    const response = await fetch(url, {
        method: 'GET',
        credentials: 'omit',
        headers: { Accept: 'application/json' }
    });

    if (!response.ok) {
        const body = await response.text();
        throw new Error(`inventory/levels ${response.status}: ${body || response.statusText}`);
    }

    const payload = await response.json();
    const normalized = normalizeInventoryLevelsPayload(payload);
    return normalized;
};

export { fetchCommerceInventoryLevels };