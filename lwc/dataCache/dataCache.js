// Module-scoped map: key → { promise, data }
const cache = new Map();

/**
 * Returns cached data for a key, or calls fetchFn once and caches its promise + result.
 * @param {string} key - unique key (e.g. recordId)
 * @param {Function} fetchFn - function returning a Promise (e.g. Apex callout)
 */
export function getOrFetch(key, fetchFn) {
    // Already have data? Return it immediately.
    if (cache.has(key) && cache.get(key).data)
    { return Promise.resolve(cache.get(key).data); }

    // Already fetching? Return the same promise.
    if (cache.has(key) && cache.get(key).promise)
    { return cache.get(key).promise; }

    // Otherwise, call fetchFn and store the promise
    const promise = fetchFn()
        .then(result => {
            cache.set(key, { data: result, promise: null });
            return result;
        })
        .catch(error => {
            cache.delete(key); // clear on failure
            throw error;
        });

    cache.set(key, { data: null, promise });
    return promise;
}