import { LightningElement, api } from 'lwc';
import { createSearchFiltersUpdateAction, dispatchAction } from 'commerce/actionApi';

export default class CategoryPagination extends LightningElement {
    @api currentPageNumber;
    @api resultsPerPage;
    @api numResults;

    @api actionLabelPreviousPage='Previous';
    @api actionLabelNextPage='Next';

    get previousButtonDisabled(){ return this.currentPageNumber <= 1;}
    get nextButtonDisabled(){ return this.currentPageNumber >= this.pageCount; }
    get pageCount(){
        if(this.numResults && this.resultsPerPage){ return Math.ceil(this.numResults/this.resultsPerPage); }
        return 1;
    }
    get paginationItems(){
        let paginationItems = [];
        for(let i = 1; i <= this.pageCount; i++){
            paginationItems.push({ label: i, value: i, styling: (this.currentPageNumber==i) ? 'pagination-page current' : 'pagination-page', type:'number', enabled: true });
        }

        return paginationItems;
    }

    handleClickPageNumber(event){
        let pageNumber = event.currentTarget.dataset.index;
        this.currentPageNumber = pageNumber;
        this.dispatchResultsPageChangeEvent();
    }

    handleClickPreviousButton(event){
        this.currentPageNumber = this.currentPageNumber - 1;
        this.dispatchResultsPageChangeEvent();
    }

    handleClickNextButton(event){
        this.currentPageNumber = this.currentPageNumber + 1;
        this.dispatchResultsPageChangeEvent();
    }

    dispatchResultsPageChangeEvent(){
        dispatchAction(this, createSearchFiltersUpdateAction({ page: this.currentPageNumber }));
    }
}