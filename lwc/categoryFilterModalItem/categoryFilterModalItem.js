import { LightningElement, api, wire } from 'lwc';
import { ProductChildrenAdapter } from 'commerce/productApi';
import { ProductSearchAdapter } from 'commerce/productApi';

export default class CategoryFilterModalItem extends LightningElement {

    @api category;
    @api categoryChildren;
    @api productCount;
    @api selected=false;

    @api setSelectedState(state){
        if(state == false){
            let checkbox = this.template.querySelector('input');
            checkbox.checked = state;
        }
    }

    handleCheckboxClicked(event){
        this.dispatchEvent(new CustomEvent('selectstatechanged', {
            detail: {
                selected: event.currentTarget.checked,
                categoryId: this.category.id
            }
        }));
    }
}