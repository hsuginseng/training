import { LightningElement, api } from 'lwc';
import { createSearchSortUpdateAction, dispatchAction } from 'commerce/actionApi';

export default class CategorySort extends LightningElement {
    static renderMode = "light";

    @api sortByActionLabel='Sort By';

    @api
    set sortRulesData(data){ this._sortRulesData = data; }
    get sortRulesData(){ return this._sortRulesData; }
    _sortRulesData;

    get sortRuleList(){ return this.sortRulesData.rules; }
    get sortOptions(){
        let options = [];
        if(this.sortRuleList){
            this.sortRuleList.forEach(rule => { options.push({ label: rule.label, value: rule.sortRuleId }); });
        }
        
        return options;
    }
    
    handleSortByChange(event){
        let selectedSortRuleId = event.detail.value;
        dispatchAction(this, createSearchSortUpdateAction(selectedSortRuleId));
    }
}