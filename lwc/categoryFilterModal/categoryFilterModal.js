import { LightningElement, wire, api, track } from 'lwc';
import { NavigationMixin } from "lightning/navigation";
import { ProductSearchAdapter } from 'commerce/productApi';

export default class CategoryFilterModal extends NavigationMixin(LightningElement) {
    @api
    set currentCategoryId(value){ this.categorySearchQuery = { categoryId: value }; }
    get currentCategoryId(){ return this.categorySearchQuery; }

    @api filterResults;

    @api modalHeaderLabel = 'Filters';
    @api modalActionLabelApplyFilter = 'Filter';
    @api modalActionLabelClearFilters = 'Clear Filters';

    @track categories;
    @track categorySearchQuery;
    searchDataResult;
    isLoading = true;
    
    @wire(ProductSearchAdapter, { searchQuery: '$categorySearchQuery' })
    retrieveSearchData(result) {
        this.searchDataResult = result;
        if(result.data) {
            this.categories = JSON.parse(JSON.stringify(result.data.categories.children));
            this.categories.forEach(category => { category.selected=false; });
            this.isLoading=false;
        } else if(result.error) {
            console.error('retrieveSearchData wire error', result.error);
        }

        setTimeout(() => { this.isLoading=false; }, 1000);
    }

	toggleFilters() {
        this.dispatchEvent(new CustomEvent('togglefilters', {
            detail: {
                filtersOpen: false
            }
        }));
    }

    handleItemSelectStateChanged(event){
        let categoryIndex = this.categories.findIndex(categoryWrapper => categoryWrapper.category.id == event.detail.categoryId );
        this.categories[categoryIndex].selected = event.detail.selected;
    }

    handleClickApplyFilters(event){
        event.preventDefault();
        this.toggleFilters();

        let categoryWrapper = this.categories.find(categoryWrapper => categoryWrapper.selected == true );
        this.currentCategoryId = categoryWrapper.category.id;
        this.categorySearchQuery.categoryId = categoryWrapper.category.id;

        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: categoryWrapper.category.id,
                objectApiName: 'ProductCategory',
                actionName: 'view'
            }
        })

    }

    handleClickClearFilters(event){
        event.preventDefault();
        let filterItems = this.template.querySelectorAll('c-category-filter-modal-item');
        filterItems.forEach(item => {
            item.setSelectedState(false);
        });
    }
}