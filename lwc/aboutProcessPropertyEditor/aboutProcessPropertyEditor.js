import { LightningElement, api, track } from 'lwc';

export default class AboutProcessPropertyEditor extends LightningElement {

    @track cards = [{ title: 'Title 1', text: 'Body 1', id: 1 }];
    _numProcessCards;

    @api
    set numProcessCards(value){
        this._numProcessCards = value;
        let tempCards = [];
        for (let i = 0; i < this._numProcessCards; i++) {
            tempCards.push({ title: 'Card ' + i, text: 'Text ' + i, id: i });
        }
        this.cards = tempCards;
        this.value = this.cards;
        this.dispatchEvent(new CustomEvent("valuechange", {detail: {value: JSON.stringify(this.value)}}));
    }
    get numProcessCards(){ return this._numProcessCards; }
    connectedCallback(){
        this.dispatchEvent(new CustomEvent("valuechange", {detail: {value: JSON.stringify(this.cards)}}));
    }

    @api
    set value(data){ let cards; try{ cards = data; this.numProcessCards=cards.length; } catch(err){ console.error('ERROR', err); } this._value=cards; }
    get value(){ return this._value; }
    _value;
    @api label;
    @api schema; // Derived from the associated property type.
    @api errors;

    handleNumCardsChange(event){
        if(event.detail.value){ this.numProcessCards = event.detail.value; }
    }


}