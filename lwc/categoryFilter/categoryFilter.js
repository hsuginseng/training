import { LightningElement, api } from 'lwc';

export default class CategoryFilter extends LightningElement {

    @api filterActionLabel='Filters';

	toggleFilters() {
        this.dispatchEvent(new CustomEvent('togglefilters', {
            detail: {
                filtersOpen: true
            }
        }));
    }
}