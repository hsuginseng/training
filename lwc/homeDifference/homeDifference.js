import { LightningElement, api } from 'lwc';

export default class HomeDifference extends LightningElement {
	@api title = 'How We’re Different';
	@api set content(data){
		this._content = data;
		try {  this.articles=JSON.parse(this._content); } catch(err){ console.error(err); }
	} 
	get content(){ return this._content; }
    @api articles;
}